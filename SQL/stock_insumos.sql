-- ─────────────────────────────────────────────────────────────────────────────
-- Stock de Insumos
-- ─────────────────────────────────────────────────────────────────────────────
-- Crea la tabla `stock_insumos` (global por productor, no por campo) y
-- agrega `insumo_id` opcional a `gastos` para vincular un gasto al stock.
-- El descuento de stock al guardar el gasto se hace desde el frontend
-- (lectura + UPDATE), validando que no quede negativo.
--
-- Aplicar en el SQL Editor de Supabase. Idempotente: usa IF NOT EXISTS.
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.stock_insumos (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null references auth.users(id) on delete cascade,
  nombre          text not null,
  tipo            text not null check (tipo in ('herbicidas','fungicidas','insecticidas','fertilizantes','semillas','otros')),
  unidad          text not null check (unidad in ('litros','kg','dosis','bolsas')),
  stock_actual    numeric(14,3) not null default 0 check (stock_actual >= 0),
  costo_unitario  numeric(14,4),
  ubicacion       text,
  notas           text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create index if not exists idx_stock_insumos_owner on public.stock_insumos(owner_id);
create index if not exists idx_stock_insumos_tipo  on public.stock_insumos(owner_id, tipo);

-- Trigger para mantener updated_at
create or replace function public.touch_stock_insumos_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_stock_insumos_updated_at on public.stock_insumos;
create trigger trg_stock_insumos_updated_at
  before update on public.stock_insumos
  for each row execute function public.touch_stock_insumos_updated_at();

-- ── RLS (siguiendo convención de `invitaciones`: 4 policies explícitas) ───────
alter table public.stock_insumos enable row level security;

drop policy if exists "stock_insumos_select" on public.stock_insumos;
create policy "stock_insumos_select"
  on public.stock_insumos for select
  using (owner_id = auth.uid());

drop policy if exists "stock_insumos_insert" on public.stock_insumos;
create policy "stock_insumos_insert"
  on public.stock_insumos for insert
  with check (owner_id = auth.uid());

drop policy if exists "stock_insumos_update" on public.stock_insumos;
create policy "stock_insumos_update"
  on public.stock_insumos for update
  using (owner_id = auth.uid())
  with check (owner_id = auth.uid());

drop policy if exists "stock_insumos_delete" on public.stock_insumos;
create policy "stock_insumos_delete"
  on public.stock_insumos for delete
  using (owner_id = auth.uid());

-- ── Vincular gasto ↔ insumo (opcional) ───────────────────────────────────────
alter table public.gastos
  add column if not exists insumo_id uuid references public.stock_insumos(id) on delete set null;

create index if not exists idx_gastos_insumo_id on public.gastos(insumo_id);
