-- ─────────────────────────────────────────────────────────────────────────────
-- Gastos: columna cultivo
-- Aplicada via MCP el 2026-06-30
--
-- En campos multi-cultivo, los gastos pueden ser específicos de un cultivo
-- (semilla, fungi de etapa específica) o compartidos del campo (flete,
-- cosecha conjunta, arrendamiento, barbecho). Antes de esta columna, el
-- frontend ya escribía `cultivo` en el payload del INSERT pero la columna
-- no existía — PostgREST tiraba el campo silenciosamente y todos los
-- gastos quedaban sin cultivo asignado, lo que causaba duplicación en
-- la rentabilidad por cultivo (el mismo gasto contaba en c/u).
--
-- Convención post-migración:
--   - cultivo NOT NULL → gasto específico de ese cultivo, no se reparte.
--   - cultivo NULL    → gasto compartido del campo; el frontend lo reparte
--                       proporcional a las hectáreas de cada cultivo
--                       (líneas 3331 y 12442 de index.html).
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.gastos add column if not exists cultivo text;
