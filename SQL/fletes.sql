-- ═══════════════════════════════════════════════════════════════════════════
-- Migración: tabla `fletes` + bucket Storage + RLS
-- ═══════════════════════════════════════════════════════════════════════════
-- Motivación: nueva sección "Información adicional" dentro de la vista de
-- campo, tercera opción "Fletes". Permite registrar cada camión que carga
-- cereal de un campo en una campaña, con toda la data de la carta de porte:
-- patente camión/acoplado, camionero, transportista, toneladas, destino,
-- empresa compradora, número de CTG, peso bruto/tara/neto, humedad,
-- precio del flete, km, estado (cargado/entregado/pagado), adjunto de la
-- carta de porte para OCR o consulta posterior.
--
-- Bucket público `fletes-cartas-porte` con path `<owner_id>/<ts>_<file>`.
-- RLS explícita owner-only (4 policies, convención del proyecto).
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.fletes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  campo_id uuid not null references public.campos(id) on delete cascade,
  cultivo text,
  fecha date not null,
  -- Datos del camión y transporte
  patente_camion text not null,
  patente_acoplado text,
  nombre_camionero text,
  nombre_transporte text,
  -- Carga y destino
  toneladas numeric(10,2) not null check (toneladas > 0),
  destino text,
  empresa_destino text,
  -- Datos AFIP / trazabilidad
  ctg text,
  carta_porte_nro text,
  -- Peso y humedad (opcionales)
  peso_bruto_kg numeric(12,2),
  peso_tara_kg numeric(12,2),
  peso_neto_kg numeric(12,2),
  humedad_porcentaje numeric(5,2),
  -- Costo del flete
  precio_flete_usd numeric(12,2),
  precio_flete_moneda text default 'usd' check (precio_flete_moneda in ('usd','ars')),
  km_recorridos numeric(10,2),
  -- Estado operativo
  estado text default 'cargado' check (estado in ('cargado','entregado','pagado','cancelado')),
  -- Adjunto de la carta de porte
  archivo_url text,
  archivo_path text,
  fuente text default 'manual' check (fuente in ('manual','foto','whatsapp')),
  -- Notas libres
  notas text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

comment on table public.fletes is
  'Fletes de granos por campo/campaña. Alimenta la sección Fletes de Información Adicional.';
comment on column public.fletes.toneladas is
  'Toneladas cargadas. Numeric con 2 decimales (ej: 28.50).';
comment on column public.fletes.ctg is
  'Código de Trazabilidad de Granos (AFIP). Opcional.';
comment on column public.fletes.fuente is
  'Origen del registro: manual (usuario tipeó), foto (OCR carta de porte), whatsapp (bot).';

create index if not exists idx_fletes_owner on public.fletes(owner_id);
create index if not exists idx_fletes_campo on public.fletes(campo_id);
create index if not exists idx_fletes_fecha on public.fletes(fecha desc);
create index if not exists idx_fletes_empresa on public.fletes(empresa_destino);
create index if not exists idx_fletes_patente on public.fletes(patente_camion);

-- ── RLS ──────────────────────────────────────────────────────────────────────
alter table public.fletes enable row level security;

drop policy if exists owner_select_fletes on public.fletes;
drop policy if exists owner_insert_fletes on public.fletes;
drop policy if exists owner_update_fletes on public.fletes;
drop policy if exists owner_delete_fletes on public.fletes;

create policy owner_select_fletes on public.fletes
  for select using (auth.uid() = owner_id);
create policy owner_insert_fletes on public.fletes
  for insert with check (auth.uid() = owner_id);
create policy owner_update_fletes on public.fletes
  for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy owner_delete_fletes on public.fletes
  for delete using (auth.uid() = owner_id);

-- ── Bucket Storage para cartas de porte ─────────────────────────────────────
insert into storage.buckets (id, name, public)
  values ('fletes-cartas-porte', 'fletes-cartas-porte', true)
  on conflict (id) do nothing;

-- Policies Storage (4 explícitas owner-only, patrón del proyecto)
drop policy if exists owner_read_cp on storage.objects;
drop policy if exists owner_insert_cp on storage.objects;
drop policy if exists owner_update_cp on storage.objects;
drop policy if exists owner_delete_cp on storage.objects;

create policy owner_read_cp on storage.objects
  for select using (
    bucket_id = 'fletes-cartas-porte'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy owner_insert_cp on storage.objects
  for insert with check (
    bucket_id = 'fletes-cartas-porte'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy owner_update_cp on storage.objects
  for update using (
    bucket_id = 'fletes-cartas-porte'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
create policy owner_delete_cp on storage.objects
  for delete using (
    bucket_id = 'fletes-cartas-porte'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Trigger para updated_at
create or replace function public.tg_fletes_touch()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists tg_fletes_updated_at on public.fletes;
create trigger tg_fletes_updated_at
  before update on public.fletes
  for each row execute function public.tg_fletes_touch();
