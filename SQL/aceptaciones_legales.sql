-- ═══════════════════════════════════════════════════════════════════════════
-- Migración: tabla `aceptaciones_legales` (audit trail inmutable)
-- ═══════════════════════════════════════════════════════════════════════════
-- Motivación: hoy el checkbox de "Acepto los T&C y la Política de Privacidad"
-- en el registro obliga al user a marcarlo, pero no dejaba rastro. Si mañana
-- un user niega haber aceptado los términos, o cambian las versiones y hay
-- que probar qué versión aceptó cada quien, no había evidencia.
--
-- Esta tabla es un audit trail INMUTABLE (no permite UPDATE ni DELETE por
-- policy). Cada aceptación queda registrada con timestamp preciso, versión,
-- IP y user agent. Se usa como prueba legal en caso de disputa.
--
-- Estructura complementaria:
--   - user_metadata.terminos_aceptados_v (redundante para lectura rápida
--     del perfil sin cross-join)
--   - user_metadata.terminos_aceptados_fecha
--   - user_metadata.privacidad_aceptada_v
--   - user_metadata.privacidad_aceptada_fecha
--
-- Convención del proyecto: 4 policies RLS explícitas + owner-only para
-- SELECT + INSERT libre para authenticated (necesario para poder registrar
-- aceptación) + UPDATE / DELETE bloqueados (audit trail).
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.aceptaciones_legales (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  tipo text not null check (tipo in ('terminos','privacidad')),
  version text not null,
  fecha_aceptacion timestamptz not null default now(),
  ip text,
  user_agent text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz not null default now()
);

comment on table public.aceptaciones_legales is
  'Audit trail inmutable de aceptaciones de T&C y Política de Privacidad. '
  'Cada fila queda registrada permanentemente y no puede ser modificada ni '
  'borrada (salvo cascade delete cuando se elimina el auth.user).';
comment on column public.aceptaciones_legales.tipo is
  'terminos | privacidad — qué documento se aceptó.';
comment on column public.aceptaciones_legales.version is
  'Versión del documento aceptado. Formato sugerido: v1-2026-07.';
comment on column public.aceptaciones_legales.ip is
  'IP desde donde se registró la aceptación. Best effort — puede estar null si '
  'no se pudo obtener.';
comment on column public.aceptaciones_legales.user_agent is
  'User-Agent del navegador al momento de la aceptación. Best effort.';

create index if not exists idx_aceptaciones_user on public.aceptaciones_legales(user_id);
create index if not exists idx_aceptaciones_tipo_version on public.aceptaciones_legales(tipo, version);
create index if not exists idx_aceptaciones_fecha on public.aceptaciones_legales(fecha_aceptacion desc);

-- ── RLS ──────────────────────────────────────────────────────────────────────
alter table public.aceptaciones_legales enable row level security;

drop policy if exists user_select_aceptaciones on public.aceptaciones_legales;
drop policy if exists user_insert_aceptaciones on public.aceptaciones_legales;
drop policy if exists nadie_update_aceptaciones on public.aceptaciones_legales;
drop policy if exists nadie_delete_aceptaciones on public.aceptaciones_legales;

-- SELECT: cada user ve solo las suyas
create policy user_select_aceptaciones on public.aceptaciones_legales
  for select using (auth.uid() = user_id);

-- INSERT: cualquier user autenticado puede insertar una aceptación con su propio user_id
-- (el frontend solo inserta con auth.uid() como user_id, no permite hardcodear otro)
create policy user_insert_aceptaciones on public.aceptaciones_legales
  for insert with check (auth.uid() = user_id);

-- UPDATE: NADIE puede actualizar una aceptación — es un audit trail inmutable.
-- No creamos policy positive → deniega por default.

-- DELETE: NADIE puede borrar una aceptación (salvo cascade delete del auth.user).
-- No creamos policy positive → deniega por default.

-- Aunque no creamos policies para UPDATE/DELETE, dejamos DROP de las viejas por si
-- alguna existía en una versión previa del schema y esta migración se re-ejecuta.
