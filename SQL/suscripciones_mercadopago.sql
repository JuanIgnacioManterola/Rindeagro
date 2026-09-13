-- ─────────────────────────────────────────────────────────────────────────────
-- Suscripciones — Mercado Pago (preapproval / débito automático)
--
-- Fuente de verdad del plan pago del usuario. ANTES el plan vivía en
-- auth.users.user_metadata.plan, que es ESCRIBIBLE POR EL CLIENTE
-- (sb.auth.updateUser({data:{plan:'cosecha'}}) desde la consola del navegador).
-- Con estas tablas el plan efectivo se deriva de una fila que SOLO puede
-- escribir el webhook de Mercado Pago usando el service_role.
--
-- Arquitectura elegida (ver CLAUDE.md → "Suscripciones y cobro"):
--   preapproval SIN plan asociado, status 'pending' → init_point → checkout de MP.
--   Cada suscripción lleva su propio transaction_amount (los precios son
--   USD × dólar BNA + IVA, distintos para cada usuario según el día del alta)
--   y su propio external_reference (owner_id|plan|periodo) para que el
--   webhook mapee de vuelta sin ambigüedad.
--
-- Estados de suscripciones.estado:
--   pendiente  → preapproval creado, el usuario todavía no puso la tarjeta.
--   activa     → MP la marcó authorized y está al día.
--   en_gracia  → un cobro falló; conserva acceso completo hasta gracia_hasta.
--   impaga     → venció la gracia sin regularizar → la app pasa a solo lectura.
--   pausada    → paused en MP (sin cobros, sin acceso pago).
--   cancelada  → cancelled en MP o baja pedida por el usuario.
-- ─────────────────────────────────────────────────────────────────────────────

-- ═══════════════════════════════════════════════════════════════════════════
-- 1) suscripciones
-- ═══════════════════════════════════════════════════════════════════════════

create table if not exists public.suscripciones (
  id                   uuid primary key default gen_random_uuid(),
  owner_id             uuid not null references auth.users(id) on delete cascade,

  -- Plan comercial. Los ids son los de PLANES_INFO en index.html.
  plan                 text not null check (plan in ('semilla','germinacion','floracion','maduracion','cosecha')),
  periodo              text not null default 'mensual' check (periodo in ('mensual','anual')),
  estado               text not null default 'pendiente'
                         check (estado in ('pendiente','activa','en_gracia','impaga','pausada','cancelada')),

  -- Pasarela
  proveedor            text not null default 'mercadopago' check (proveedor in ('mercadopago')),
  proveedor_id         text unique,          -- preapproval id de MP
  proveedor_payer_id   text,                 -- payer_id de MP
  external_reference   text,                 -- owner_id|plan|periodo
  init_point           text,                 -- URL del checkout de MP
  entorno              text not null default 'test' check (entorno in ('test','prod')),

  -- Importes. importe_ars es lo que MP debita (ya incluye IVA).
  -- Guardamos también la base en USD y el TC del alta para poder detectar
  -- desfasajes cuando se mueve el dólar y reajustar a mano (política elegida:
  -- monto fijo, reajuste manual desde el endpoint admin).
  importe_ars          numeric(14,2) not null check (importe_ars >= 0),
  moneda               text not null default 'ARS' check (moneda in ('ARS')),
  importe_usd          numeric(12,2),        -- base sin IVA
  iva_pct              numeric(5,2) not null default 21,
  tc_alta              numeric(12,4),        -- dólar BNA vendedor usado al crear

  -- Ciclo
  periodo_inicio       timestamptz,
  periodo_fin          timestamptz,
  proximo_cobro        timestamptz,
  gracia_hasta         timestamptz,          -- seteado al primer cobro fallido
  cancelada_en         timestamptz,

  raw                  jsonb,                -- último payload de MP (debug)
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

create index if not exists idx_suscripciones_owner        on public.suscripciones(owner_id);
create index if not exists idx_suscripciones_owner_estado on public.suscripciones(owner_id, estado);
create index if not exists idx_suscripciones_proveedor_id on public.suscripciones(proveedor_id);
create index if not exists idx_suscripciones_prox_cobro   on public.suscripciones(proximo_cobro);

-- Una sola suscripción "viva" por usuario. Las canceladas quedan como
-- histórico, así que el índice único es parcial.
create unique index if not exists idx_suscripciones_una_viva
  on public.suscripciones(owner_id)
  where estado in ('pendiente','activa','en_gracia','impaga','pausada');

create or replace function public.touch_suscripciones_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists trg_suscripciones_updated_at on public.suscripciones;
create trigger trg_suscripciones_updated_at
  before update on public.suscripciones
  for each row execute function public.touch_suscripciones_updated_at();

-- ── RLS: 4 policies explícitas (NO usar FOR ALL — ver CLAUDE.md) ──
-- El usuario SOLO lee. Las tres policies de escritura existen de forma
-- explícita pero deniegan siempre: si el frontend pudiera hacer UPDATE, un
-- usuario se pondría estado='activa' y plan='cosecha' desde la consola y
-- volveríamos al agujero de user_metadata. Todas las escrituras entran por el
-- webhook de Railway con SUPABASE_SERVICE_KEY, que saltea RLS.
alter table public.suscripciones enable row level security;

drop policy if exists "suscripciones_select" on public.suscripciones;
create policy "suscripciones_select" on public.suscripciones
  for select using (owner_id = auth.uid());

drop policy if exists "suscripciones_insert" on public.suscripciones;
create policy "suscripciones_insert" on public.suscripciones
  for insert with check (false);

drop policy if exists "suscripciones_update" on public.suscripciones;
create policy "suscripciones_update" on public.suscripciones
  for update using (false) with check (false);

drop policy if exists "suscripciones_delete" on public.suscripciones;
create policy "suscripciones_delete" on public.suscripciones
  for delete using (false);


-- ═══════════════════════════════════════════════════════════════════════════
-- 2) suscripcion_pagos — historial / comprobantes
-- ═══════════════════════════════════════════════════════════════════════════
-- Una fila por cobro que MP nos informa vía el topic
-- subscription_authorized_payment (y por el pago inicial vía topic payment).

create table if not exists public.suscripcion_pagos (
  id                   uuid primary key default gen_random_uuid(),
  owner_id             uuid not null references auth.users(id) on delete cascade,
  suscripcion_id       uuid references public.suscripciones(id) on delete set null,

  proveedor            text not null default 'mercadopago',
  proveedor_pago_id    text unique,          -- authorized_payment id (o payment id)
  proveedor_preapproval_id text,             -- redundante pero útil para conciliar

  estado               text not null default 'pendiente'
                         check (estado in ('aprobado','rechazado','pendiente','reintegrado','cancelado')),
  importe              numeric(14,2) not null default 0,
  moneda               text not null default 'ARS',
  fecha                timestamptz not null default now(),
  periodo_desde        timestamptz,
  periodo_hasta        timestamptz,

  -- Datos para el comprobante que ve el usuario. NUNCA guardamos el número de
  -- tarjeta completo: MP solo nos da marca y últimos 4 dígitos.
  metodo               text,                 -- visa | master | account_money | ...
  ultimos4             text check (ultimos4 is null or ultimos4 ~ '^[0-9]{4}$'),
  motivo_rechazo       text,

  raw                  jsonb,
  created_at           timestamptz not null default now()
);

create index if not exists idx_sus_pagos_owner   on public.suscripcion_pagos(owner_id);
create index if not exists idx_sus_pagos_sus     on public.suscripcion_pagos(suscripcion_id);
create index if not exists idx_sus_pagos_fecha   on public.suscripcion_pagos(owner_id, fecha desc);

-- ── RLS: 4 policies explícitas. Mismo criterio: lectura del dueño, escrituras
-- solo desde el service_role del webhook.
alter table public.suscripcion_pagos enable row level security;

drop policy if exists "suscripcion_pagos_select" on public.suscripcion_pagos;
create policy "suscripcion_pagos_select" on public.suscripcion_pagos
  for select using (owner_id = auth.uid());

drop policy if exists "suscripcion_pagos_insert" on public.suscripcion_pagos;
create policy "suscripcion_pagos_insert" on public.suscripcion_pagos
  for insert with check (false);

drop policy if exists "suscripcion_pagos_update" on public.suscripcion_pagos;
create policy "suscripcion_pagos_update" on public.suscripcion_pagos
  for update using (false) with check (false);

drop policy if exists "suscripcion_pagos_delete" on public.suscripcion_pagos;
create policy "suscripcion_pagos_delete" on public.suscripcion_pagos
  for delete using (false);


-- ═══════════════════════════════════════════════════════════════════════════
-- 3) Vista de conveniencia — suscripción vigente por usuario
-- ═══════════════════════════════════════════════════════════════════════════
-- El frontend puede leer directo la tabla (RLS ya filtra por auth.uid()),
-- pero la vista deja explícito cuál es "la" suscripción cuando hay histórico.

create or replace view public.v_suscripcion_vigente as
select distinct on (owner_id) *
from public.suscripciones
where estado in ('pendiente','activa','en_gracia','impaga','pausada')
order by owner_id, created_at desc;
