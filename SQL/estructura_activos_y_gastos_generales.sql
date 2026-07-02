-- ═════════════════════════════════════════════════════════════════════════════
-- Módulo Estructura: activos amortizables + gastos generales
-- Aplicada via MCP el 2026-07-02
-- ═════════════════════════════════════════════════════════════════════════════
-- Motivación: hasta ahora la tabla `gastos` requiere campo_id. Pero
-- amortizaciones (camioneta 5 años, herramienta 10 años, silo 15 años) y
-- sueldos/gastos de estructura (contador, oficina, seguros, empleados que
-- trabajan en varios campos) son costos de la EMPRESA productor, no de un
-- campo específico. Se prorratean entre campos y campañas.
--
-- Estas dos tablas cubren esos dos casos:
--   - activos_amortizables: se carga una vez el activo (valor + vida útil) y
--     el sistema calcula la cuota anual automática.
--   - gastos_estructura: recurrentes (mensuales/anuales) o únicos, no ligados
--     a un campo.
--
-- Distribución entre campos (modo por gasto/activo):
--   por_hectareas → default, proporcional al peso de ha del campo
--   igualitario   → dividido por cantidad de campos
--   personalizado → distribuir_config guarda {campo_id: pct} JSON (a futuro)
-- ═════════════════════════════════════════════════════════════════════════════

create table if not exists public.activos_amortizables (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  descripcion text not null,
  tipo text not null check (tipo in ('vehiculo','herramienta','maquinaria','construccion','otros')),
  valor_compra_usd numeric not null check (valor_compra_usd > 0),
  fecha_compra date not null,
  vida_util_anos integer not null check (vida_util_anos > 0 and vida_util_anos <= 50),
  valor_residual_usd numeric not null default 0 check (valor_residual_usd >= 0),
  distribuir_modo text not null default 'por_hectareas' check (distribuir_modo in ('por_hectareas','igualitario','personalizado')),
  distribuir_config text,
  notas text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_activos_amort_owner on public.activos_amortizables (owner_id);
alter table public.activos_amortizables enable row level security;
create policy "activos_amort_select" on public.activos_amortizables for select using (auth.uid() = owner_id);
create policy "activos_amort_insert" on public.activos_amortizables for insert with check (auth.uid() = owner_id);
create policy "activos_amort_update" on public.activos_amortizables for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "activos_amort_delete" on public.activos_amortizables for delete using (auth.uid() = owner_id);

create table if not exists public.gastos_estructura (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  descripcion text not null,
  tipo text not null check (tipo in ('sueldo','honorarios','seguro','oficina','combustible','otros')),
  importe_usd numeric not null check (importe_usd > 0),
  frecuencia text not null default 'mensual' check (frecuencia in ('unico','mensual','anual')),
  fecha_inicio date not null,
  fecha_fin date,
  distribuir_modo text not null default 'por_hectareas' check (distribuir_modo in ('por_hectareas','igualitario','personalizado')),
  distribuir_config text,
  notas text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists idx_gastos_estructura_owner on public.gastos_estructura (owner_id);
create index if not exists idx_gastos_estructura_fecha on public.gastos_estructura (fecha_inicio);
alter table public.gastos_estructura enable row level security;
create policy "gastos_estr_select" on public.gastos_estructura for select using (auth.uid() = owner_id);
create policy "gastos_estr_insert" on public.gastos_estructura for insert with check (auth.uid() = owner_id);
create policy "gastos_estr_update" on public.gastos_estructura for update using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "gastos_estr_delete" on public.gastos_estructura for delete using (auth.uid() = owner_id);
