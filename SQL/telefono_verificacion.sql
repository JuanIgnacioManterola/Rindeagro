-- ═══════════════════════════════════════════════════════════════════════════
-- Migración: verificación de propiedad del número de WhatsApp
-- ═══════════════════════════════════════════════════════════════════════════
-- Problema que resuelve: hasta ahora el usuario tipeaba su número en el
-- registro y el sistema le creía. Un dígito mal tipeado alcanzaba para que el
-- bot de WhatsApp le sirviera los datos de un productor a otra persona (y para
-- que las notificaciones salientes fueran a un desconocido).
--
-- Mecanismo (uno solo, igual para dueño y para operario invitado):
--   1. La web genera un código de 6 caracteres, lo hashea y guarda la fila acá.
--   2. El usuario le escribe "VINCULAR <codigo>" al WhatsApp del bot.
--   3. El bot (service_role) matchea el hash, marca la fila usada y setea
--      perfiles.telefono_verificado = true con el número REAL del remitente.
--
-- La invitación prueba que a alguien lo invitaron. Esto prueba que el número
-- es suyo. Son cosas distintas y hacen falta las dos.
--
-- Convención del proyecto: RLS con 4 policies explícitas, NUNCA `for all`.
-- ═══════════════════════════════════════════════════════════════════════════


-- ── 1. Normalizador de teléfonos (espejo de kapso.normalizar_numero) ─────────
-- Argentina se marca con un 9 después del código de país (+54 9 2944 56-5308)
-- pero WhatsApp identifica al usuario SIN ese 9 (542944565308). Los perfiles
-- están guardados CON el 9. Sin normalizar, nada matchea. Mismo caso en México
-- con el 1. Tiene que ser IMMUTABLE para poder indexar sobre ella.

create or replace function public.normalizar_telefono(numero text)
returns text
language plpgsql
immutable
as $$
declare
  d text;
begin
  if numero is null then
    return null;
  end if;
  d := regexp_replace(numero, '\D', '', 'g');
  if d = '' then
    return null;
  end if;
  -- 00 como prefijo internacional
  if left(d, 2) = '00' then
    d := substr(d, 3);
  end if;
  -- Argentina: 54 9 XXXXXXXXXX → 54 XXXXXXXXXX
  if left(d, 3) = '549' and length(d) = 13 then
    d := '54' || substr(d, 4);
  end if;
  -- México: 52 1 XXXXXXXXXX → 52 XXXXXXXXXX
  if left(d, 3) = '521' and length(d) = 13 then
    d := '52' || substr(d, 4);
  end if;
  return d;
end;
$$;

comment on function public.normalizar_telefono(text) is
  'Devuelve el teléfono como lo identifica WhatsApp: solo dígitos, sin el 9 de AR ni el 1 de MX. Espejo exacto de kapso.normalizar_numero() en el server.';


-- ── 2. Columnas de verificación en `perfiles` ────────────────────────────────

alter table public.perfiles
  add column if not exists telefono_verificado boolean not null default false;

alter table public.perfiles
  add column if not exists telefono_verificado_en timestamptz;

comment on column public.perfiles.telefono_verificado is
  'true solo si el dueño del número mandó el código por WhatsApp. El bot NO atiende a números no verificados. Lo setea únicamente service_role (ver trigger tg_perfiles_guard_verificacion).';

-- Un número verificado pertenece a UNA sola cuenta. Para re-vincularlo hay que
-- desvincularlo antes (poner telefono_verificado = false en la otra cuenta).
-- El índice es parcial: los números sin verificar pueden repetirse sin drama.
create unique index if not exists ux_perfiles_telefono_verificado
  on public.perfiles (public.normalizar_telefono(telefono))
  where telefono_verificado = true;


-- ── 3. Guard: el usuario no puede auto-verificarse ───────────────────────────
-- El frontend escribe en `perfiles` con el JWT del usuario, así que sin este
-- trigger cualquiera podría hacer un PATCH telefono_verificado=true y saltearse
-- todo el flujo. Solo service_role (el bot) puede marcar la verificación.
-- Y si el usuario cambia el número, la verificación se cae sola.

create or replace function public.tg_perfiles_guard_verificacion()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  -- El bot, las edge functions y el admin de la consola pasan derecho.
  if current_user in ('service_role', 'postgres', 'supabase_admin') then
    return new;
  end if;

  if tg_op = 'INSERT' then
    -- Nadie nace verificado.
    new.telefono_verificado := false;
    new.telefono_verificado_en := null;
    return new;
  end if;

  -- UPDATE: no se puede prender la verificación a mano.
  if new.telefono_verificado and not coalesce(old.telefono_verificado, false) then
    raise exception 'telefono_verificado solo puede setearlo el bot tras validar el código de WhatsApp'
      using errcode = '42501';
  end if;

  -- Cambiar el número desverifica automáticamente: el código anterior probaba
  -- la posesión del número viejo, no del nuevo.
  if public.normalizar_telefono(new.telefono)
       is distinct from public.normalizar_telefono(old.telefono) then
    new.telefono_verificado := false;
    new.telefono_verificado_en := null;
  end if;

  return new;
end;
$$;

drop trigger if exists tg_perfiles_verificacion on public.perfiles;
create trigger tg_perfiles_verificacion
  before insert or update on public.perfiles
  for each row execute function public.tg_perfiles_guard_verificacion();


-- ── 4. Tabla de códigos de verificación ──────────────────────────────────────
-- El código NUNCA se guarda en claro: se guarda sha256(user_id || ':' || código
-- en mayúsculas). Meter el user_id adentro del hash hace que una tabla arcoíris
-- no sirva y que un código no se pueda mover de una fila a otra.

create table if not exists public.verificaciones_telefono (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  -- Número normalizado que el usuario dice tener. Informativo: el flujo inverso
  -- confía en el número REAL del remitente, no en este.
  telefono text,
  -- Lo que el usuario tipeó, tal cual, para poder mostrarle "cargaste X".
  telefono_display text,
  codigo_hash text not null,
  metodo text not null default 'inverso'
    check (metodo in ('inverso', 'saliente')),
  expira_en timestamptz not null,
  usado boolean not null default false,
  usado_en timestamptz,
  -- Número que efectivamente completó la verificación (normalizado).
  verificado_desde text,
  intentos integer not null default 0,
  created_at timestamptz not null default now()
);

comment on table public.verificaciones_telefono is
  'Códigos de verificación de WhatsApp de un solo uso. Ver "Verificación del número de WhatsApp" en CLAUDE.md.';
comment on column public.verificaciones_telefono.codigo_hash is
  'sha256(user_id || '':'' || upper(codigo)). El código en claro solo existe en la pantalla del usuario.';
comment on column public.verificaciones_telefono.metodo is
  'inverso = el usuario le escribe VINCULAR <codigo> al bot (camino principal). saliente = el bot le manda 6 dígitos y los tipea en la web (fallback).';

-- El bot busca códigos vivos: no usados y no vencidos.
create index if not exists ix_verif_tel_pendientes
  on public.verificaciones_telefono (expira_en)
  where usado = false;

create index if not exists ix_verif_tel_user
  on public.verificaciones_telefono (user_id, created_at desc);

-- ── RLS: cada uno ve y maneja solo sus propios códigos ───────────────────────
alter table public.verificaciones_telefono enable row level security;

drop policy if exists owner_select_verif_tel on public.verificaciones_telefono;
drop policy if exists owner_insert_verif_tel on public.verificaciones_telefono;
drop policy if exists owner_update_verif_tel on public.verificaciones_telefono;
drop policy if exists owner_delete_verif_tel on public.verificaciones_telefono;

create policy owner_select_verif_tel on public.verificaciones_telefono
  for select using (auth.uid() = user_id);
create policy owner_insert_verif_tel on public.verificaciones_telefono
  for insert with check (auth.uid() = user_id);
create policy owner_update_verif_tel on public.verificaciones_telefono
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy owner_delete_verif_tel on public.verificaciones_telefono
  for delete using (auth.uid() = user_id);


-- ── 5. Rate limiting persistente por número entrante ─────────────────────────
-- El límite tiene que sobrevivir a los reinicios de Railway, así que va en DB y
-- no en memoria del proceso. Solo la toca el bot: RLS prendida y CERO policies
-- deja la tabla accesible únicamente desde service_role.

create table if not exists public.wa_verificacion_intentos (
  numero text primary key,
  intentos integer not null default 0,
  ventana_inicio timestamptz not null default now(),
  bloqueado_hasta timestamptz,
  actualizado_en timestamptz not null default now()
);

comment on table public.wa_verificacion_intentos is
  'Anti fuerza bruta del comando VINCULAR, por número entrante. Sin policies a propósito: solo service_role.';

alter table public.wa_verificacion_intentos enable row level security;


-- ── 6. Limpieza de códigos vencidos ──────────────────────────────────────────
-- Los códigos usados/vencidos no sirven para nada y solo hacen ruido. Se van a
-- los 7 días. Corre con el mismo pg_cron del pipeline de precios.

create or replace function public.limpiar_verificaciones_vencidas()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.verificaciones_telefono
   where created_at < now() - interval '7 days';
  delete from public.wa_verificacion_intentos
   where actualizado_en < now() - interval '7 days';
$$;

select cron.unschedule('limpiar-verificaciones-telefono')
 where exists (select 1 from cron.job where jobname = 'limpiar-verificaciones-telefono');

select cron.schedule(
  'limpiar-verificaciones-telefono',
  '17 4 * * *',                        -- 04:17 UTC ≈ 01:17 ARG, todos los días
  $$select public.limpiar_verificaciones_vencidas()$$
);


-- ═══════════════════════════════════════════════════════════════════════════
-- BACKFILL OPCIONAL — leer antes de correr
-- ═══════════════════════════════════════════════════════════════════════════
-- Después de esta migración TODOS los perfiles quedan sin verificar, así que el
-- bot deja de atender a todo el mundo hasta que cada uno mande su código. Es el
-- comportamiento correcto y deseado.
--
-- Si querés grandfatherear cuentas concretas (por ejemplo la tuya, para no
-- quedarte afuera mientras probás), descomentá y poné los UUID a mano. NO lo
-- corras sobre toda la tabla: sería tirar a la basura el motivo de la migración.
--
-- update public.perfiles
--    set telefono_verificado = true,
--        telefono_verificado_en = now()
--  where id in ('ea80343b-b31d-4cba-a43e-00c3f0a3fa39')
--    and telefono is not null;
