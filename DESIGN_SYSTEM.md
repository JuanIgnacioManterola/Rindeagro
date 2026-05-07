# RindeAgro — Design System

> **Propósito:** Este documento es la fuente única de verdad para el sistema de diseño de RindeAgro. Cualquier IA o desarrollador que modifique `index.html` debe leerlo antes de agregar o cambiar componentes visuales.

---

## 1. TOKENS — Variables CSS

Todas definidas en `:root` al inicio del `<style>`. **Nunca hardcodear valores hex en estilos inline o nuevas clases — siempre usar estas variables.**

### Paleta verde (color primario)

| Variable | Valor | Uso | No usar para |
|----------|-------|-----|--------------|
| `--verde` | `#1a4a2e` | Color primario, CTAs, headers, bordes activos, textos de marca | Texto sobre fondo oscuro (contraste bajo) |
| `--verde-mid` | `#2d6e47` | Hover de botones verdes, fondo del header de campo | Fondo de elementos grandes (muy oscuro) |
| `--verde-light` | `#3d8f5f` | Acentos secundarios, indicadores activos | Botón principal (usar `--verde`) |
| `--verde-pale` | `#e8f5ee` | Fondos de badges positivos, fondo activo de nav | Texto (muy claro) |

### Paleta dorada (acento / destacado)

| Variable | Valor | Uso | No usar para |
|----------|-------|-----|--------------|
| `--dorado` | `#c9a84c` | Badges "más elegido", puntos de acento, gráficos, logotipo `.d` | Botón primario de acción |
| `--dorado-light` | `#e8c97a` | Hover del dorado, texto sobre fondo verde oscuro | |
| `--dorado-pale` | `#fdf8ec` | Fondos de elementos con acento dorado | |

### Neutros / fondos

| Variable | Valor | Uso | No usar para |
|----------|-------|-----|--------------|
| `--crema` | `#faf7f0` | Fondo del body, fondo de inputs de formularios, fondo de tabs activas en nav | |
| `--crema-dark` | `#f0ead8` | Hover de elementos sobre crema, separadores suaves | |
| `--blanco` | `#ffffff` | Fondo de cards, modales, inputs | |
| `--borde` | `rgba(26,74,46,.12)` | Bordes de cards, separadores, bordes de inputs | Bordes de estado (error/éxito — usar semánticos) |

### Texto

| Variable | Valor | Uso | No usar para |
|----------|-------|-----|--------------|
| `--texto` | `#1a1a18` | Cuerpo de texto, valores principales | Labels y texto secundario |
| `--texto-mid` | `#3d3d38` | Títulos de sección secundarios, labels de form | |
| `--texto-suave` | `#7a7a6e` | Labels, subtítulos, metadatos, placeholders | Valores numéricos importantes |

### Semánticos

| Variable | Valor | Uso | No usar para |
|----------|-------|-----|--------------|
| `--rojo` | `#c0392b` | Error, negativo, costo, margen negativo | Acción destructiva sin confirmación |
| `--rojo-pale` | `#fdecea` | Fondo de badges de error | |
| `--amber` | `#c97a14` | Advertencia, base/neutro en sensibilidad | |
| `--amber-pale` | `#fdf3e3` | Fondo de badges de advertencia | |
| `--azul` | `#1a5fa8` | Información, ingresos/ventas, fungicidas | |
| `--azul-pale` | `#e8f0fb` | Fondo de badges de información | |

### Sombras

| Variable | Valor | Cuándo usar |
|----------|-------|-------------|
| `--sombra` | `0 4px 24px rgba(26,74,46,.08)` | Cards base, elementos en reposo |
| `--sombra-md` | `0 8px 32px rgba(26,74,46,.12)` | Cards en hover, modales pequeños |
| `--sombra-lg` | `0 16px 56px rgba(26,74,46,.16)` | Modales principales, toasts, dropdowns |

---

## 2. TIPOGRAFÍA

### Fuentes cargadas

```html
<!-- Google Fonts — en el <head> -->
Playfair Display — serif, para títulos
DM Sans         — sans-serif, para cuerpo de texto (font-family del body)
DM Mono         — monospace, para números financieros
```

### Cuándo usar cada fuente

| Fuente | Cuándo usar | Cuándo NO usar |
|--------|-------------|----------------|
| **Playfair Display** | Títulos de módulos (`.mod-titulo`), títulos de modales (`.m-tit`), logo, valores grandes en `.met-v`, precios en landing | Texto de cuerpo, labels, botones |
| **DM Sans** | Todo el cuerpo de texto, labels, botones, nav, descripiones | Números financieros, títulos principales |
| **DM Mono** | Valores numéricos financieros (USD, qq, %), fechas en tablas, datos de sensibilidad | Texto narrativo, labels |

### Escala de tamaños usada

| Contexto | Tamaño | Clase/elemento |
|----------|--------|----------------|
| Título de módulo | `24px` | `.mod-titulo` |
| Título de modal | `18px` | `.m-tit` |
| Valor de métrica | `22px` | `.met-v` |
| Nombre de campo | `16px` | `.cn` |
| Texto de cuerpo | `13–14px` | general |
| Labels de formulario | `14px` | `.fl` |
| Inputs | `16px` (evita zoom en mobile) | `.fi` |
| Label de métrica | `11px` uppercase | `.met-l` |
| Metadatos / subtítulos | `11–12px` | `.met-s`, `.mod-sub` |
| Tags / badges | `10–11px` | `.gtag`, `.etapa-tag` |

### Pesos tipográficos usados

| Peso | Uso |
|------|-----|
| `400` | Texto de cuerpo, subtítulos itálicos |
| `500` | Labels, nav items, nombres de campo |
| `600` | Botones, labels de formulario, subtítulos de card |
| `700` | Títulos principales, valores de métricas, botón primario |

---

## 3. COMPONENTES

### Botones

#### `.btn-primary` — Botón primario (landing)
```html
<button class="btn-primary">Empezar gratis</button>
```
- Fondo: `--verde` | Texto: `#fff` | Hover: `--verde-mid` + lift `-1px`
- **Usar en:** navbar de landing, acciones principales fuera de la app

#### `.btn-ghost` — Botón secundario (landing)
```html
<button class="btn-ghost">Ingresar</button>
```
- Borde: `--borde` | Hover: borde `--verde`, texto `--verde`
- **Usar en:** acción secundaria junto a `.btn-primary`

#### `.btn-hero` — CTA grande (landing)
```html
<button class="btn-hero btn-verde">🌱 Empezar gratis</button>
<a class="btn-hero btn-outline" href="#features">Ver más →</a>
```
- Variantes: `.btn-verde` (fondo verde) y `.btn-outline` (borde verde)
- Padding generoso (`15px 34px`), `font-size: 15px`

#### `.btn-vs` — Botón primario de app (verde sólido)
```html
<button class="btn-vs" onclick="openModalCampo()">+ Nuevo campo</button>
```
- **El botón de acción principal dentro de la app.** Fondo `--verde`, `border-radius: 8px`
- **Usar en:** crear/guardar elementos, CTAs en módulos

#### `.btn-sm` — Botón secundario pequeño
```html
<button class="btn-sm">Editar</button>
```
- Borde `--borde`, hover: borde `--verde`, texto `--verde`
- **Usar en:** acciones secundarias en card headers

#### `.btn-salir` — Botón destructivo suave
```html
<button class="btn-salir" onclick="cerrarSesion()">Salir</button>
```
- Hover: borde y texto `--rojo`

#### `.sub-tipo-btn` — Selector de subtipo
```html
<button class="sub-tipo-btn active">Herbicida</button>
<button class="sub-tipo-btn">Fungicida</button>
```
- Estado `.active`: fondo `--verde`, texto blanco
- **Usar en:** selección de opciones dentro de formularios de gastos

---

### Cards

#### `.card` — Card base
```html
<div class="card">
  <div class="card-hdr">
    <span class="card-tit">TÍTULO DE SECCIÓN</span>
    <button class="btn-sm">Acción</button>
  </div>
  <!-- contenido -->
</div>
```
- Fondo `--blanco`, borde `.5px solid --borde`, `border-radius: 16px`, sombra `--sombra`
- `.card-tit`: `11px uppercase letter-spacing .07em` en `--texto-suave`

#### `.campo-card` — Card de campo en lista
```html
<div class="campo-card" onclick="abrirCampo('id')">
  <div style="height:5px;background:#1a4a2e"></div>
  <div style="padding:1.1rem 1.25rem">
    <!-- nombre, estado, datos -->
  </div>
</div>
```
- Acento de color arriba (`5px` del color del campo)
- Hover: lift `-3px` + sombra `--sombra-md`

---

### Métricas

#### `.met` — Tarjeta de métrica
```html
<div class="met">
  <div class="met-acc" style="background:#1a4a2e"></div>
  <div class="met-l">HECTÁREAS</div>
  <div class="met-v" style="color:#1a4a2e">907 ha</div>
  <div class="met-s">3 campos</div>
</div>
```
- `.met-acc`: barra de color de `4px` de alto en el borde superior — siempre igual al color del valor
- `.met-l`: label uppercase `11px` en `--texto-suave`
- `.met-v`: valor principal `22px` Playfair, color semántico
- `.met-s`: subtítulo `13px` en `--texto-suave`
- Hover: lift `-2px` + sombra `--sombra-md`
- **Siempre usar en grids:** `.grid4` o `.grid5` para métricas del dashboard

**Colores semánticos para `.met-acc` y `.met-v`:**
| Tipo | Color |
|------|-------|
| Hectáreas / primario | `--verde` → `#1a4a2e` |
| Ingresos / positivo | `--azul` → `#1a5fa8` |
| Costos / negativo | `--rojo` → `#c0392b` |
| Margen positivo | `#1a7a52` |
| Margen negativo | `--rojo` → `#c0392b` |
| Campos / acento | `--dorado` → `#c9a84c` |

---

### Precio Strip

#### `.precio-strip` — Barra de precios de mercado
```html
<div class="precio-strip">
  <div class="pi">
    <div class="pi-l">Soja · Rosario</div>
    <div class="pi-v" id="ps-soja">USD 341</div>
    <div class="pi-d up">+1.2%</div>
  </div>
  <!-- más .pi -->
</div>
```
- Fondo gradiente verde oscuro, items separados por borde rgba blanco
- `.pi-v`: `DM Mono`, `16px`, blanco
- `.pi-d`: `11px`, `.up` → `#1a7a52`, `.dn` → `--rojo`

---

### Navegación

#### `.app-nav` + `.anl` — Nav principal de la app
```html
<nav class="app-nav">
  <div class="app-nav-links">
    <button class="anl active" onclick="showModulo('dashboard')">
      <span>🏠</span><span>Inicio</span>
    </button>
  </div>
</nav>
```
- `.anl`: `15px`, padding `9px 16px`, `border-radius: 9px`
- Estado `.active`: fondo `--verde-pale`, texto `--verde`
- Hover: fondo `--crema`, texto `--verde`

#### `.user-chip` — Chip de usuario
```html
<div class="user-chip">
  <div class="u-av">JM</div>
  <span class="u-nm">Juan</span>
</div>
```

---

### Modales

#### `.overlay` + `.modal` — Modal estándar
```html
<div class="overlay" id="ov-mi-modal">
  <div class="modal">
    <button class="m-close" onclick="closeModal('mi-modal')">×</button>
    <div class="m-tit">Título del modal</div>
    <div class="m-sub">Descripción breve del modal.</div>
    <!-- formulario o contenido -->
  </div>
</div>
```
- Overlay: `rgba(26,74,46,.65)` + `backdrop-filter: blur(12px)`
- Modal: `border-radius: 22px`, `max-width: 460px`, `max-height: 92vh`
- Abrir: agregar clase `.open` al overlay → opacidad 1 + modal baja desde arriba
- `.m-tit`: `18px` Playfair, `--verde`
- `.m-sub`: `12px`, `--texto-suave`
- **Nunca crear diálogos con `<dialog>` o `alert()` — siempre `.overlay + .modal`**

#### `.tabs` + `.tab` — Tabs dentro de modales
```html
<div class="tabs">
  <button class="tab on">Tab 1</button>
  <button class="tab">Tab 2</button>
</div>
```
- Estado `.on`: fondo blanco, texto `--verde`, sombra leve

---

### Formularios

#### Estructura estándar de campo de formulario
```html
<div class="fg">
  <label class="fl">Nombre del campo</label>
  <input class="fi" type="text" placeholder="Ej: La Esperanza"/>
</div>
```
- `.fg`: contenedor con `margin-bottom: .9rem`
- `.fl`: label `14px`, peso `500`, `--texto-mid`
- `.fi`: input `16px` (evita auto-zoom en iOS), borde `1.5px solid --borde`, focus borde `--verde`
- `.fb`: botón submit verde de ancho completo

#### `.form-row2` / `.form-row3` — Grids de formulario
```html
<div class="form-row2">
  <div class="fg">...</div>
  <div class="fg">...</div>
</div>
```
- `.form-row2`: 2 columnas iguales, gap `8px`
- `.form-row3`: 3 columnas iguales, gap `8px`

#### `.conv-box` — Caja de conversión/resumen
```html
<div class="conv-box">
  <div><div class="conv-l">Toneladas</div><div class="conv-v">30 t</div></div>
  <div><div class="conv-l">Precio/tn</div><div class="conv-v">USD 200</div></div>
  <div><div class="conv-l">Total USD</div><div class="conv-v">6.000</div></div>
</div>
```
- Fondo `--crema`, 3 columnas, fuente `DM Mono` para valores

---

### Tags y Badges de Rubros

#### `.gtag` + `.r-{rubro}` — Tag de rubro de gasto
```html
<span class="gtag r-herbicidas">Herbicidas</span>
<span class="gtag r-fertilizantes">Fertilizantes</span>
```

| Clase | Background | Color texto | Rubro |
|-------|-----------|-------------|-------|
| `.r-herbicidas` | `#e8f5ee` | `#1a7a52` | Herbicidas |
| `.r-fungicidas` | `--azul-pale` | `--azul` | Fungicidas |
| `.r-fertilizantes` | `--amber-pale` | `--amber` | Fertilizantes |
| `.r-semillas` | `#f0fef4` | `#16a34a` | Semillas |
| `.r-laboreo` | `--dorado-pale` | `--dorado` | Laboreo |
| `.r-flete` | `#f5f0ff` | `#7c3aed` | Flete |
| `.r-arrendamiento` | `#fef3c7` | `#d97706` | Arrendamiento |
| `.r-empleados` | `#fce7f3` | `#9d174d` | Empleados |
| `.r-insecticidas` | `#fef9c3` | `#a16207` | Insecticidas |
| `.r-riego` | `#e0f2fe` | `#0369a1` | Riego |
| `.r-otros` | `#f4f4f5` | `#71717a` | Otros |

**Patrón para nuevo rubro:** background muy claro (pale), color texto saturado del mismo tono.

---

### Tags de Etapa Fenológica

```html
<span class="etapa-tag e-siembra">Siembra</span>
```

| Clase | Background | Color | Etapa |
|-------|-----------|-------|-------|
| `.e-barbecho` | `#f4f4f5` | `#71717a` | Barbecho |
| `.e-siembra` | `#f0fef4` | `#16a34a` | Siembra |
| `.e-vegetativo` | `--verde-pale` | `--verde` | Vegetativo |
| `.e-floracion` | `--rojo-pale` | `--rojo` | Floración |
| `.e-llenado` | `--amber-pale` | `--amber` | Llenado |
| `.e-maduracion` | `--dorado-pale` | `--dorado` | Maduración |

---

### Tags de Estado Nutricional

```html
<span class="nut-estado n-optimo">Óptimo</span>
```

| Clase | Background | Color | Estado |
|-------|-----------|-------|--------|
| `.n-critico` | `--rojo-pale` | `--rojo` | Crítico |
| `.n-bajo` | `--amber-pale` | `--amber` | Bajo |
| `.n-optimo` | `--verde-pale` | `#1a7a52` | Óptimo |
| `.n-alto` | `--azul-pale` | `--azul` | Alto |

---

### Rows

#### `.campo-row` — Fila de campo en lista
```html
<div class="campo-row" onclick="abrirCampo('id')">
  <div class="cdot" style="background:#1a4a2e"></div>
  <div class="ci">
    <div class="cn">La Esperanza</div>
    <div class="cm">Soja · 307 ha</div>
  </div>
  <div class="cmg">
    <div class="cmgv" style="color:#1a7a52">+240 USD/ha</div>
    <div class="cmgp">307 ha</div>
  </div>
</div>
```

#### `.gasto-row` — Fila de gasto
```html
<div class="gasto-row">
  <span class="gtag r-herbicidas">Herbicidas</span>
  <!-- descripción, fecha, monto -->
</div>
```

#### `.lluvia-row` — Fila de registro de lluvia
```html
<div class="lluvia-row">
  <span class="etapa-tag e-siembra">Siembra</span>
  <!-- fecha, mm -->
</div>
```

#### `.nutriente-row` — Fila de análisis de suelo
```html
<div class="nutriente-row">
  <div class="nut-label">Fósforo (P)</div>
  <div class="nut-bar-wrap"><div class="nut-bar" style="width:65%;background:#1a7a52"></div></div>
  <div class="nut-val">18 ppm</div>
  <span class="nut-estado n-optimo">Óptimo</span>
</div>
```

---

### Toasts

```javascript
// Invocar siempre con la función showToast — nunca crear HTML de toast manualmente
showToast('✓ Campo guardado', 'ok')    // verde
showToast('⚠️ Error al guardar', 'err') // rojo
showToast('ℹ️ Dato cargado', 'info')   // azul
showToast('Procesando...', '')          // verde (default)
```

| Tipo | Clase CSS | Color |
|------|-----------|-------|
| Éxito | `.toast.ok` | `#1a7a52` |
| Error | `.toast.err` | `--rojo` |
| Info | `.toast.info` | `--azul` |
| Default | `.toast` | `--verde` |

- Posición: `fixed bottom:1.75rem right:1.75rem`
- Aparece con animación: clase `.show` → `opacity:1` + `translateY(0)`
- **Nunca usar `alert()` — siempre `showToast()`**

---

### Sensibilidad

```html
<table class="sens-table">
  <thead>
    <tr><th>Rend \ Precio</th><th>USD 300</th></tr>
  </thead>
  <tbody>
    <tr>
      <td>3.2 t/ha</td>
      <td><span class="cell-pos">+240</span></td>
      <td><span class="cell-base">+96</span></td>
      <td><span class="cell-neg">-48</span></td>
    </tr>
  </tbody>
</table>
```

| Clase | Significado | Estilo |
|-------|-------------|--------|
| `.cell-pos` | Margen positivo | Fondo `#e8f5ee`, texto `#1a7a52` |
| `.cell-neg` | Margen negativo | Fondo `--rojo-pale`, texto `--rojo` |
| `.cell-base` | Caso base (actual) | Fondo `rgba(201,168,76,.15)`, texto `--amber` |
| `.cell-be` | Break-even | Dorado más saturado con borde |

---

### Empty States

```html
<div class="empty">
  <div class="empty-i">🌾</div>
  <div class="empty-t">Sin campos registrados</div>
  <div class="empty-s">Agregá tu primer campo para ver la rentabilidad.</div>
  <button class="btn-vs" onclick="openModalCampo()">+ Agregar campo</button>
</div>
```
- **Siempre usar esta estructura exacta** para pantallas vacías
- `.empty-i`: emoji o ícono de `36px`
- `.empty-t`: título `14px` en `--texto-mid`
- `.empty-s`: descripción `12px` en `--texto-suave`
- Opcionalmente: CTA con `.btn-vs` al final

---

### Sistema de Grids

```html
<div class="grid2"><!-- 2 columnas --></div>
<div class="grid3"><!-- 3 columnas --></div>
<div class="grid4"><!-- 4 columnas (métricas) --></div>
<div class="grid5"><!-- 5 columnas (métricas ampliadas) --></div>
```

- Todas usan `gap: 10–14px` y `margin-bottom: 14px`
- Responsive `≤780px`: `.grid2/.grid3/.grid4/.grid5` → 2 columnas
- Responsive `≤480px`: todas → 1 columna

---

### Tabs de Campo (dentro de detalle)

```html
<button class="campo-tab active" onclick="switchCampoTab('ingresos', this)">
  💵 Ingresos
</button>
```
- Tabs en barra del header verde del campo
- `.active`: fondo `rgba(255,255,255,.22)`, texto blanco, sombra
- Invocar siempre con `switchCampoTab(nombre, this)` — nunca manipular clases manualmente

---

## 4. ESPACIADO Y LAYOUT

### Valores de espaciado más usados

| Valor | Uso |
|-------|-----|
| `4px` | Gaps mínimos, margin entre label y valor |
| `6–8px` | Gaps entre items inline, padding de badges |
| `10–14px` | Gaps de grids, margin entre cards |
| `1rem (16px)` | Padding base de elementos |
| `1.25rem` | Padding de cards |
| `1.5rem` | Margin entre secciones de formulario |
| `1.75rem` | Margin entre secciones de módulo |
| `2rem` | Padding del módulo, nav lateral |
| `2.25rem` | Padding de modales |

### Border-radius estándar

| Valor | Uso |
|-------|-----|
| `6–7px` | Badges, tags, botones pequeños |
| `8–9px` | Inputs, botones secundarios |
| `10px` | Tabs, conv-box, elementos intermedios |
| `12px` | Mapa, toast |
| `16px` | Cards principales, métricas |
| `18px` | Feature cards, plan cards |
| `22px` | Modales |
| `50%` | Avatares, dots de campo, spinner |

### Breakpoints responsive

| Punto | Valor | Comportamiento |
|-------|-------|----------------|
| Tablet | `≤780px` | Nav links ocultos, grids → 2 cols, nav labels ocultos |
| Mobile | `≤480px` | Todos los grids → 1 columna |

---

## 5. SOMBRAS Y BORDES

### Uso de sombras

| Variable | Cuándo usar |
|----------|-------------|
| `--sombra` | Cards en reposo (`.card`, `.met`, `.campo-card`) |
| `--sombra-md` | Hover de cards, drawer/panel secundario |
| `--sombra-lg` | Modales principales, toasts, precio strip |

### Borde estándar

- **Valor:** `.5px solid var(--borde)` → `rgba(26,74,46,.12)`
- Siempre `.5px`, nunca `1px` para bordes estructurales
- Excepción: inputs `.fi` usan `1.5px` para mayor legibilidad
- Bordes activos/foco: `1.5–2px solid var(--verde)`

---

## 6. COLORES SEMÁNTICOS

| Estado | Color principal | Color pale (fondo) | Usar en |
|--------|----------------|-------------------|---------|
| **Éxito / positivo / ingreso** | `#1a7a52` | `--verde-pale #e8f5ee` | Margen positivo, badges de ingreso, `.cell-pos` |
| **Error / negativo / costo** | `--rojo #c0392b` | `--rojo-pale #fdecea` | Margen negativo, errores, delete, `.cell-neg` |
| **Advertencia / estimado** | `--amber #c97a14` | `--amber-pale #fdf3e3` | Caso base en sensibilidad, campos sin datos |
| **Información / venta** | `--azul #1a5fa8` | `--azul-pale #e8f0fb` | Ingresos, fungicidas, toast info |
| **Neutro / sin datos** | `#71717a` | `#f4f4f5` | Estados sin datos, gastos "otros" |

---

## 7. PATRONES DE USO — Reglas para la IA

### Colores y estilos
- ✅ **Siempre usar variables CSS** (`var(--verde)`, etc.) — nunca hardcodear hex en `<style>` estático
- ✅ Los estilos inline (`style="..."`) solo se usan para **valores dinámicos calculados en JS** (colores de campo, anchos de barras de progreso)
- ✅ El borde estándar es siempre `.5px solid var(--borde)` — nunca `1px`
- ❌ No crear nuevas clases CSS globales sin agregarlas a este documento

### Tipografía
- ✅ Títulos de módulos: `font-family: 'Playfair Display', serif`
- ✅ Valores numéricos financieros (USD, qq, %): `font-family: 'DM Mono', monospace`
- ✅ Todo el resto: `font-family: 'DM Sans', sans-serif` (heredado del body)
- ❌ No usar otras fuentes sin agregar su `@import` y documentarla aquí

### Componentes
- ✅ Botón de acción principal en la app: **siempre `.btn-vs`**
- ✅ Modales: **siempre `.overlay` + `.modal`** — nunca `<dialog>`, `confirm()` o `alert()`
- ✅ Toasts: **siempre `showToast(msg, tipo)`** — nunca crear HTML de toast manualmente
- ✅ Pantallas vacías: **siempre `.empty > .empty-i + .empty-t + .empty-s`**
- ✅ Métricas del dashboard: **siempre `.met` con `.met-acc`** del color semántico correcto
- ✅ Nuevos rubros de gasto: **clase `.r-{nombre}`** con background pale y color saturado (ver tabla)
- ✅ Tabs dentro del campo: invocar siempre `switchCampoTab(tab, btn)` — nunca manipular clases directamente

### Datos y cálculos
- ✅ Los ingresos se calculan **solo desde datos reales** guardados en `ingresos_cultivos` — nunca usar defaults de rendimiento estimado × precio de mercado si el usuario no cargó datos. Usar `_ingRealParaCampo(c)`
- ✅ Las hectáreas por cultivo se calculan con `_haParaCultivo(c, cult, cultivosList)` — respeta prioridad: polígono > ingresos_cultivos > proporción equitativa
- ✅ Los gastos se leen desde el array global `gastos`, filtrando por `campo_id` y rango de campaña

### Layout y grids
- ✅ Usar `.grid2`, `.grid3`, `.grid4`, `.grid5` para columnas — nunca CSS grid inline
- ✅ Métricas del dashboard usan `.grid5` o `.grid4` según cantidad
- ✅ Padding de módulo: `2rem 1.25rem` (ya en `.modulo`)
- ✅ Cards siempre con `margin-bottom: 14px` (ya en `.card`)

---

## 8. CONVENCIONES DE CÓDIGO

### Nomenclatura de funciones JS

| Prefijo / patrón | Significado | Ejemplos |
|-----------------|-------------|---------|
| `render*` | Renderiza HTML en el DOM | `renderDashboard()`, `renderCamposLista()`, `renderDetGastos()` |
| `renderCampo*` | Renderiza tab del detalle de campo | `renderCampoRent()` |
| `open*` / `close*` | Abre/cierra modal | `openModalCampo()`, `closeModalCampo()` |
| `guardar*` | Guarda en Supabase | `guardarCampo()`, `guardarGasto()` |
| `mostrar*` | Muestra/oculta elemento | `mostrarPrecios()` |
| `calc*` | Cálculo sin efecto DOM | `calcConv()`, `calcRendReal()` |
| `switch*Tab` | Cambia tab activa | `switchCampoTab()` |
| `show*` | Muestra pantalla/módulo | `showModulo()`, `showScreen()` |
| `_*` (underscore) | Helper interno, no expuesto | `_ingRealParaCampo()`, `_guardarCache()`, `_haParaCultivo()` |
| `init*` | Inicialización única | `initMapa()`, `initLanding()` |
| `abrir*` | Navega a vista de detalle | `abrirCampo()` |

### Variables globales principales

```javascript
var usuario    // objeto de sesión Supabase
var campos     // array de campos del usuario
var gastos     // array de gastos
var lluvias    // array de registros de lluvia
var analisisS  // array de análisis de suelo
var precios    // {soja, maiz, trigo, girasol, sorgo, bna} — precios actuales
var campoRent  // id del campo seleccionado en Rentabilidad
var campoDet   // id del campo abierto en detalle
var campanaActivaId // id de campaña activa
var COLORES    // paleta de 6 colores para campos (asignados por índice)
```

### Queries a Supabase

```javascript
// Patrón estándar (await + manejo de error):
var { data, error } = await sb.from('campos')
  .select('*')
  .eq('usuario_id', uid)
  .order('creado_en', { ascending: false })
if (error) { showToast('⚠️ Error: ' + error.message, 'err'); return }

// Para updates críticos, usar _sbRace() con timeout:
var r = await _sbRace(sb.from('campos').update({...}).eq('id', id), 8000)
```

### Manejo de errores

```javascript
// Toast para errores de usuario:
showToast('⚠️ Completá todos los campos', 'err')

// Try/catch para JSON o operaciones que pueden fallar silenciosamente:
try { savedIngr = JSON.parse(c.ingresos_cultivos || '{}') } catch(e) {}

// Siempre validar antes de guardar:
if (!nombre || !ha) { showToast('⚠️ Ingresá nombre y hectáreas', 'err'); return }
```

### Actualización del DOM

- **Siempre `innerHTML`** para renderizado completo de secciones — el proyecto no usa frameworks
- **`textContent`** para actualizar texto simple sin HTML
- **Nunca `document.createElement`** — usar template strings en `innerHTML`
- Después de modificar datos: llamar a `_guardarCache()` y al render correspondiente
- Después de guardar en Supabase: llamar a `renderDashboard()` + la función del módulo activo

### Cache de datos

```javascript
// Guardar siempre después de modificar campos/gastos/lluvias:
_guardarCache()

// Los datos se cargan en paralelo al inicio:
var [resC, resG, resL, resS] = await Promise.allSettled([
  sb.from('campos')...,
  sb.from('gastos')...,
  ...
])
```

---

## 9. COMPONENTES PENDIENTES DE CREAR

Completar esta tabla a medida que se agregan nuevos componentes:

| Componente | Clases | Descripción | Agregado en fecha |
|-----------|--------|-------------|-------------------|
| (vacío — completar cuando se agreguen) | | | |

---

## Cómo usar este documento

Cada vez que se agregue una feature nueva a RindeAgro:

1. **Verificar** si el componente necesario ya existe en este documento
2. **Si existe:** usar exactamente las mismas clases y estructura HTML
3. **Si no existe:** crearlo siguiendo los patrones documentados (paleta, tipografía, espaciado, bordes)
4. **Agregar** el componente nuevo a la sección "Componentes pendientes" con su fecha
5. **Nunca hardcodear** colores, sombras ni tipografías — siempre usar variables CSS
6. **Probar** que el componente sea responsive (se adapte a `≤780px` y `≤480px`)

---

*Última actualización: Mayo 2026 — generado desde el `index.html` del repo `JuanIgnacioManterola/Rindeagro`*
