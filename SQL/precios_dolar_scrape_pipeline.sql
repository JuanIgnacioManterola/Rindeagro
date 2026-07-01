-- ═════════════════════════════════════════════════════════════════════════════
-- Precios: pipeline de scraping automatizado (BCR cereales + BNA dólar)
-- Aplicado en producción via MCP el 2026-07-01.
-- ═════════════════════════════════════════════════════════════════════════════
-- Motivación:
-- - Antes: precios_pizarra tenía una única columna `bna` (mal etiquetada como
--   "divisa comprador" en la UI pero en realidad guardaba el billete oficial).
--   El fetch corría desde el navegador contra ambito.com / dolarapi.com,
--   dependía de tener el tab abierto y solo capturaba una cotización.
-- - Ahora: dos edge functions (precios-scrape-bcr, precios-fetch-dolar) corren
--   por pg_cron server-side. Frontend lee de dos vistas públicas y usa los
--   4 valores del BNA por semántica: divisa_compra para ingresos (venta cereal),
--   divisa_venta para egresos (compra insumos en USD).
--
-- Componentes:
-- 1. Tabla precios_dolar (nueva): billete_compra/venta + divisa_compra/venta.
-- 2. Extensiones pg_cron + pg_net (para invocar edge functions desde DB).
-- 3. RLS en precios_pizarra (pendiente del security advisor).
-- 4. Vistas v_precio_dolar_actual / v_precio_cereales_actual con filtros de sanity.
-- 5. Cron jobs: BCR a las 19:00 lun-vie; dólar cada 30 min entre 10-15 hs lun-vie
--    y al cierre 19:00.
-- ═════════════════════════════════════════════════════════════════════════════

create extension if not exists pg_net with schema extensions;
create extension if not exists pg_cron;

-- RLS en precios_pizarra
alter table public.precios_pizarra enable row level security;
drop policy if exists "precios_pizarra_read_all" on public.precios_pizarra;
create policy "precios_pizarra_read_all"
  on public.precios_pizarra for select using (true);

-- Nueva tabla precios_dolar
create table if not exists public.precios_dolar (
  id bigserial primary key,
  timestamp_scrape timestamptz not null default now(),
  fecha date not null default (now() at time zone 'America/Argentina/Buenos_Aires')::date,
  fuente text not null default 'bna',
  billete_compra numeric,
  billete_venta numeric,
  divisa_compra numeric,
  divisa_venta numeric,
  notas text
);
create index if not exists idx_precios_dolar_ts_desc
  on public.precios_dolar (timestamp_scrape desc);

alter table public.precios_dolar enable row level security;
drop policy if exists "precios_dolar_read_all" on public.precios_dolar;
create policy "precios_dolar_read_all"
  on public.precios_dolar for select using (true);

-- Vistas helper con filtros de sanity (valores absurdos = fila corrupta)
create or replace view public.v_precio_dolar_actual as
  select * from public.precios_dolar
  where divisa_compra is not null and divisa_venta is not null
    and divisa_compra between 100 and 100000
    and divisa_venta  between 100 and 100000
  order by timestamp_scrape desc limit 1;
grant select on public.v_precio_dolar_actual to anon, authenticated;

create or replace view public.v_precio_cereales_actual as
  select * from public.precios_pizarra order by fecha desc limit 1;
grant select on public.v_precio_cereales_actual to anon, authenticated;

-- pg_cron: schedules
-- BCR cereales: 19:00 ARG lun-vie
-- BNA dólar intraday: cada 30 min entre 10:00-15:00 ARG lun-vie
-- BNA dólar cierre: 19:00 ARG lun-vie (junto con BCR)
-- ARG = UTC-3 (sin DST desde 2009)
--
-- Los schedules se aplican en producción vía cron.schedule() con URL y anon key
-- de la instancia (kmfydetiwatnwwzjnhyq). No los versionamos acá porque incluyen
-- el JWT anon key hardcoded — ver Supabase → Database → Cron para inspeccionarlos.
