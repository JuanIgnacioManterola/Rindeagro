---
name: parpadeo
description: Diagnosticar y arreglar parpadeo, titileo, flicker, scroll trabado o fondo que "se corta" (checkerboarding) en rindeagro.app. Usar cuando el usuario reporte que la página titila, parpadea, se traba al scrollear, un widget aparece y desaparece, o el dashboard "salta" al cargar. También como checklist preventivo al agregar modales, overlays, blur, animaciones o renders async.
---

# Parpadeo / titileo en Rinde.Agro

Ya nos pasó varias veces y fueron causas **distintas** con el mismo síntoma.
No asumir cuál es: medir primero.

## Paso 0 — ¿Es caché?

GitHub Pages sirve `index.html` con `cache-control: max-age=600`. Después de
mergear un fix, el navegador puede mostrar la versión vieja hasta 10 minutos.

1. Confirmar que el deploy terminó: `gh run list --limit 1` (workflow
   "pages build and deployment" en `success`).
2. Confirmar que el sitio vivo tiene el cambio:
   `curl -s "https://rindeagro.app/?nc=$(date +%s)" | grep -c '<fragmento del fix>'`
3. Pedirle al usuario **recarga forzada: `Cmd + Shift + R`** antes de concluir
   que el fix no funcionó.

## Paso 1 — Medir

Abrir la sección que titila y correr [`diagnostico.js`](diagnostico.js)
(con la herramienta de JavaScript del Browser, o pegándolo en la consola).
Devuelve:

| Campo | Qué indica | Causa probable |
|---|---|---|
| `capasCarasVisibles` alto (> 3) | Elementos que no se ven pero se componen en GPU | **Causa A** |
| `mutaciones3s` > 0 sin tocar nada, `topMutados` repite un contenedor | El DOM se reescribe solo | **Causa B** |
| `animInfinitas` sobre elementos grandes | Repintado constante | **Causa C** |

La landing sana da: `capasCarasVisibles: 1` (`#toast`), `mutaciones3s: 0`,
3 animaciones infinitas decorativas del hero (`float`, `pulse`).

Sin sesión solo se puede medir la landing. **No loguearse con credenciales del
usuario**: pedirle que corra el script en su navegador dentro de la app y pegue
el resultado.

## Causa A — Compositing: overlays invisibles que igual ocupan GPU (PR #225)

**Síntoma:** titila en *todas* las secciones; en celular el scroll se traba y
el fondo se corta. En desktop casi no se nota.

**Mecanismo:** los 30 `.overlay` (modales) viven siempre en el DOM,
`position:fixed` a pantalla completa con `backdrop-filter:blur(12px)`.
Cerrados tenían `opacity:0` + `pointer-events:none`, pero **un elemento con
`backdrop-filter` se promueve a capa compuesta aunque tenga opacidad 0**.
Resultado: 92 capas compuestas (18 sin el bug) → se agota la memoria de tiles
del GPU del celular.

**Fix:** ocultar con `visibility:hidden`, con transición que preserve el fade:

```css
.overlay{...;opacity:0;visibility:hidden;pointer-events:none;transition:opacity .25s,visibility 0s linear .25s}
.overlay.open{opacity:1;visibility:visible;pointer-events:all;transition:opacity .25s,visibility 0s}
```

- `backdrop-filter:none` en los cerrados **NO alcanza** (medido: sigue en 92).
- El delay `visibility 0s linear .25s` en el estado cerrado es obligatorio:
  sin él el modal desaparece de golpe al cerrar.

**Prevención:** todo elemento nuevo que esté siempre en el DOM y se muestre/oculte
con `opacity` (drawers, toasts, popovers, overlays) y tenga `backdrop-filter`,
`position:fixed`, `transform` o `will-change` → ocultarlo con
`visibility:hidden` (patrón de arriba) o `display:none`, nunca solo `opacity:0`.

Verificación fina (opcional): servir el repo con `python3 -m http.server 8787`,
abrir con Playwright, `LayerTree.enable` por CDP y contar `layers` (~18 sano).

## Causa B — Renders async en carrera (PR #209, `fix/dashboard-flicker-v2`)

**Síntoma:** el dashboard parpadea *al cargar*; widgets aparecen, se vacían y
vuelven; tarjetas duplicadas.

**Mecanismo:** `_renderDashEquipo` y `_renderAccesosColaborador` eran `async` y
hacían su propia query a `equipo` en cada render. El dashboard se renderiza 3
veces al iniciar sesión (caché en `_entrarApp`, caché en `cargarTodo`, datos
frescos) → 6 queries concurrentes que resolvían fuera de orden y hacían
`innerHTML` / `appendChild` sobre el mismo DOM.

**Fix:**
- Traer los datos **una vez** en el `Promise.allSettled` de `cargarTodo` y
  cachearlos en `window._xxxCache`.
- Funciones de render **sincrónicas**, que leen de la caché.
- **Idempotentes**: quitar el nodo antes de re-agregarlo (`getElementById(...).remove()`).
- Si la caché todavía no cargó, **no tocar el DOM** (evita el flash vacío).

**Prevención:** una función `render*` nunca debe hacer fetch ni ser `async`.
Nada de `appendChild` sin antes remover la versión anterior.

## Causa C — Animaciones infinitas (todavía no nos pasó, revisar)

Si `animInfinitas` muestra animaciones sobre contenedores grandes o fuera de
pantalla, pausarlas cuando no se ven (`animation-play-state:paused` o sacar la
clase) y respetar `@media (prefers-reduced-motion: reduce)`.

## Checklist del PR

- [ ] Medido antes y después con `diagnostico.js` (pegar ambos resultados en el PR).
- [ ] Deploy en `success` y fragmento del fix presente en el sitio vivo.
- [ ] Usuario hizo `Cmd + Shift + R`.
- [ ] Si la causa es A: pedir que lo pruebe en celular (es de GPU, en desktop no se ve bien).
- [ ] Si apareció una causa nueva: agregarla a este archivo.
