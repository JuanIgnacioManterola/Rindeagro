-- ─────────────────────────────────────────────────────────────────────────────
-- Tareas: comentario al completar + insumos: factura asociada
-- Aplicada via MCP el 2026-05-16
-- ─────────────────────────────────────────────────────────────────────────────

-- 1) tareas: comentario al completar + quién la realizó
alter table public.tareas
  add column if not exists comentario_completado text,
  add column if not exists completado_por uuid references auth.users(id) on delete set null;

create index if not exists idx_tareas_completado_por on public.tareas(completado_por);

-- 2) stock_insumos: factura/remito asociado (URL pública + path Storage)
alter table public.stock_insumos
  add column if not exists factura_url text,
  add column if not exists factura_path text,
  add column if not exists factura_tipo text check (factura_tipo in ('factura','remito') or factura_tipo is null);

-- 3) Bucket de Storage para facturas de insumos
insert into storage.buckets (id, name, public)
values ('insumos-facturas','insumos-facturas', true)
on conflict (id) do nothing;

-- 4) Policies de Storage: cada usuario lee/escribe sólo en su propio prefijo (carpeta = uid)
drop policy if exists "insumos_facturas_select" on storage.objects;
create policy "insumos_facturas_select"
  on storage.objects for select
  using (bucket_id = 'insumos-facturas');

drop policy if exists "insumos_facturas_insert" on storage.objects;
create policy "insumos_facturas_insert"
  on storage.objects for insert
  with check (bucket_id = 'insumos-facturas' and auth.uid()::text = (storage.foldername(name))[1]);

drop policy if exists "insumos_facturas_update" on storage.objects;
create policy "insumos_facturas_update"
  on storage.objects for update
  using (bucket_id = 'insumos-facturas' and auth.uid()::text = (storage.foldername(name))[1]);

drop policy if exists "insumos_facturas_delete" on storage.objects;
create policy "insumos_facturas_delete"
  on storage.objects for delete
  using (bucket_id = 'insumos-facturas' and auth.uid()::text = (storage.foldername(name))[1]);
