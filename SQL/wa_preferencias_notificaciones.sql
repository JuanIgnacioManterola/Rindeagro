-- ═══════════════════════════════════════════════════════════════════════════
-- Migración: tabla `wa_preferencias_notificaciones` + RLS
-- ═══════════════════════════════════════════════════════════════════════════
-- Motivación: el frontend (index.html líneas ~7142-7233) intenta leer y
-- escribir preferencias de WhatsApp del usuario, pero la tabla no existía en
-- el schema. El código ya tenía manejo defensivo (timeout + fallback REST +
-- estado "En desarrollo") para no crashear, pero eso significa que ningún
-- usuario podía guardar sus preferencias — se perdían al cerrar la pestaña.
--
-- Esta tabla persiste qué avisos quiere recibir cada usuario por WhatsApp:
--   - resumen_semanal: sábados 9hs, resumen de lluvias/gastos/precios
--   - alerta_precio: cuando cambia significativamente el precio de soja
--   - recordatorio_admin: viernes 12:30hs, aviso para cargar datos
--   - recordatorio_operario: L/M/V 17:30hs, aviso a operarios
--   - activo: master switch para pausar TODAS las notificaciones
--
-- Convención del proyecto: RLS owner-only con 4 policies explícitas. user_id
-- es PK (una fila por user) para que `upsert onConflict: user_id` funcione.
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.wa_preferencias_notificaciones (
  user_id uuid primary key references auth.users(id) on delete cascade,
  resumen_semanal boolean not null default true,
  alerta_precio boolean not null default true,
  recordatorio_admin boolean not null default true,
  recordatorio_operario boolean not null default true,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.wa_preferencias_notificaciones is
  'Preferencias de notificaciones de WhatsApp por usuario. Una fila por user.';
comment on column public.wa_preferencias_notificaciones.activo is
  'Master switch: si false, pausa TODAS las notificaciones sin borrar preferencias.';

-- ── RLS ──────────────────────────────────────────────────────────────────────
alter table public.wa_preferencias_notificaciones enable row level security;

drop policy if exists owner_select_wa_prefs on public.wa_preferencias_notificaciones;
drop policy if exists owner_insert_wa_prefs on public.wa_preferencias_notificaciones;
drop policy if exists owner_update_wa_prefs on public.wa_preferencias_notificaciones;
drop policy if exists owner_delete_wa_prefs on public.wa_preferencias_notificaciones;

create policy owner_select_wa_prefs on public.wa_preferencias_notificaciones
  for select using (auth.uid() = user_id);
create policy owner_insert_wa_prefs on public.wa_preferencias_notificaciones
  for insert with check (auth.uid() = user_id);
create policy owner_update_wa_prefs on public.wa_preferencias_notificaciones
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy owner_delete_wa_prefs on public.wa_preferencias_notificaciones
  for delete using (auth.uid() = user_id);

-- ── Trigger para updated_at ──────────────────────────────────────────────────
create or replace function public.tg_wa_prefs_touch()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists tg_wa_prefs_updated_at on public.wa_preferencias_notificaciones;
create trigger tg_wa_prefs_updated_at
  before update on public.wa_preferencias_notificaciones
  for each row execute function public.tg_wa_prefs_touch();
