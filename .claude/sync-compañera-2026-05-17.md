# Sync para Agustina — sesión 17-may-2026

> Mensaje para pegar al inicio del chat de Claude en la computadora de Agustina.
> Sirve para que Claude sepa qué pasó hoy y pueda seguir trabajando sobre lo nuevo.

---

Hola, vengo de un día largo de trabajo del lado de Ignacio. Te paso todos los cambios que pushié a `main` hoy, además del estado actual de la app, para que puedas seguir trabajando sin pisarte. Lo importante: **pull primero** así arrancás con todo sincronizado.

## Para empezar (en tu compu)

```bash
cd /Users/juanignaciomanterola/Rindeagro
git checkout main
git pull origin main
```

El repo está en `JuanIgnacioManterola/Rindeagro`. Hoy mergeé 25 PRs (del #13 al #37). El `index.html` creció +3000 líneas más o menos, hay 3 SQL migrations nuevas aplicadas en producción, y 1 edge function de Supabase desplegada.

## Bug crítico descubierto hoy y workaround

**El cliente `supabase-js` se cuelga internamente** — no dispara la HTTP request, no resuelve, no rechaza. Lo descubrimos cuando "Mi equipo" se quedaba en "Cargando..." infinito, las tareas no guardaban, los archivos no subían, los insumos no eliminaban.

**Workaround**: helpers REST que se saltean el SDK y van directo a `/rest/v1` y `/storage/v1` con el JWT de `localStorage['rindeagro-auth']`. Cualquier mutación nueva tiene que usar este patrón, no el SDK directo. Helpers que dejé listos en `index.html`:

- `_restGet(path)`, `_restPost(path, body)`, `_restPatch(path, body)`, `_restDelete(path)`
- `_restStorageUpload(bucket, path, file, contentType)`
- `_dbMutate({method, table, filter:{col,val}, payload, timeout})` — wrapper genérico: SDK con timeout + fallback REST
- `_selectConFallback(table, {col, val, col2, val2, order})` — usado en `cargarTodo` para los SELECT iniciales
- `_getAccessTokenFromStorage()` — lee el JWT directo de localStorage sin pasar por `sb.auth`

**Patrón optimista**: las mutaciones aplican el cambio al estado local + render + cache YA, y sincronizan con DB en background. Si la DB falla, hay rollback con snapshot previo.

## Features grandes nuevas

### 1. Estado de resultados (Rentabilidad Total)

Rediseñé toda la pantalla de Rentabilidad Total. Nuevo orden de secciones (top a bottom):
1. 4 métricas globales (Hectáreas / Ingresos / Costos / Margen) — el "rectángulo" con cards
2. Estado de resultados P&L — tabla con filas pintadas (verde oscuro Ingresos, rojo Costos, verde claro Margen) + texto NEGRO bold. Convenciones contables: costos entre paréntesis, doble underline en subtotal, tabular-nums.
3. Cards de rentabilidad por campo — solo el número va coloreado, sin fondo en la fila.
4. Comparativa entre campos
5. Tortas (Gastos por rubro / Detalle por producto) — la primera tiene selector de campo, la segunda hereda + tiene selector de rubro propio. Cascada de filtros.
6. Tabla resumen de gasto por rubro

### 2. Stock de Insumos (totalmente operativo)

Tab `🧪 Insumos` en la nav. Cada insumo es una fila a ancho completo con:
- Nombre + tipo
- Ubicación (editable inline)
- Cantidad (editable inline, número en verde si hay / rojo si no)
- Precio USD/unidad (editable inline)
- Botón "Detalles" → modal completo

Cuando se carga un insumo, el campo Nombre tiene autocompletado `<datalist>` con **~120 productos curados** según uso en agricultura argentina (constante `INSUMOS_PREDEFINIDOS`). Filtrado por tipo. El usuario puede tipear cualquier nombre que no esté en la lista (no es un select cerrado). Semillas queda manual.

Badge "⚠️ Sin stock" rojo aparece DENTRO del card cuando stock_actual = 0.

**Integración con Gastos**: al cargar un gasto con rubro herbicidas/fungicidas/insecticidas/fertilizantes aparece un selector "Descontar de stock". Al guardar el gasto, descuenta `cantidad × ha_aplicadas` del stock. Al editar/borrar el gasto, revierte. Bloquea si excede stock.

### 3. Carga de insumos desde factura/remito

Botón "📄 Desde factura" en el módulo Insumos abre `#ov-factura`:
- Subís imagen o PDF
- Elegís si es factura o remito
- Click "Leer e identificar insumos"
- Modal muestra lista editable de items extraídos
- Bulk insert al stock con checkboxes

**OCR**: edge function `ocr-factura` desplegada en Supabase. Usa Claude vision API. **NECESITA `ANTHROPIC_API_KEY` como secret en Edge Functions** para funcionar. Hasta que se setee, el botón muestra mensaje claro y la carga manual sigue funcionando.

### 4. Tareas — mejoras

- **Comentario al completar**: modal nuevo `#ov-completar-tarea` con textarea. Persiste en `tareas.comentario_completado` + `tareas.completado_por`. Se renderiza como bloque verde con borde en la tarjeta de tarea completada.
- **Asignado/realizador visible**: "Asignada a X" en pendientes, "✓ Realizada por Y" en completadas. Helper `_nombreUsuario(uid)` resuelve nombre desde equipo, admin o sesión propia.
- **Filtros avanzados**: por Usuario / Campo / Prioridad / Fecha (hoy/semana/mes/vencidas) en los 4 estados (pendiente/en_progreso/programada/completada).
- **Calidad de imágenes**: previews subidos sin recompresión (file original al Storage). Thumbnails en card 110×110 (antes 36×36).
- **4 botones del card uniformes** (Completar / Iniciar / Editar / Eliminar) — mismo ancho 110px stretch.
- **Eliminar siempre disponible** para admin (antes solo en completadas).

### 5. Mapa — dibujar polígono nuevo

Antes solo se podían editar polígonos existentes. Ahora los campos sin polígono muestran botón "✏️ Dibujar polígono" en la sidebar y en el popup del marcador. Usa `L.Draw.Polygon` (leaflet-draw, cargado via CDN). Al cerrar el polígono, calcula hectáreas con shoelace + radio terrestre y guarda `campos.poligono` + `campos.hectareas`.

### 6. Nav reordenada

Orden actual: `Inicio · Campos · Rentabilidad · Insumos · Tareas · Mapa`.

## Schema changes aplicados en producción (Supabase)

3 migraciones nuevas. Todas ya están aplicadas. Si vas a hacer un environment fresh, los SQL están en `SQL/`:

### `SQL/stock_insumos.sql` (ya aplicada hace 2 días)
Crea `public.stock_insumos` (id, owner_id, nombre, tipo, unidad, stock_actual, costo_unitario, ubicacion, notas, created_at, updated_at) + 4 RLS policies explícitas + columna `gastos.insumo_id` (FK opcional).

### `SQL/tareas_comentario_y_insumos_factura.sql` (hoy)
Agrega:
- `tareas.comentario_completado` (text)
- `tareas.completado_por` (uuid FK auth.users on delete set null)
- `stock_insumos.factura_url`, `factura_path`, `factura_tipo` (factura|remito)
- Bucket Storage `insumos-facturas` (público) + 4 policies de Storage RLS

### `SQL/equipo_split_for_all_policy.sql` (hoy)
Reemplaza la policy `owner_manage_equipo` (FOR ALL) por 4 explícitas (`owner_select_equipo`, `owner_insert_equipo`, `owner_update_equipo`, `owner_delete_equipo`). El FOR ALL causaba que los SELECT a `equipo` se colgaran 10+s desde el frontend (mismo síntoma que mencionaste para `invitaciones`). **Mantener este patrón a futuro** — nunca usar `FOR ALL` con RLS en Supabase.

## Schema "gotchas" encontrados hoy

Importante para no romper cosas:

- **Tabla `tareas` usa `estado` (text), NO existe columna boolean `completada`**. Si ves código con `completada: false` en un payload de INSERT, hay que sacarlo (causa error "column does not exist in schema cache"). Fixeado en `guardarTarea`.
- **Tabla `equipo` usa `miembro_id` y `nombre_display`** — NO `colaborador_id` y NO `nombre`. Yo había introducido un bug usando los nombres equivocados en `_nombreUsuario` y `_tarjAsignado`. Ya corregido.
- **NO usar FOR ALL en RLS**. Siempre 4 policies explícitas por tabla (SELECT/INSERT/UPDATE/DELETE).

## Edge function `ocr-factura`

Desplegada en Supabase como `ocr-factura` (verify_jwt: true). Código en `supabase/functions/ocr-factura/index.ts`. Recibe `{image_base64, mime_type, tipo}`, llama Claude API vision, devuelve `{items: [...]}`.

**Pendiente del lado humano**: setear `ANTHROPIC_API_KEY` como secret en Supabase Dashboard → Project Settings → Edge Functions → Secrets. Sin la key la función devuelve 500 con mensaje claro al frontend.

## Pendientes que quedaron

- [ ] Setear `ANTHROPIC_API_KEY` para activar OCR de facturas (decisión: Ignacio quería consultar con vos si pagamos los ~USD 10 de créditos en Anthropic, o usamos Tesseract.js gratis pero peor calidad).
- [ ] Confirmación de eliminación más fuerte. Ignacio tuvo un caso donde se perdió todo el stock (probablemente clicks consecutivos en delete con UI optimistic). Opciones: tipear "ELIMINAR" para confirmar, o botón "Deshacer" en el toast por 5s.
- [ ] Dominio `rindeagro.lat` sigue caído.
- [ ] Bug 1 (RLS Agustina viendo datos de campos de Ignacio) — ¿se aplicó el SQL ya? No lo retomé hoy, asumí que estaba resuelto.
- [ ] Bug 5 (invitación queda con usado=false) — ídem, asumí resuelto.

## Convenciones nuevas / recordatorio

- Workflow git: siempre branch `feat/...` o `fix/...`, PR, merge. **Nunca commitear directo a main**.
- Para mutaciones a DB: usar `_dbMutate` o el patrón `Promise.race([sdk, timeout])` + `_rest*` en el catch. **No usar `sb.from(...).insert/update/delete` directo**.
- Para SELECT iniciales en `cargarTodo`: ya están migrados a `_selectConFallback`.
- Para UI: el patrón optimistic (update local + cache + render YA, sync DB en background con rollback) está aplicado en todas las operaciones de Insumos, Tareas y Gastos. Mantener consistencia si agregás otras.
- Para colores en Rentabilidad: hay 3 colores brand: verde oscuro `#15803d` para ingresos, rojo `#dc2626` para costos, verde claro `#86efac` para margen. Texto siempre negro `#000` cuando hay fondo coloreado. Tabular-nums obligatorio para todos los números financieros.

## Cosas que NO toqué (para que no te pisen)

- `precios_pizarra` sigue sin RLS — no lo cambié.
- FKs `gastos`, `lluvias`, `analisis_suelo`, `campanas`, `eventos`, `mensajes_wa` siguen como NO ACTION — no las migré a CASCADE.
- WhatsApp bot — no toqué nada del backend FastAPI ni de Twilio.
- Mercado Pago — sin cambios.
- Verificación WhatsApp con código — sin cambios.

Si querés ver el diff completo:

```bash
gh pr list --state merged --limit 25 --repo JuanIgnacioManterola/Rindeagro
```

(o `git log --since="2 days ago" --oneline` para todos los commits).

Si tenés alguna pregunta sobre algo específico, decime el PR o el archivo y te explico el contexto. ¡A laburar!
