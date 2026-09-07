# Rinde.Agro

App para gestión agropecuaria. Frontend single-file HTML + backend FastAPI + Supabase.

## Stack

- **Frontend:** `index.html` (~600KB, single-file) publicado en GitHub Pages → **https://rindeagro.app** (dominio custom). El `CNAME` en la raíz del repo apunta a `rindeagro.app`. URL legacy `juanignaciomanterola.github.io/Rindeagro/` también funciona.
- **Backend:** FastAPI en `/Users/juanignaciomanterola/rindeagro-server/main.py`, deployado en Railway
- **DB/Auth:** Supabase JS v2 en frontend + Supabase REST API desde el server
- **Repo frontend:** https://github.com/JuanIgnacioManterola/Rindeagro
- **Edge function OCR:** `supabase/functions/ocr-factura/index.ts` (desplegada). Necesita secret `ANTHROPIC_API_KEY` en Supabase Edge Functions para que funcione la lectura automática de facturas.

## Workflow de git (obligatorio)

Nunca commitear directo a `main`.

```bash
git checkout -b feat/nombre   # o fix/nombre
# ...cambios y commits...
git push origin nombre-rama
gh pr create
gh pr merge N --merge --delete-branch
```

## Preview local

```bash
cd /Users/juanignaciomanterola/Rindeagro
python3 -m http.server 8787
```

Si el puerto está ocupado: `lsof -i :8787` → `kill <PID>`.

`.claude/launch.json` tiene `autoPort: true`.

## Notas del schema de Supabase

Detalles que rompieron cosas antes — no revertir:

- Tabla `perfiles` usa columna `telefono` (no `whatsapp`). El server de Railway depende de este nombre.
- Tabla `invitaciones` tiene 4 policies RLS explícitas (SELECT/INSERT/UPDATE/DELETE). Un `FOR ALL` único causó problemas.
- **Tabla `equipo`**: ídem invitaciones — 4 policies explícitas. La policy original `owner_manage_equipo` (FOR ALL) causaba que los SELECT del modal "Mi equipo" se colgaran 10+s sin responder. Reemplazada por `owner_select_equipo` / `owner_insert_equipo` / `owner_update_equipo` / `owner_delete_equipo`. La policy `miembro_ver_equipo` (auth.uid() = miembro_id) y `miembro_aceptar_invitacion` quedan sin cambios.
- **Tabla `equipo` — columnas**: `miembro_id` (NO `colaborador_id`) y `nombre_display` (NO `nombre`). Cualquier código que itere `_equipoCache` tiene que usar estos nombres.
- **Tabla `tareas`**: usa columna `estado` (text con valores `pendiente|en_progreso|programada|completada`) — NO existe columna boolean `completada`. El payload de INSERT no debe incluir `completada:false` (causa error "column does not exist in schema cache").
- **Tabla `tareas` — columnas nuevas**: `comentario_completado` (text), `completado_por` (uuid FK a auth.users on delete set null). Aplicadas via migración `SQL/tareas_comentario_y_insumos_factura.sql`.
- **Tabla `campos` — columnas `ingresos_cultivos` y `hectareas_cultivo`** (text, nullable, ambas guardan JSON serializado): `ingresos_cultivos` guarda por cultivo el `{rendimiento, precio_venta, hectareas, ventas:[{tn,precio,tipo:'spot'|'forward',comprador,fecha,fecha_entrega?}]}` cargado en el tab Ingresos. `hectareas_cultivo` guarda el `{cultivo: ha}` cuando el campo es mixto y se asignan ha por cultivo desde el polígono o manualmente. El frontend tiene un fallback silencioso en `guardarIngresos` (línea ~12333) que rescata el `update` si la columna no existe — dejarlo, hace al código robusto contra DBs sin la migración `SQL/campos_ingresos_cultivos.sql`.
- **Tabla `stock_insumos`**: tabla del módulo Stock de Insumos. Columnas: `id`, `owner_id`, `nombre`, `tipo` (herbicidas|fungicidas|insecticidas|fertilizantes|semillas|otros), `unidad` (litros|kg|dosis|bolsas), `stock_actual` (numeric, check >= 0), `costo_unitario`, `ubicacion`, `notas`, `factura_url`, `factura_path`, `factura_tipo` (factura|remito), `created_at`, `updated_at`. 4 policies RLS explícitas (owner-only).
- **Tabla `gastos`**: columna `insumo_id` (uuid FK a stock_insumos, nullable, on delete set null). Cuando un gasto está vinculado a un insumo, se descuenta `cantidad * ha_aplicadas` del stock al guardar.
- `_renderAccesosColaborador` usa `.select('*')`, no `.select('*, owner:owner_id(id)')` — el join devolvía 400.

## Storage

- Bucket `tareas-archivos` (público) — archivos adjuntos a tareas. Path: `<owner_id>/<timestamp>_<filename>`.
- Bucket `insumos-facturas` (público) — facturas/remitos asociados a stock_insumos. Mismo path pattern. 4 policies de Storage explícitas (owner-only por carpeta = uid).

## Bug crítico del SDK de Supabase — workaround REST fallback

**Síntoma**: el cliente `supabase-js` queda colgado internamente (no dispara la HTTP request, no resuelve, no rechaza). Afecta SELECT, INSERT, UPDATE, DELETE y Storage upload. Se manifestó al usuario como modales en "Cargando..." infinito, tareas que no guardaban, archivos que no se subían.

**Workaround aplicado**: helpers REST que se saltean el SDK y van directo a la REST API de Supabase con el JWT de `localStorage['rindeagro-auth']`.

Helpers disponibles en `index.html`:
- `_getAccessTokenFromStorage()` — lee el JWT directo de localStorage.
- `_restGet(path)`, `_restPost(path, body)`, `_restPatch(path, body)`, `_restDelete(path)` — fetch directo a `/rest/v1{path}`.
- `_restStorageUpload(bucket, path, file, contentType)` — fetch directo a `/storage/v1/object/{bucket}/{path}`.
- `_dbMutate({method, table, filter:{col,val}, payload, timeout})` — helper genérico: intenta SDK con timeout, cae a REST. Para mutaciones.
- `_selectConFallback(table, {col, val, col2, val2, order})` — usado en `cargarTodo` para que cada SELECT inicial tenga su propio timeout y fallback REST.

**Convención (CRÍTICA)**: cualquier query nueva a Supabase debe seguir este patrón:
- **Lecturas** → `_restGet(path)` directo. No `sb.from(...).select(...)` sin fallback.
- **Mutaciones** (INSERT/UPDATE/DELETE) → `_dbMutate({...})` o el patrón `Promise.race([sdk, timeout])` + `_restXxx` en el catch.
- **Storage** → `_restStorageUpload(...)` con fallback a SDK.

Operaciones ya migradas: Insumos, Tareas, Gastos, archivos en Storage, **Mi Equipo + generación de invitaciones** (PR #45 de Agustina).

**Patrón optimista**: además del fallback, las mutaciones son optimistic — el cambio se aplica al estado local + render + cache YA, y la sincronización con DB pasa en background. Si la DB falla, se hace rollback con un snapshot previo.

## Auth — convenciones

- **NUNCA hardcodear URLs** en `redirectTo` / `emailRedirectTo` de Supabase Auth. Siempre `window.location.origin + window.location.pathname`. Esto vale para magic link, recuperación de contraseña, OAuth, etc. Romper esto rompe el dominio rindeagro.app (PR #39).
- **NUNCA usar `href="#"`** para placeholders en links (footer, etc). Usar `href="javascript:void(0)"`. Razón: el `#` deja un fragmento residual en la URL al hacer click y rompe el flujo de auth (PR #41).
- **`window.login` tiene un race condition con `onAuthStateChange SIGNED_IN`** (PR #40). El handler tiene un `finally { btn.disabled=false; btn.textContent='Ingresar a mi cuenta' }` que SIEMPRE debe ejecutarse. La rama `else if(data.user && usuario)` también debe llamar `closeModal()`. No tocar sin entender por qué.
- **Limpiar fragmento `#` post-auth**: dentro de `onAuthStateChange`, tanto para `INITIAL_SESSION` como para `SIGNED_IN`, se hace `history.replaceState(null, '', window.location.pathname + window.location.search)` envuelto en try/catch. No remover (PR #41).

## Módulo Pagos (compromisos_pago)

Nueva sección entre Insumos y Tareas para registrar **cheques emitidos** y **cuotas de crédito**. Tabla `public.compromisos_pago` con columnas:

`id`, `owner_id`, `tipo` (`cheque|cuota_credito`), `descripcion`, `beneficiario`, `fecha_emision`, `fecha_cobro` (NOT NULL), `importe`, `moneda` (ARS|USD), `alerta_dias_antes` (nullable — opt-in por compromiso), `estado` (`pendiente|cobrado|vencido|cancelado`), `banco`, `numero_cheque`, `credito_id` (agrupa cuotas), `numero_cuota`, `total_cuotas`, `notas`, `archivo_url`, `archivo_path`, `fuente` (`manual|foto|whatsapp` — default `'manual'`), `created_at`, `updated_at`.

4 RLS policies explícitas (owner-only) — convención del proyecto. NO usar FOR ALL.

Bucket Storage `pagos-archivos` (público) para guardar fotos/PDFs adjuntos a cada compromiso. Path: `<owner_id>/<timestamp>_<filename>`. 4 policies de Storage owner-only por carpeta.

### Formas de carga

1. **Manual** (modal `#ov-cheque` o `#ov-credito`): el usuario tipea todo. `fuente='manual'`.
2. **Foto / PDF con OCR**: modal `#ov-pago-foto` permite subir imagen o PDF. Llama edge function `ocr-pago` que devuelve JSON parseado (Claude vision). El frontend pre-llena el modal de cheque o crédito y el usuario revisa antes de guardar. `fuente='foto'`, `archivo_url/path` apunta al archivo en Storage. **Requiere `ANTHROPIC_API_KEY` configurada como secret en Edge Functions** (igual que `ocr-factura`).
3. **WhatsApp** (pendiente del bot): cuando el bot esté activo, debe insertar las filas directamente en `compromisos_pago` con `fuente='whatsapp'`. Ver "Contrato WhatsApp → Pagos" abajo.

### Edge functions de OCR para pagos

- `supabase/functions/ocr-pago/index.ts` — desplegada. Body: `{image_base64, mime_type, tipo: 'cheque'|'credito'}`. Devuelve `{ok, data: {…campos…}}`. Tuneada para cheques bancarios argentinos y vouchers/contratos de crédito.

### Contrato WhatsApp → Pagos (para el bot cuando esté activo)

El bot de WhatsApp debería poder parsear comandos como:
- "cheque 1500000 a Acopio La Hortensia vence 15/06" → INSERT con `tipo='cheque'`, `beneficiario='Acopio La Hortensia'`, `importe=1500000`, `fecha_cobro='2026-06-15'`.
- "crédito Galicia 12 cuotas de 500000 desde 15/06" → INSERT de 12 filas con `tipo='cuota_credito'`, mismo `credito_id`, `numero_cuota=1..12`, `total_cuotas=12`, fechas calculadas (mensual por default).

Reglas para el bot:
- Siempre setear `fuente='whatsapp'` para distinguir el origen en el dashboard.
- Usar `service_role` key para insert (saltea RLS porque el bot no tiene sesión auth del usuario directa — la asociación al `owner_id` correcto la hace el bot mediante `wa_conversaciones`).
- Si el usuario no da `alerta_dias_antes` explícito, dejar `null` (sin alerta). El usuario lo puede editar después desde la UI.
- Si el usuario no aclara moneda, asumir `ARS`.
- Si el usuario no da fecha de emisión, dejar `null` y usar solo `fecha_cobro`.
- Confirmar al usuario por WhatsApp después de insertar: "✓ Cargué cheque de $1.500.000 a Acopio La Hortensia, vence el 15/06".

Lectura desde el frontend: cuando el bot inserta, la app del usuario verá los nuevos compromisos en la próxima carga (`cargarTodo` o al abrir el tab Pagos vía `_refrescarPagosVistaActual`).

## Módulo Estructura (activos_amortizables + gastos_estructura)

Nueva sección en el nav entre **Rentabilidad** e **Insumos** para cargar costos que NO son de un campo específico sino de la empresa productor. Son 2 tablas RLS owner-only:

### `activos_amortizables`
Vehículos, herramientas, maquinaria, construcciones (silos, galpones). Se carga una sola vez el activo (`valor_compra_usd`, `fecha_compra`, `vida_util_anos`, `valor_residual_usd`). El sistema calcula automáticamente la amortización anual = `(valor − residual) / vida_util`. Durante el período `[fecha_compra, fecha_compra + vida_util_anos]` esa cuota anual prorrateada por días se suma al costo. Cuando termina la vida útil deja de sumar.

Columnas: `id`, `owner_id`, `descripcion`, `tipo` (`vehiculo|herramienta|maquinaria|construccion|otros`), `valor_compra_usd`, `fecha_compra`, `vida_util_anos`, `valor_residual_usd`, `distribuir_modo` (`por_hectareas|igualitario|personalizado`), `distribuir_config`, `notas`, timestamps.

### `gastos_estructura`
Sueldos, honorarios (contador/agrónomo), seguros (ART, agrícola, flota), oficina, combustible general. Recurrentes o únicos.

Columnas: `id`, `owner_id`, `descripcion`, `tipo` (`sueldo|honorarios|seguro|oficina|combustible|otros`), `importe_usd`, `frecuencia` (`unico|mensual|anual`), `fecha_inicio`, `fecha_fin` (nullable — null = indefinido), `distribuir_modo`, `distribuir_config`, `notas`, timestamps.

### Cálculos (helpers globales en `index.html`)

- `_estCuotaAnual(a)` → (valor − residual) / vida_util.
- `_estCostoActivoEnRango(a, dStart, dEnd)` → prorrateo por días del período de vida útil que intersecta el rango.
- `_estCostoGastoEnRango(g, dStart, dEnd)` → continuo, por días. Único = importe si fecha ∈ rango. Mensual = (importe/30) × días. Anual = (importe/365) × días.
- `_estructuraTotalEnRango(dStart, dEnd)` → total de activos + gastos en el rango.
- `_estructuraCostoPorCampo(campoId, dStart, dEnd)` → prorrateo por hectáreas entre todos los campos.

### Integración en Rentabilidad Total
- Nueva fila `(−) Estructura` en el P&L (fondo rojo más oscuro, `#b91c1c`) con USD/ha, USD total y % del ingreso.
- Métrica "Costos totales" incluye estructura + subtexto `"incluye USD X de estructura"`.
- Cards por campo separan **Costos directos** y **↳ Estructura (prorrateo)** en dashed itálica.
- PDF de Rentabilidad Total (`exportarPDFTotal`) también incluye estructura con caja explicativa de composición debajo del TOTALES.

### OCR desde foto/PDF
- Edge function `ocr-activo` (deploy activo) — lee factura de vehículo/máquina y devuelve `{descripcion, tipo, valor_compra_usd, fecha_compra}`.
- Edge function `ocr-gasto-estr` (deploy activo) — lee recibo de sueldo / factura de contador / póliza de seguro / alquiler y devuelve `{descripcion, tipo, importe_usd, frecuencia, fecha_inicio, fecha_fin}`.
- Ambas requieren `ANTHROPIC_API_KEY` como secret en Edge Functions — hasta que se setee, el frontend detecta el error específico y muestra un mensaje amigable.

## Pipeline automatizado de precios (BCR cereales + BNA dólar)

Sistema de scraping server-side con cron para tener siempre la cotización fresca sin depender del navegador del usuario.

### Tablas
- `precios_pizarra` (histórica) — soja/maiz/trigo/girasol/sorgo. RLS pública de lectura (writes solo desde service_role).
- `precios_dolar` (nueva) — 4 cotizaciones: `billete_compra`, `billete_venta`, `divisa_compra`, `divisa_venta`. Con timestamp preciso.

### Edge Functions
- `precios-scrape-bcr` — scrapea `mercados.ambito.com/mercados/commodities` (Chicago) y aplica retenciones ARG (Soja 24%, Maíz 8.5%, Trigo 7.5%, Girasol 4.5%, Sorgo 8.5%) para calcular la pizarra local. Upsert por fecha en `precios_pizarra`.
- `precios-fetch-dolar` — scrapea el HTML del cotizador público del BNA. Maneja los dos formatos numéricos que usa el BNA en la misma página (billete usa coma AR `"1460,00"`, divisa usa punto US `"1480.0000"`). Fallback a `dolarapi.com/v1/dolares/oficial` si el scrape del BNA falla.

### Cron jobs (pg_cron, hora Argentina UTC-3)
- **19:00 lun-vie** → `precios-scrape-bcr` (cierre pizarra).
- **Cada 30 min entre 10:00-15:00 lun-vie** → `precios-fetch-dolar` (horario de mercado).
- **19:00 lun-vie** → `precios-fetch-dolar` (cotización de cierre).

### Vistas SQL con filtros de sanity
- `v_precio_dolar_actual` → última fila con `divisa_compra` y `divisa_venta` between 100 and 100000 (excluye valores absurdos).
- `v_precio_cereales_actual` → última fila de `precios_pizarra`.

### Frontend: helpers de conversión USD ↔ ARS
En `index.html`:
- `window._dolarCompra()` → divisa comprador (~1480). **Usar en INGRESOS** (venta de cereal, el banco compra USD al productor).
- `window._dolarVenta()` → divisa vendedor (~1489). **Usar en EGRESOS/COSTOS** (compra de insumos, Mi Plan, pagos, gastos).
- `precios.bna` sigue existiendo como alias legacy de `divisa_venta` para no romper código viejo. Nuevos usos van con los helpers explícitos.
- Strip del dashboard tiene 2 celdas separadas: `USD Compra · BNA` y `USD Venta · BNA` con el timestamp de "Cierre pizarra: DD-mmm".
- Mi Plan hace `actualizarPrecios(true)` al abrir para forzar fetch fresco + muestra timestamp "Recién actualizado" / "Hace X min".

## Suscripciones y cobro (Mercado Pago)

Débito automático mensual/anual con **Mercado Pago Suscripciones (`preapproval`)**. Migración `SQL/suscripciones_mercadopago.sql`, backend en `main.py`, frontend en la sección "Mi plan" de `index.html`.

### Por qué `preapproval` y no `preapproval_plan`

Los precios son **USD × dólar BNA vendedor + IVA 21%**, o sea que el monto en ARS es distinto para cada usuario según el día en que se dio de alta. Un `preapproval_plan` es un monto fijo compartido por todos los suscriptos: habría que recrear planes cada vez que se mueve el dólar. Con `preapproval` sin plan asociado cada suscripción lleva su propio `transaction_amount` y su propio `external_reference` (`owner_id|plan|periodo`), que es lo que el webhook necesita para mapear de vuelta al usuario.

**Anual** = `preapproval` con `frequency: 12, frequency_type: "months"` (un solo rail de pago, se auto-renueva, se cancela desde la app). MP Suscripciones **no soporta cuotas**; si algún día queremos anual en cuotas va por Checkout Pro como `proveedor` aparte (la tabla ya tiene las columnas `periodo` y `proveedor` para eso, no hace falta migración nueva).

### El plan efectivo ya NO vive en `user_metadata`

Antes el plan salía de `usuario.user_metadata.plan` y `suscribirse()` hacía `sb.auth.updateUser({data:{plan}})`. Eso es **escribible por el cliente**: cualquiera se ponía `plan:'cosecha'` desde la consola del navegador.

Ahora:
- La **fuente de verdad** es la tabla `suscripciones`, que solo escribe el webhook con el `service_role`.
- `window._planEfectivo()` (frontend) y `_plan_efectivo()` (server) derivan el plan de esa fila. **Son espejo uno del otro — si tocás uno, tocá el otro.**
- `user_metadata.plan` queda como **cache de lectura** que el webhook sincroniza, para no romper el código viejo que lo lee.
- `window._infoPlanActual()` ahora pasa por `_planEfectivo()`. La whitelist `USUARIOS_ADMIN_ILIMITADOS` sigue ganando sobre todo.
- Para comp-ear una cuenta a mano desde Supabase: setear `user_metadata.plan` **y** `user_metadata.plan_manual: true`. Sin el flag `plan_manual`, un `plan` en el metadata sin fila de suscripción se ignora (cae a gratis).

**Límite conocido**: el gate de hectáreas sigue siendo del lado del cliente, así que es UX, no seguridad — alguien puede pisar `window._limiteHectareasPlan` desde la consola. Lo que se cerró es el camino fácil (auto-asignarse el plan) y ahora el estado real es auditable. La aplicación server-side del límite (un CHECK o un trigger sobre `campos`) queda pendiente.

**Colaboradores**: el plan se evalúa contra la suscripción del usuario logueado, no la del dueño de la cuenta a la que accede (la policy de SELECT es `owner_id = auth.uid()`). Es el mismo comportamiento que había antes con `user_metadata`, así que no es una regresión, pero un colaborador de una cuenta paga cuenta como gratis para los límites.

### Estados

`pendiente` (preapproval creado, falta la tarjeta) → `activa` → `en_gracia` (rebotó un cobro; **10 días de acceso completo**) → `impaga` (venció la gracia) · `pausada` · `cancelada`.

**Comportamiento en downgrade / impago** (decisión del producto): los datos ya cargados **nunca se ocultan**. El usuario sigue viendo y exportando todo; lo único que se bloquea es escribir. El corte lo aplica `window._guardSoloLectura()`, llamado desde `_dbMutate()` y `_restRequest()` — los dos puntos por donde pasan todas las mutaciones. Los GET/HEAD nunca se bloquean.

Cuando se cancela, el usuario **conserva el plan hasta `periodo_fin`** (el final del período que ya pagó), como hace cualquier SaaS.

### Endpoints (`main.py`)

Todos autentican con el **JWT de Supabase** en el header `Authorization` — nunca con un `usuario_id` del body.

| Endpoint | Qué hace |
|---|---|
| `POST /mp/suscripcion/crear` | Crea el `preapproval` y devuelve el `init_point` del checkout de MP |
| `POST /mp/suscripcion/cambiar-plan` | `PUT` del monto sobre el preapproval existente (no vuelve a pedir la tarjeta). Cambiar mensual ↔ anual devuelve `requiere_nuevo_checkout` |
| `POST /mp/suscripcion/cancelar` | Baja autogestionada, con acceso hasta el fin del período pago |
| `POST /mp/webhook` | **Fuente de verdad.** Valida firma y aplica el estado |
| `GET /mp/suscripcion` · `GET /mp/planes` · `GET /mp/diagnostico` | Estado, precios en ARS y chequeo de configuración |
| `GET /mp/admin/desfasaje` · `POST /mp/admin/reajustar` | Reajuste manual por movimiento del dólar (solo UUIDs de `ADMIN_USER_IDS`) |

### El webhook es lo único que otorga un plan

El redirect de vuelta (`back_url`) **no da de alta nada** — solo muestra "confirmando tu pago" y hace polling sobre la tabla. Nunca confiar en el cliente para eso.

Validación de firma (obligatoria): header `x-signature: ts=<ms>,v1=<hex>`, manifest `id:<data.id>;request-id:<x-request-id>;ts:<ts>;`, HMAC-SHA256 hex con `MP_WEBHOOK_SECRET`. **Sin el secreto configurado el webhook ignora la notificación** en vez de aplicarla (devuelve 200 para que MP no reintente en loop, pero no toca la DB). Topics escuchados: `subscription_preapproval` y `subscription_authorized_payment`.

### URLs de retorno

Se mantiene la regla dura: **el frontend manda su propio `window.location.origin + window.location.pathname`** en `retorno_url` y el server lo valida contra la allowlist `ORIGENES_RETORNO`. Nada de URLs hardcodeadas (romper esto rompe rindeagro.app) y nada de open redirect.

### Datos de tarjeta

Ninguno pasa por Rinde.Agro. El usuario carga la tarjeta en el checkout hosteado por Mercado Pago. De vuelta solo guardamos marca y últimos 4 dígitos, que es lo que MP nos informa para el comprobante.

### Env vars a setear en Railway

| Variable | De dónde sale |
|---|---|
| `MP_ACCESS_TOKEN` | MP → Tus integraciones → tu aplicación → Credenciales. **Empezar con la de prueba (`TEST-…`)**; el server detecta el entorno por ese prefijo |
| `MP_WEBHOOK_SECRET` | MP → Tus integraciones → tu aplicación → Webhooks → "Configurar notificación" → revelar clave secreta |
| `ADMIN_USER_IDS` | Opcional, CSV de UUIDs para `/mp/admin/*`. Default: el UUID de Ignacio |

En el panel de MP hay que configurar la URL de notificación apuntando a `https://<server-de-railway>/mp/webhook` y marcar los eventos **"Planes y suscripciones"** y **"Pagos autorizados de suscripciones"**. El secreto se genera recién al guardar esa configuración.

### Cron

Job diario 6:00 AR `_suscripciones_vencer_gracia`: pasa `en_gracia` → `impaga` cuando venció `gracia_hasta` y sincroniza el metadata. MP no nos avisa de eso.

### Pruebas en sandbox

Usar **usuarios de prueba** de MP (Tus integraciones → Cuentas de prueba): hace falta uno vendedor (de donde sale el `TEST-` access token) y uno comprador distinto. El `payer_email` del checkout tiene que ser el del usuario de prueba comprador, si no MP rechaza la suscripción.

## Límites por plan + whitelist de admin

Los planes se eligen por **hectáreas totales del productor**, no por cantidad de campos. El límite se aplica en `window.guardarCampo` sumando las ha de todos los campos más las del que se está creando:

| Plan | Límite | USD/mes |
|---|---|---|
| Gratis | 50 ha (1 campo) | 0 |
| 🌱 Semilla | 500 ha | 35 |
| 🌿 Germinación | 1.000 ha | 50 |
| 🌸 Floración | 2.000 ha | 65 |
| 🌾 Maduración | 5.000 ha | 80 |
| 🚜 Cosecha | 10.000 ha | 110 |

Anual = mensual × 12 × 0.8 (−20%). Todo + IVA 21%, cobrado en pesos al dólar BNA vendedor.

Al registrarse hay **30 días de trial** sin tarjeta: durante ese período `_limiteHectareasPlan()` devuelve `Infinity`.

Cuando el usuario se pasa del límite, `guardarCampo` abre `window._modalLimitePlan()` — que sugiere el plan más chico que le alcanza y lleva derecho al checkout de Mercado Pago (ver "Suscripciones y cobro"). Antes era un toast que se perdía + un redirect silencioso a Mi Plan.

Excepción admin: whitelist `USUARIOS_ADMIN_ILIMITADOS` (array de UUIDs en `index.html`). Los que están ahí tienen acceso ilimitado sin importar su plan. Hoy contiene solo el UUID de Ignacio (`ea80343b-b31d-4cba-a43e-00c3f0a3fa39`) para poder seguir probando la app sin bloquearse. Extensible: para agregar otro admin, sumar su UUID al array.

Helpers globales:
- `window._esAdminIlimitado()` — true si el user actual está en la whitelist.
- `window._planEfectivo()` — id del plan que le corresponde HOY según la tabla `suscripciones`. **Fuente de verdad.**
- `window._infoPlanActual()` — objeto `PLANES_INFO` del plan efectivo (default gratis).
- `window._limiteHectareasPlan()` — ha permitidas (`Infinity` para admin o trial activo).
- `window._limiteCamposPlan()` — alias legacy por cantidad de campos.
- `window._appSoloLectura()` — true si la suscripción quedó impaga.
- `window._suscripcionEstado()` — `{estado, etiqueta, color}` para la UI.

## Catálogo de insumos predefinidos

`INSUMOS_PREDEFINIDOS` (en `index.html`) contiene ~120 productos curados según uso en agricultura argentina (datos INTA/CASAFE/Aapresid). Aparece como autocompletado `<datalist>` en el modal de carga de insumo, filtrado por tipo. Semillas y "otros" quedan en carga manual.

Las 4 categorías predefinidas:
- **Herbicidas** (~34): Glifosato en varias formulaciones, 2,4-D, Dicamba, Atrazina, Acetoclor, S-Metolaclor, Sulfentrazone, Flumioxazin, Imazetapir, Cletodim, Haloxifop, Quizalofop, Bentazon, Saflufenacil, Picloram, Metsulfurón, Glufosinato, Paraquat, Tembotrione, etc.
- **Fungicidas** (~30): Mancozeb, Carbendazim, Clorotalonil, triazoles (Tebuconazole, Epoxiconazole, Cyproconazole, etc.), estrobilurinas (Azoxistrobina, Piraclostrobina, Trifloxistrobina), mezclas estrobilurina+triazol, carboxamidas, cobres, curasemillas.
- **Insecticidas** (~33): piretroides (Cipermetrina, Lambdacialotrina, Bifentrin, Deltametrina, Zeta-cipermetrina, Gamma-cialotrina, Permetrina), neonicotinoides (Imidacloprid, Tiametoxam, Acetamiprid, Clotianidina), diamidas (Clorantraniliprole/Coragen, Flubendiamide/Belt, Ciantraniliprole), espinosinas (Spinosad, Spinetoram), reguladores (Metoxifenocide, Lufenuron), organofosforados (Clorpirifos, Dimetoato).
- **Fertilizantes** (~32): nitrogenados (Urea 46% en variantes, UAN 32, Solmix, ATS, Sulfato/Nitrato de amonio), fosfatados (MAP, DAP, MAP azufrado, SFS, SFT), potásicos (KCl, K2SO4, Sulpomag), azufrados, mezclas físicas NPS/NPK, micros (Boro, Zinc), starter líquido.

## Pendientes (roadmap corto)

- [x] ~~Dominio `rindeagro.lat`~~ — Reemplazado por **rindeagro.app** (PR #39). El CNAME apunta ahí. Los redirects auth ahora son dinámicos (`window.location.origin + pathname`), funcionan en cualquier dominio sin hardcodear.
- [x] ~~Open Graph meta tags~~ — Aplicado. Meta tags og:/twitter: en el `<head>` + imagen SVG en `assets/og-image.svg` (1200×630). Se ve preview en WhatsApp/Facebook/LinkedIn/Slack/X. Si en algún momento un partner reporta que WhatsApp no lo renderiza bien (SVG spotty), convertir a PNG y actualizar la URL de `og:image`.
- [x] ~~Migrar FKs de Supabase a `ON DELETE CASCADE`~~ — Aplicado (migración `fks_on_delete_cascade_cleanup`). Cambios: `*.usuario_id → perfiles(id)` pasa a `CASCADE` en gastos/lluvias/eventos/analisis_suelo/campanas/mensajes_wa. `gastos.campana_id`, `mensajes_wa.evento_creado`, `precios_pizarra.actualizado_por` y `perfiles.agronomo_id` pasan a `SET NULL` (mantienen registro histórico). Ahora un `auth.users DELETE` limpia todo en cascada sin transacciones manuales.
- [x] ~~Habilitar RLS en tabla `precios_pizarra`~~ — Aplicado con la migración `precios_dolar_scrape_pipeline` (lectura pública para authenticated + anon, writes solo desde edge functions con service_role).
- [x] ~~Confirmación de eliminación más fuerte~~ — Aplicado. 5 confirms simples (`eliminarTarea`, `eliminarGasto`, `eliminarCompromiso`, `eliminarActivo`, `eliminarGastoEstructura`) migrados al pattern **`_showToastUndo`**: delete optimista inmediato + toast con botón "Deshacer" 5s. Los 2 confirms que quedan son deliberados: `eliminarInsumo` cuando está vinculado a gastos (warning custom), y bulk delete de insumos (donde SÍ querés confirmación explícita).
- [ ] **Verificación de WhatsApp con código de 6 dígitos** — hoy es vinculación directa. A futuro: bot manda código, usuario lo ingresa en la web, recién ahí se vincula.
- [ ] **Panel de notificaciones por WhatsApp en "Mi Plan"** — toggles para resumen semanal, alertas de precio, recordatorios de operarios y admins.
- [ ] **OCR de facturas, pagos, activos y gastos de estructura — activar `ANTHROPIC_API_KEY`** en Supabase Edge Functions secrets. Las 4 edge functions (`ocr-factura`, `ocr-pago`, `ocr-activo`, `ocr-gasto-estr`) están desplegadas pero devuelven 500 hasta que se setee el secret. Con el secret: foto/PDF → Claude API vision → JSON → pre-llenado del modal correspondiente.
- [ ] **SMTP custom para emails de auth** — hoy los mails de "olvidé contraseña" y magic link salen desde `noreply@mail.app.supabase.com`. Se puede configurar SMTP custom en Supabase → Auth → Emails con las credenciales de Gmail (`rindeagro.contacto@gmail.com` con App Password de 2FA) para que salgan desde el mail de Rinde.Agro. Requiere teléfono para la 2FA (esperando).
- [ ] **Bot de WhatsApp insertando pagos**: cuando el bot esté listo, implementar el parser de comandos "cheque NNN a X vence DD/MM" y "crédito X N cuotas de NNN desde DD/MM" según el contrato documentado en "Módulo Pagos → Contrato WhatsApp → Pagos".
- [x] ~~**Mercado Pago para suscripciones**~~ — Implementado con `preapproval` (débito automático). Ver sección "Suscripciones y cobro" abajo. **Queda por hacer para salir a producción**: (1) aplicar `SQL/suscripciones_mercadopago.sql`, (2) setear `MP_ACCESS_TOKEN` y `MP_WEBHOOK_SECRET` en Railway, (3) configurar la URL del webhook en el panel de MP, (4) probar el ciclo completo en sandbox con usuarios de prueba, (5) recién ahí cambiar las credenciales de TEST- a producción.

## Cosas en curso

- Bot de WhatsApp (Twilio Sandbox, ya recibe mensajes y reconoce números vinculados, falta terminar los flujos de carga de gastos/lluvias y los recordatorios programados con APScheduler).
- Mercado Pago: el flujo de suscripción está implementado y funcionando contra el **sandbox**. Falta aplicar la migración, cargar las credenciales en Railway, configurar el webhook en el panel de MP y probar el ciclo completo antes de pasar a producción.

## Convenciones de UI

- **Estado de resultados (P&L)** en Rentabilidad Total: tabla con filas pintadas. **Paleta actualizada (PR #43 de Agustina)**: Ingresos `#dcfce7` (verde claro suave), Costos `#dc2626` (rojo), Margen `#86efac` (verde medio, o `#fca5a5` si negativo). Texto NEGRO bold en todas las filas. Convenciones contables: costos entre paréntesis, doble underline en subtotal Margen, font-variant-numeric: tabular-nums.
- **Cards de Rentabilidad por campo**: solo el NÚMERO va coloreado (ingresos verde oscuro `#15803d`, costos rojo `#dc2626`, margen verde más claro `#16a34a`). Las filas sin fondo. Labels en negro.
- **Tortas Rentabilidad**: la primera (Gastos por rubro) tiene selector de campo. La segunda (Detalle por producto) hereda ese filtro + tiene su propio selector de rubro. Cascada de filtros.
- **Insumos**: filas de ancho completo (no grid de cards). Cantidad, precio y ubicación son inputs inline (editar sin abrir modal). Botón "Detalles" abre el modal completo. Badge "Sin stock" rojo DENTRO del card cuando stock_actual=0.
- **Tareas**: 4 botones (Completar / Iniciar / Editar / Eliminar) del mismo ancho (110px) y mismo estilo visual. Eliminar siempre visible para admin.
- **Mapa**: campos sin polígono tienen botón "✏️ Dibujar polígono" en la tarjeta sidebar y en el popup del marcador. Usa `L.Draw.Polygon` de leaflet-draw. Al cerrar el polígono, calcula hectáreas por shoelace + radio terrestre y guarda en `campos.poligono` + `campos.hectareas`.
- **Refresh garantizado al abrir tab**: `showModulo('stock-insumos')` y `showModulo('tareas')` disparan un fetch REST extra que garantiza ver datos frescos incluso si `cargarTodo` no terminó.

## Dev tools — Copy Tools widget (PR #42, #44 de Agustina)

Widget flotante para devs que permite copiar contexto rápido (HTML/CSS/JS de un elemento) para pegarlo en un chat de asistente. No afecta producción para usuarios finales.

- **Activación**: agregar `?dev=1` en la URL una vez. Guarda `localStorage['ra_devmode'] = '1'`. A partir de ahí aparece el widget bottom-right.
- **Desactivar**: `window._devCopyDisable()` borra `ra_devmode` y `ra_devmode_pos`.
- **Posición**: draggable desde el header `⋮⋮ COPY TOOLS ⋮⋮`. Posición persiste en `localStorage['ra_devmode_pos']` como JSON `{left, top}`. Se reclampa a viewport en resize.
- **Atajos teclado (solo si dev mode activo)**: `1` → copiar página activa, `2` → inspeccionar elemento. Ignora targets INPUT/TEXTAREA/SELECT/contenteditable.
- **Globals expuestas**: `window._devCopyPage`, `window._devPickElement`, `window._devCopyDisable`.
- **DOM**: `<div id="dev-copy-widget">` con `z-index:99997`. Coexiste con el widget viejo (bottom-left).

**No reusar**: el id `dev-copy-widget`, los nombres `_dev*`, las localStorage keys `ra_devmode` / `ra_devmode_pos`, ni el z-index 99997. Si agregás atajos globales con tecla 1 o 2, vas a chocar — siempre filtrá targets editables como hace este widget.

## SQL migrations aplicadas (en orden)

Todas en `SQL/`. Aplicadas en producción via MCP de Supabase.

1. `stock_insumos.sql` — tabla + RLS + columna `gastos.insumo_id`.
2. `tareas_comentario_y_insumos_factura.sql` — `tareas.comentario_completado`, `tareas.completado_por`, `stock_insumos.factura_url/path/tipo`, bucket `insumos-facturas` + 4 RLS de Storage.
3. `equipo_split_for_all_policy.sql` — reemplazo del policy `owner_manage_equipo` FOR ALL por 4 explícitas.
4. `compromisos_pago.sql` — tabla `compromisos_pago` con todos los campos para cheques y cuotas de crédito + 4 RLS policies explícitas.
5. `compromisos_pago_archivo_y_fuente.sql` — agrega `archivo_url`, `archivo_path`, `fuente` (manual|foto|whatsapp) a `compromisos_pago` + bucket `pagos-archivos` con 4 RLS de Storage.
6. `compromisos_estado_pagado.sql` — renombra el value `'cobrado'` por `'pagado'` en `compromisos_pago.estado` (re-genera el CHECK constraint).
7. `campos_ingresos_cultivos.sql` — agrega `ingresos_cultivos` y `hectareas_cultivo` (text nullable) a `campos`. El frontend ya las escribía pero el schema no las tenía, así que las ventas/forward del tab Ingresos y la asignación de ha por cultivo en campos mixtos no persistían a DB.
8. `gastos_cultivo.sql` — agrega `gastos.cultivo` (text nullable). Cuando el gasto es específico de un cultivo se guarda ahí y no se reparte. Cuando es null se considera "compartido" y el frontend lo reparte proporcional a las ha de cada cultivo en campos mixtos.
9. `precios_dolar_scrape_pipeline.sql` — pipeline automatizado de precios: crea tabla `precios_dolar` (billete_compra/venta + divisa_compra/venta), habilita RLS pública de lectura en `precios_pizarra`, instala extensiones `pg_cron` + `pg_net`, crea vistas `v_precio_dolar_actual` / `v_precio_cereales_actual` con filtros de sanity, y programa 3 cron jobs: BCR 19:00 lun-vie, BNA dólar cada 30 min entre 10-15 hs lun-vie, BNA dólar cierre 19:00 lun-vie.
10. `gastos_factura_columns.sql` — agrega `factura_url`, `factura_path`, `factura_tipo` (factura|remito) a `gastos`. Reutiliza el bucket `insumos-facturas` (owner_id + timestamp en el path evita colisiones). Permite adjuntar factura/remito a cualquier gasto, no solo insumos.
11. `estructura_activos_y_gastos_generales.sql` — nuevas tablas `activos_amortizables` (vehículos/maquinaria/herramientas/construcción con vida útil) y `gastos_estructura` (sueldos/honorarios/seguros/oficina con frecuencia mensual/anual/único). 4 RLS policies owner-only en cada una. Ver sección "Módulo Estructura" abajo.
12. `fks_on_delete_cascade_cleanup.sql` — migra los `*.usuario_id → perfiles(id)` a `CASCADE` en gastos/lluvias/eventos/analisis_suelo/campanas/mensajes_wa (antes eran NO ACTION, rompía el borrado limpio de un `auth.users`). Además pone en `SET NULL`: `gastos.campana_id`, `mensajes_wa.evento_creado`, `precios_pizarra.actualizado_por` y `perfiles.agronomo_id` para preservar registros históricos cuando se elimina la referencia.
13. `gastos_momento_pulverizacion.sql` — agrega `gastos.momento_pulverizacion` (text nullable con CHECK `barbecho|presiembra|postemergente|aplicacion`). Alimenta la nueva tab **Cultivo** en la vista del campo, que arma una timeline con siembra, pulverizaciones, fertilizaciones y cosecha derivada de los gastos ya cargados. El dropdown aparece en el modal de gasto solo cuando el rubro es `herbicidas`/`fungicidas`/`insecticidas`.
14. `suscripciones_mercadopago.sql` — tablas `suscripciones` (una fila por suscripción: plan, período, estado, preapproval id de MP, importe ARS + base USD + TC del alta, próximo cobro, ventana de gracia) y `suscripcion_pagos` (historial de cobros / comprobantes). 4 RLS policies explícitas en cada una, pero con una diferencia respecto del resto del proyecto: **solo el SELECT del dueño está permitido; INSERT/UPDATE/DELETE deniegan siempre** (`with check (false)`). Todas las escrituras entran por el webhook de Railway con `SUPABASE_SERVICE_KEY`, que saltea RLS. Si el frontend pudiera escribir, un usuario se pondría `estado='activa'` y `plan='cosecha'` desde la consola. Incluye índice único parcial `idx_suscripciones_una_viva` (una sola suscripción no cancelada por usuario) y la vista `v_suscripcion_vigente`.
