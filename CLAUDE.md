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

## Catálogo de insumos predefinidos

`INSUMOS_PREDEFINIDOS` (en `index.html`) contiene ~120 productos curados según uso en agricultura argentina (datos INTA/CASAFE/Aapresid). Aparece como autocompletado `<datalist>` en el modal de carga de insumo, filtrado por tipo. Semillas y "otros" quedan en carga manual.

Las 4 categorías predefinidas:
- **Herbicidas** (~34): Glifosato en varias formulaciones, 2,4-D, Dicamba, Atrazina, Acetoclor, S-Metolaclor, Sulfentrazone, Flumioxazin, Imazetapir, Cletodim, Haloxifop, Quizalofop, Bentazon, Saflufenacil, Picloram, Metsulfurón, Glufosinato, Paraquat, Tembotrione, etc.
- **Fungicidas** (~30): Mancozeb, Carbendazim, Clorotalonil, triazoles (Tebuconazole, Epoxiconazole, Cyproconazole, etc.), estrobilurinas (Azoxistrobina, Piraclostrobina, Trifloxistrobina), mezclas estrobilurina+triazol, carboxamidas, cobres, curasemillas.
- **Insecticidas** (~33): piretroides (Cipermetrina, Lambdacialotrina, Bifentrin, Deltametrina, Zeta-cipermetrina, Gamma-cialotrina, Permetrina), neonicotinoides (Imidacloprid, Tiametoxam, Acetamiprid, Clotianidina), diamidas (Clorantraniliprole/Coragen, Flubendiamide/Belt, Ciantraniliprole), espinosinas (Spinosad, Spinetoram), reguladores (Metoxifenocide, Lufenuron), organofosforados (Clorpirifos, Dimetoato).
- **Fertilizantes** (~32): nitrogenados (Urea 46% en variantes, UAN 32, Solmix, ATS, Sulfato/Nitrato de amonio), fosfatados (MAP, DAP, MAP azufrado, SFS, SFT), potásicos (KCl, K2SO4, Sulpomag), azufrados, mezclas físicas NPS/NPK, micros (Boro, Zinc), starter líquido.

## Pendientes (roadmap corto)

- [x] ~~Dominio `rindeagro.lat`~~ — Reemplazado por **rindeagro.app** (PR #39). El CNAME apunta ahí. Los redirects auth ahora son dinámicos (`window.location.origin + pathname`), funcionan en cualquier dominio sin hardcodear.
- [ ] **Open Graph meta tags + imagen `assets/og-image.jpg`** — para previews al compartir links en WhatsApp/Twitter/etc.
- [ ] **Migrar FKs de Supabase a `ON DELETE CASCADE`** — actualmente `gastos`, `lluvias`, `analisis_suelo`, `campanas`, `eventos`, `mensajes_wa` son `NO ACTION`. Esto facilita borrar usuarios limpiamente sin transacciones manuales.
- [ ] **Habilitar RLS en tabla `precios_pizarra`** — security advisor lo marca como crítico.
- [ ] **Verificación de WhatsApp con código de 6 dígitos** — hoy es vinculación directa. A futuro: bot manda código, usuario lo ingresa en la web, recién ahí se vincula.
- [ ] **Panel de notificaciones por WhatsApp en "Mi Plan"** — toggles para resumen semanal, alertas de precio, recordatorios de operarios y admins.
- [ ] **OCR de facturas — activar `ANTHROPIC_API_KEY`** en Supabase Edge Functions secrets. La edge function `ocr-factura` está desplegada pero devuelve 500 hasta que se setee el secret. Con el secret: foto/PDF de factura → Claude API vision → JSON de items → bulk import al stock.
- [ ] **Confirmación de eliminación más fuerte** — el delete actual usa `confirm()` simple, que en combinación con UI optimistic facilita borrados accidentales (un usuario reportó pérdida de todo el stock). Opciones: tipear "ELIMINAR" para confirmar, o agregar botón "Deshacer" en el toast por 5s.

## Cosas en curso

- Bot de WhatsApp (Twilio Sandbox, ya recibe mensajes y reconoce números vinculados, falta terminar los flujos de carga de gastos/lluvias y los recordatorios programados con APScheduler).
- Integración de Mercado Pago para suscripciones (planes Semilla, Lote, Agrónomo, Corporativo en ARS atadas al dólar BNA).

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
