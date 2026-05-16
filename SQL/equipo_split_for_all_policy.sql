-- ─────────────────────────────────────────────────────────────────────────────
-- Equipo: dividir policy FOR ALL en 4 policies explícitas
-- Aplicada via MCP el 2026-05-16
--
-- Síntoma: SELECT a public.equipo se colgaba 10+ segundos sin responder
-- desde el cliente (con sesión válida). Misma solución que se aplicó a
-- public.invitaciones según el CLAUDE.md.
-- ─────────────────────────────────────────────────────────────────────────────

drop policy if exists "owner_manage_equipo" on public.equipo;

create policy "owner_select_equipo"
  on public.equipo for select
  using (auth.uid() = owner_id);

create policy "owner_insert_equipo"
  on public.equipo for insert
  with check (auth.uid() = owner_id);

create policy "owner_update_equipo"
  on public.equipo for update
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

create policy "owner_delete_equipo"
  on public.equipo for delete
  using (auth.uid() = owner_id);
