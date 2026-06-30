-- ─────────────────────────────────────────────────────────────────────────────
-- Pagos: renombrar 'cobrado' por 'pagado' en estado
-- Aplicada via MCP el 2026-05-17
--
-- El usuario es quien PAGA (no quien cobra). Cambiamos el value del enum
-- por coherencia semántica con el flujo real del módulo.
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.compromisos_pago drop constraint if exists compromisos_pago_estado_check;
update public.compromisos_pago set estado = 'pagado' where estado = 'cobrado';
alter table public.compromisos_pago
  add constraint compromisos_pago_estado_check
  check (estado in ('pendiente','pagado','vencido','cancelado'));
