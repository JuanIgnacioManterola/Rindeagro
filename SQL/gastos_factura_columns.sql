-- ═════════════════════════════════════════════════════════════════════════════
-- Gastos: columnas factura_url, factura_path, factura_tipo
-- Aplicada via MCP el 2026-07-01
-- ═════════════════════════════════════════════════════════════════════════════
-- Permite adjuntar factura o remito (foto o PDF) al cargar un gasto de
-- cualquier rubro (herbicidas, laboreo, arrendamiento, flete, empleados, etc.).
-- Antes solo Insumos tenía este flujo. Reutiliza el bucket Storage
-- `insumos-facturas` — el path incluye owner_id + timestamp, no hay colisión
-- con archivos de insumos.
--
-- factura_tipo tiene check constraint: 'factura' o 'remito' (o null).
-- Los tres campos son nullable — la carga de factura es opcional.
-- ═════════════════════════════════════════════════════════════════════════════

alter table public.gastos
  add column if not exists factura_url text,
  add column if not exists factura_path text,
  add column if not exists factura_tipo text check (factura_tipo in ('factura','remito') or factura_tipo is null);
