-- ─────────────────────────────────────────────────────────────────────────────
-- Módulo Pagos — compromisos_pago (cheques emitidos + cuotas de crédito)
-- Aplicada via MCP el 2026-05-17
--
-- Modelo: una fila por cada compromiso individual a pagar.
-- - Cheque: una sola fila.
-- - Crédito de N cuotas: N filas, todas con el mismo credito_id y
--   numero_cuota = 1..N, total_cuotas = N.
--
-- Estados: pendiente | cobrado | vencido | cancelado.
-- Alerta opcional: alerta_dias_antes (NULL = sin alerta).
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists public.compromisos_pago (
  id                  uuid primary key default gen_random_uuid(),
  owner_id            uuid not null references auth.users(id) on delete cascade,
  tipo                text not null check (tipo in ('cheque','cuota_credito')),
  descripcion         text,
  beneficiario        text,
  fecha_emision       date,
  fecha_cobro         date not null,
  importe             numeric(14,2) not null check (importe >= 0),
  moneda              text not null default 'ARS' check (moneda in ('ARS','USD')),
  alerta_dias_antes   integer check (alerta_dias_antes is null or alerta_dias_antes >= 0),
  estado              text not null default 'pendiente' check (estado in ('pendiente','cobrado','vencido','cancelado')),
  banco               text,
  numero_cheque       text,
  credito_id          uuid,
  numero_cuota        integer,
  total_cuotas        integer,
  notas               text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create index if not exists idx_compromisos_owner          on public.compromisos_pago(owner_id);
create index if not exists idx_compromisos_owner_fecha    on public.compromisos_pago(owner_id, fecha_cobro);
create index if not exists idx_compromisos_owner_estado   on public.compromisos_pago(owner_id, estado);
create index if not exists idx_compromisos_credito        on public.compromisos_pago(credito_id);

-- Trigger updated_at
create or replace function public.touch_compromisos_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists trg_compromisos_updated_at on public.compromisos_pago;
create trigger trg_compromisos_updated_at
  before update on public.compromisos_pago
  for each row execute function public.touch_compromisos_updated_at();

-- RLS: 4 policies explícitas (NO usar FOR ALL — ver CLAUDE.md)
alter table public.compromisos_pago enable row level security;

drop policy if exists "compromisos_select" on public.compromisos_pago;
create policy "compromisos_select" on public.compromisos_pago for select using (owner_id = auth.uid());

drop policy if exists "compromisos_insert" on public.compromisos_pago;
create policy "compromisos_insert" on public.compromisos_pago for insert with check (owner_id = auth.uid());

drop policy if exists "compromisos_update" on public.compromisos_pago;
create policy "compromisos_update" on public.compromisos_pago for update using (owner_id = auth.uid()) with check (owner_id = auth.uid());

drop policy if exists "compromisos_delete" on public.compromisos_pago;
create policy "compromisos_delete" on public.compromisos_pago for delete using (owner_id = auth.uid());
