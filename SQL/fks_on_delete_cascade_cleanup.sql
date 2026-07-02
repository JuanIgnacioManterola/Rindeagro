-- ═════════════════════════════════════════════════════════════════════════════
-- FKs: migrar NO ACTION → CASCADE / SET NULL donde corresponde
-- Aplicada via MCP el 2026-07-02
-- ═════════════════════════════════════════════════════════════════════════════
-- Motivación: hasta ahora borrar un `auth.users` fallaba porque las tablas
-- gastos, lluvias, analisis_suelo, campanas, eventos y mensajes_wa referencian
-- `perfiles(id)` via `usuario_id` con NO ACTION. Como perfiles se borra en
-- cascada al borrar el user, la cadena se rompía. Requería transacciones
-- manuales para limpiar un usuario.
--
-- Cambios:
--
-- CASCADE (borrar en cadena — es data del mismo user):
--   gastos.usuario_id, lluvias.usuario_id, eventos.usuario_id,
--   analisis_suelo.usuario_id, campanas.usuario_id, mensajes_wa.usuario_id
--
-- SET NULL (mantener el registro pero desasociar):
--   gastos.campana_id → si se borra una campaña, los gastos siguen existiendo
--     pero pierden la referencia (útil para histórico).
--   mensajes_wa.evento_creado → similar (auditoría).
--   precios_pizarra.actualizado_por → auditoría, no queremos borrar precios
--     históricos al borrar el user que los cargó.
--   perfiles.agronomo_id → si se elimina un agrónomo, sus productores mantienen
--     el perfil pero sin agrónomo asociado.
-- ═════════════════════════════════════════════════════════════════════════════

alter table public.gastos drop constraint gastos_usuario_id_fkey;
alter table public.gastos add constraint gastos_usuario_id_fkey
  foreign key (usuario_id) references public.perfiles(id) on delete cascade;

alter table public.lluvias drop constraint lluvias_usuario_id_fkey;
alter table public.lluvias add constraint lluvias_usuario_id_fkey
  foreign key (usuario_id) references public.perfiles(id) on delete cascade;

alter table public.eventos drop constraint eventos_usuario_id_fkey;
alter table public.eventos add constraint eventos_usuario_id_fkey
  foreign key (usuario_id) references public.perfiles(id) on delete cascade;

alter table public.analisis_suelo drop constraint analisis_suelo_usuario_id_fkey;
alter table public.analisis_suelo add constraint analisis_suelo_usuario_id_fkey
  foreign key (usuario_id) references public.perfiles(id) on delete cascade;

alter table public.campanas drop constraint campanas_usuario_id_fkey;
alter table public.campanas add constraint campanas_usuario_id_fkey
  foreign key (usuario_id) references public.perfiles(id) on delete cascade;

alter table public.mensajes_wa drop constraint mensajes_wa_usuario_id_fkey;
alter table public.mensajes_wa add constraint mensajes_wa_usuario_id_fkey
  foreign key (usuario_id) references public.perfiles(id) on delete cascade;

-- SET NULL: mantener registro histórico o auditoría
alter table public.gastos drop constraint gastos_campana_id_fkey;
alter table public.gastos add constraint gastos_campana_id_fkey
  foreign key (campana_id) references public.campanas(id) on delete set null;

alter table public.mensajes_wa drop constraint mensajes_wa_evento_creado_fkey;
alter table public.mensajes_wa add constraint mensajes_wa_evento_creado_fkey
  foreign key (evento_creado) references public.eventos(id) on delete set null;

alter table public.precios_pizarra drop constraint precios_pizarra_actualizado_por_fkey;
alter table public.precios_pizarra add constraint precios_pizarra_actualizado_por_fkey
  foreign key (actualizado_por) references auth.users(id) on delete set null;

alter table public.perfiles drop constraint perfiles_agronomo_id_fkey;
alter table public.perfiles add constraint perfiles_agronomo_id_fkey
  foreign key (agronomo_id) references public.perfiles(id) on delete set null;
