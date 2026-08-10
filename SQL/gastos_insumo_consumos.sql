-- ═══════════════════════════════════════════════════════════════════════════
-- Multi-ubicación en el descuento de stock del gasto
-- ═══════════════════════════════════════════════════════════════════════════
--
-- Contexto: hasta ahora un gasto podía vincularse a UN solo insumo (insumo_id)
-- y le descontaba `cantidad × ha_aplicadas` unidades. Cuando el usuario tenía
-- el mismo producto repartido en varias ubicaciones (ej. Glifosato en Depósito
-- Central y en Galpón Fraga), no podía dividir el consumo entre las dos.
--
-- Esta migración agrega una columna JSONB opcional `insumo_consumos` que
-- almacena un array de consumos por ubicación:
--
--   [
--     {"insumo_id": "uuid-1", "cantidad_total": 3000, "precio": 8.50},
--     {"insumo_id": "uuid-2", "cantidad_total": 2000, "precio": 9.00}
--   ]
--
-- - `cantidad_total`: unidades totales (L, kg, dosis) — NO es por hectárea
-- - `precio`: USD por unidad
--
-- Backward compat:
-- - Gastos viejos con `insumo_id` (single) siguen funcionando sin cambios.
-- - Al editar un gasto viejo, si se elige >1 ubicación se pobla
--   `insumo_consumos` y se conserva `insumo_id` apuntando al primero.
--
-- Nada más cambia: `total_de_usd` sigue siendo la fuente de verdad para
-- Rentabilidad, PDF, CSV, etc.

ALTER TABLE gastos ADD COLUMN IF NOT EXISTS insumo_consumos jsonb;

-- Verificar
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'gastos' AND column_name = 'insumo_consumos';
-- Esperado: data_type = 'jsonb', is_nullable = 'YES'
