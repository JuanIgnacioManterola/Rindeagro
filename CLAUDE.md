# Rinde.Agro

App para gestión agropecuaria. Frontend single-file HTML + backend FastAPI + Supabase.

## Stack

- **Frontend:** `index.html` (~600KB, single-file) publicado en GitHub Pages → https://juanignaciomanterola.github.io/Rindeagro/
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

**Convención**: cualquier mutación nueva (INSERT/UPDATE/DELETE) debe usar `_dbMutate` o el patrón `Promise.race([sdk, timeout])` + `_restXxx` en el catch. Las operaciones de Insumos, Tareas, Gastos y archivos en Storage ya están migradas.

**Patrón optimista**: además del fallback, las mutaciones son optimistic — el cambio se aplica al estado local + render + cache YA, y la sincronización con DB pasa en background. Si la DB falla, se hace rollback con un snapshot previo.

## Catálogo de insumos predefinidos

`INSUMOS_PREDEFINIDOS` (en `index.html`) contiene ~120 productos curados según uso en agricultura argentina (datos INTA/CASAFE/Aapresid). Aparece como autocompletado `<datalist>` en el modal de carga de insumo, filtrado por tipo. Semillas y "otros" quedan en carga manual.

Las 4 categorías predefinidas:
- **Herbicidas** (~34): Glifosato en varias formulaciones, 2,4-D, Dicamba, Atrazina, Acetoclor, S-Metolaclor, Sulfentrazone, Flumioxazin, Imazetapir, Cletodim, Haloxifop, Quizalofop, Bentazon, Saflufenacil, Picloram, Metsulfurón, Glufosinato, Paraquat, Tembotrione, etc.
- **Fungicidas** (~30): Mancozeb, Carbendazim, Clorotalonil, triazoles (Tebuconazole, Epoxiconazole, Cyproconazole, etc.), estrobilurinas (Azoxistrobina, Piraclostrobina, Trifloxistrobina), mezclas estrobilurina+triazol, carboxamidas, cobres, curasemillas.
- **Insecticidas** (~33): piretroides (Cipermetrina, Lambdacialotrina, Bifentrin, Deltametrina, Zeta-cipermetrina, Gamma-cialotrina, Permetrina), neonicotinoides (Imidacloprid, Tiametoxam, Acetamiprid, Clotianidina), diamidas (Clorantraniliprole/Coragen, Flubendiamide/Belt, Ciantraniliprole), espinosinas (Spinosad, Spinetoram), reguladores (Metoxifenocide, Lufenuron), organofosforados (Clorpirifos, Dimetoato).
- **Fertilizantes** (~32): nitrogenados (Urea 46% en variantes, UAN 32, Solmix, ATS, Sulfato/Nitrato de amonio), fosfatados (MAP, DAP, MAP azufrado, SFS, SFT), potásicos (KCl, K2SO4, Sulpomag), azufrados, mezclas físicas NPS/NPK, micros (Boro, Zinc), starter líquido.

## Pendientes (roadmap corto)

- [ ] **Dominio `rindeagro.lat`** — verificar estado en el registrador, renovar o reconfigurar DNS. Bloqueante para links públicos.
- [ ] **Open Graph meta tags + imagen `assets/og-image.jpg`** — para previews al compartir links en WhatsApp/Twitter/etc.
- [ ] **Migrar FKs de Supabase a `ON DELETE CASCADE`** — actualmente `gastos`, `lluvias`, `analisis_suelo`, `campanas`, `eventos`, `mensajes_wa` son `NO ACTION`. Esto facilita borrar usuarios limpiamente sin transacciones manuales.
- [ ] **Habilitar RLS en tabla `precios_pizarra`** — security advisor lo marca como crítico.
- [ ] **Verificación de WhatsApp con código de 6 dígitos** — hoy es vinculación directa. A futuro: bot manda código, usuario lo ingresa en la web, recién ahí se vincula.
- [ ] **Panel de notificaciones por WhatsApp en "Mi Plan"** — toggles para resumen semanal, alertas de precio, recordatorios de operarios y admins.
- [ ] **Cuando vuelva `rindeagro.lat`**, revertir el workaround del hardcode del github.io en los links de invitación.
- [ ] **OCR de facturas — activar `ANTHROPIC_API_KEY`** en Supabase Edge Functions secrets. La edge function `ocr-factura` está desplegada pero devuelve 500 hasta que se setee el secret. Con el secret: foto/PDF de factura → Claude API vision → JSON de items → bulk import al stock.
- [ ] **Confirmación de eliminación más fuerte** — el delete actual usa `confirm()` simple, que en combinación con UI optimistic facilita borrados accidentales (un usuario reportó pérdida de todo el stock). Opciones: tipear "ELIMINAR" para confirmar, o agregar botón "Deshacer" en el toast por 5s.

## Cosas en curso

- Bot de WhatsApp (Twilio Sandbox, ya recibe mensajes y reconoce números vinculados, falta terminar los flujos de carga de gastos/lluvias y los recordatorios programados con APScheduler).
- Integración de Mercado Pago para suscripciones (planes Semilla, Lote, Agrónomo, Corporativo en ARS atadas al dólar BNA).

## Convenciones de UI / patrones agregados hoy

- **Estado de resultados (P&L)** en Rentabilidad Total: tabla con filas pintadas (verde oscuro Ingresos, rojo Costos, verde claro Margen) + texto negro bold. Convenciones contables: costos entre paréntesis, doble underline en subtotal Margen, font-variant-numeric: tabular-nums.
- **Cards de Rentabilidad por campo**: solo el NÚMERO va coloreado (ingresos verde oscuro, costos rojo, margen verde claro). Las filas sin fondo. Labels en negro.
- **Tortas Rentabilidad**: la primera (Gastos por rubro) tiene selector de campo. La segunda (Detalle por producto) hereda ese filtro + tiene su propio selector de rubro. Cascada de filtros.
- **Insumos**: filas de ancho completo (no grid de cards). Cantidad, precio y ubicación son inputs inline (editar sin abrir modal). Botón "Detalles" abre el modal completo. Badge "Sin stock" rojo DENTRO del card cuando stock_actual=0.
- **Tareas**: 4 botones (Completar / Iniciar / Editar / Eliminar) del mismo ancho (110px) y mismo estilo visual. Eliminar siempre visible para admin.
- **Mapa**: campos sin polígono tienen botón "✏️ Dibujar polígono" en la tarjeta sidebar y en el popup del marcador. Usa `L.Draw.Polygon` de leaflet-draw. Al cerrar el polígono, calcula hectáreas por shoelace + radio terrestre y guarda en `campos.poligono` + `campos.hectareas`.
- **Refresh garantizado al abrir tab**: `showModulo('stock-insumos')` y `showModulo('tareas')` disparan un fetch REST extra que garantiza ver datos frescos incluso si `cargarTodo` no terminó.

## SQL migrations aplicadas (en orden)

Todas en `SQL/`. Aplicadas en producción via MCP de Supabase.

1. `stock_insumos.sql` — tabla + RLS + columna `gastos.insumo_id`.
2. `tareas_comentario_y_insumos_factura.sql` — `tareas.comentario_completado`, `tareas.completado_por`, `stock_insumos.factura_url/path/tipo`, bucket `insumos-facturas` + 4 RLS de Storage.
3. `equipo_split_for_all_policy.sql` — reemplazo del policy `owner_manage_equipo` FOR ALL por 4 explícitas.
