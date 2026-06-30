-- ─────────────────────────────────────────────────────────────────────────────
-- Pagos: archivo asociado + fuente del registro
-- Aplicada via MCP el 2026-05-17
--
-- Permite asociar foto/PDF a cada compromiso de pago. fuente trackea el
-- origen para distinguir altas manuales, vía OCR de foto, y vía WhatsApp
-- (cuando el bot esté activo).
-- ─────────────────────────────────────────────────────────────────────────────

alter table public.compromisos_pago
  add column if not exists archivo_url  text,
  add column if not exists archivo_path text,
  add column if not exists fuente       text not null default 'manual'
    check (fuente in ('manual','foto','whatsapp'));

create index if not exists idx_compromisos_fuente on public.compromisos_pago(owner_id, fuente);

-- Bucket de Storage para archivos de pagos
insert into storage.buckets (id, name, public)
values ('pagos-archivos','pagos-archivos', true)
on conflict (id) do nothing;

drop policy if exists "pagos_archivos_select" on storage.objects;
create policy "pagos_archivos_select"
  on storage.objects for select
  using (bucket_id = 'pagos-archivos');

drop policy if exists "pagos_archivos_insert" on storage.objects;
create policy "pagos_archivos_insert"
  on storage.objects for insert
  with check (bucket_id = 'pagos-archivos' and auth.uid()::text = (storage.foldername(name))[1]);

drop policy if exists "pagos_archivos_update" on storage.objects;
create policy "pagos_archivos_update"
  on storage.objects for update
  using (bucket_id = 'pagos-archivos' and auth.uid()::text = (storage.foldername(name))[1]);

drop policy if exists "pagos_archivos_delete" on storage.objects;
create policy "pagos_archivos_delete"
  on storage.objects for delete
  using (bucket_id = 'pagos-archivos' and auth.uid()::text = (storage.foldername(name))[1]);
