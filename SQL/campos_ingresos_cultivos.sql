-- ─────────────────────────────────────────────────────────────────────────────
-- Campos: columnas ingresos_cultivos y hectareas_cultivo
-- Aplicada via MCP el 2026-06-30
--
-- El frontend escribe estos dos campos en `campos.update(...)` desde hace tiempo
-- (tab Ingresos: ventas/contratos forward por cultivo + asignación de ha por
-- cultivo en campos mixtos). El código tenía un fallback silencioso que
-- toleraba la ausencia de las columnas — es decir: NUNCA persistían en DB,
-- solo vivían en el cache local y se perdían al refrescar.
--
-- Esta migración agrega ambas columnas como text nullable (la app las parsea
-- como JSON pero el formato lo controla el frontend). El fallback en
-- `index.html` (línea ~12333) queda intacto a propósito para que el código
-- siga siendo robusto si alguien usa una DB sin esta migración.
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.campos
  add column if not exists ingresos_cultivos text,
  add column if not exists hectareas_cultivo text;
