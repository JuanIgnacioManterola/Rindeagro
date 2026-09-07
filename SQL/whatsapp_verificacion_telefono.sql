-- Verificación del número de WhatsApp.
--
-- Sostiene los dos caminos que implementa el server:
--   · OTP saliente — la web pide un código, el bot lo manda por WhatsApp y el
--     usuario lo tipea en la web (POST /whatsapp/verificacion/enviar y
--     /confirmar).
--   · OTP inverso  — la web muestra un código y el usuario se lo escribe al bot
--     ("VINCULAR ABC123"). Es el que arregla el caso del dígito mal tipeado:
--     queda verificado el número DESDE EL QUE ESCRIBE, no el que había cargado.
--
-- Las dos tablas se tocan SOLO desde el server con service_role: el frontend
-- llama a los endpoints, nunca a Supabase directo. Por eso van con RLS prendida
-- y CERO policies — así ni anon ni authenticated pueden leer los hashes de los
-- códigos ni los contadores de rate limit.

-- ──────────────────────────────────────────────────────────────
-- 1. perfiles: marcar el número como verificado
-- ──────────────────────────────────────────────────────────────
-- OJO: el default es false, así que al aplicar esto TODOS los usuarios que hoy
-- usan el bot pasan a estar "sin verificar" y el bot deja de reconocerlos hasta
-- que verifiquen. Es a propósito (que el número esté cargado en el perfil no
-- prueba que sea suyo), pero conviene avisarles antes de aplicarla.

alter table public.perfiles
  add column if not exists telefono_verificado    boolean     not null default false,
  add column if not exists telefono_verificado_en timestamptz;

-- Un número verificado pertenece a UNA sola cuenta. Sin esto, dos perfiles
-- podrían quedar verificados con el mismo teléfono y el bot no sabría a quién
-- servirle los datos.
create unique index if not exists perfiles_telefono_verificado_unico
  on public.perfiles (telefono)
  where telefono_verificado is true;

-- ──────────────────────────────────────────────────────────────
-- 2. verificaciones_telefono — códigos emitidos
-- ──────────────────────────────────────────────────────────────

create table if not exists public.verificaciones_telefono (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references auth.users(id) on delete cascade,
  telefono         text not null,           -- normalizado, solo dígitos
  telefono_display text,                    -- como lo tipeó el usuario
  codigo_hash      text not null,           -- sha256(user_id + ':' + código)
  metodo           text not null default 'saliente'
                     check (metodo in ('saliente', 'inverso')),
  intentos         integer not null default 0,
  usado            boolean not null default false,
  usado_en         timestamptz,
  expira_en        timestamptz not null,
  verificado_desde text,                    -- número real del que llegó el VINCULAR
  created_at       timestamptz not null default now()
);

-- El flujo inverso busca entre TODOS los códigos vivos (no sabe de qué usuario
-- es hasta comparar el hash), así que este índice es el que sostiene la query.
create index if not exists verificaciones_telefono_vivos
  on public.verificaciones_telefono (expira_en)
  where usado = false;

create index if not exists verificaciones_telefono_user
  on public.verificaciones_telefono (user_id, metodo, created_at desc);

alter table public.verificaciones_telefono enable row level security;
-- Sin policies a propósito: solo service_role.

-- ──────────────────────────────────────────────────────────────
-- 3. wa_verificacion_intentos — rate limit por número entrante
-- ──────────────────────────────────────────────────────────────
-- Vive en la base y no en memoria del proceso: Railway reinicia seguido y un
-- contador en RAM se resetea con cada deploy, que es justo lo que necesitaría
-- alguien para probar códigos sin límite.

create table if not exists public.wa_verificacion_intentos (
  numero          text primary key,         -- normalizado, solo dígitos
  intentos        integer not null default 0,
  ventana_inicio  timestamptz not null default now(),
  bloqueado_hasta timestamptz,
  actualizado_en  timestamptz not null default now()
);

alter table public.wa_verificacion_intentos enable row level security;
-- Sin policies a propósito: solo service_role.
