# Activar el OCR de facturas y pagos

> Este archivo explica cómo activar la lectura automática de fotos/PDFs en
> Rinde.Agro. Se hace **una sola vez** y queda funcionando para siempre.
> Tarda 5 minutos.

## Qué se activa

Una vez completados los pasos, estos dos botones empiezan a funcionar:

- **Insumos → 📄 Desde factura**: subís una foto o PDF de una factura/remito
  de agroquímicos y el sistema carga automáticamente todos los insumos al stock.
- **Pagos → 📄 Desde foto/PDF**: subís un cheque o el contrato de un crédito
  y el sistema pre-llena el formulario con los datos extraídos.

Sin esto activado, los botones muestran un mensaje claro al usuario y la
carga manual sigue funcionando perfecta.

## Lo que vas a necesitar

- Una **tarjeta de crédito o débito internacional** (Visa, Mastercard, etc.).
- Acceso al **mail** con el que querés crear la cuenta de Anthropic.
- 5 minutos.

## Cuánto cuesta

La inteligencia artificial de Anthropic se paga por uso, como la electricidad.
Cada vez que lee una factura o un cheque, "consume" un poquito de saldo:

- Leer una factura: entre **USD 0.01 y USD 0.05** (1 a 5 centavos de dólar).
- Leer un cheque: entre **USD 0.01 y USD 0.03**.

Anthropic pide cargar **mínimo USD 5** la primera vez (para que la cuenta
esté activa). Con USD 5 te alcanza para **varios meses** de uso normal en
una explotación agrícola.

## Parte 1 — Generar la API key en Anthropic (3 minutos)

### Paso 1.1

Abrí el navegador y andá a:

**https://console.anthropic.com/settings/keys**

### Paso 1.2 — Crear cuenta o entrar

- Si **NO tenés cuenta** todavía:
  1. Te pide email + verificación. Usá un mail al que tengas acceso.
  2. Confirmás el código que llega por mail.
  3. Te pide cargar fondos. **Cargá USD 5** la primera vez (es el mínimo).
  4. Te pide datos de la tarjeta. Completalos.
  5. Una vez confirmado el pago, te lleva al panel principal.

- Si **ya tenés cuenta**:
  1. Logueate.
  2. Si nunca cargaste fondos, hacelo ahora: **USD 5 mínimo**.

### Paso 1.3 — Crear la API Key

1. Andá al menú **"API Keys"** (en la barra izquierda).
2. Click en el botón **"Create Key"** (arriba a la derecha).
3. Te pide nombre para la key. Poné: `Rinde.Agro OCR`
4. Click **"Create Key"**.

### Paso 1.4 — Copiar la key

Te muestra una clave que empieza con:

```
sk-ant-api03-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX...
```

> ⚠️ **MUY IMPORTANTE**: copiala AHORA. La clave se muestra **una sola vez**.
> Si cerrás la ventana sin copiarla, no la podés volver a ver y vas a tener
> que generar una nueva.

**Pegala temporalmente en algún lado seguro** (no en WhatsApp ni en un mail
público). Por ejemplo, en un bloc de notas. Vas a usarla en el siguiente paso.

## Parte 2 — Pegar la key en Supabase (2 minutos)

### Paso 2.1

Andá a esta URL (es el panel directo a los secrets del proyecto):

**https://supabase.com/dashboard/project/kmfydetiwatnwwzjnhyq/settings/functions**

> Si te pide login: usá la cuenta de Supabase del proyecto (la misma con la
> que entran al dashboard normalmente).

### Paso 2.2 — Agregar el secret

Vas a ver una sección llamada **"Edge Function Secrets"** (puede llamarse
también "Secrets" o "Environment variables" según la versión).

1. Click en **"New secret"** (o **"Add new secret"**).
2. **Name**: escribí exactamente esto (todo en MAYÚSCULAS con guiones bajos):

   ```
   ANTHROPIC_API_KEY
   ```

3. **Value**: pegá la clave que copiaste de Anthropic
   (`sk-ant-api03-...`).

4. Click **Save** (o **Add secret**).

### Paso 2.3 — Verificar

En la lista de secrets, ahora tiene que aparecer una entrada que dice
`ANTHROPIC_API_KEY` con su valor enmascarado (puntos o asteriscos por
seguridad).

## Listo

A partir de ese momento:

- **No hace falta redeployar nada.**
- **No hace falta avisar a Ignacio** (igual avisale por si quiere probar).
- Las dos edge functions (`ocr-factura` y `ocr-pago`) **ya están desplegadas
  desde antes** y al detectar el secret empiezan a funcionar al toque.

## Cómo probar

1. Entrá a Rinde.Agro: **https://rindeagro.app**
2. Logueate.
3. Andá a **Insumos**.
4. Click en **"📄 Desde factura"**.
5. Subí una foto o PDF de una factura real de agroquímicos.
6. Esperá unos segundos.
7. Te tiene que mostrar una lista de los productos con sus cantidades y
   precios (extraídos automáticamente del documento).
8. Revisalos, marcá los que quieras importar, y dale "Cargar al stock".

Si en vez de la lista te aparece un error tipo "ANTHROPIC_API_KEY no
configurada", quiere decir que el secret no se guardó bien. Revisar:
- Que el nombre sea exactamente `ANTHROPIC_API_KEY` (sin espacios, sin
  comillas, sin minúsculas).
- Que la value empiece con `sk-ant-api03-`.

## Costos a futuro

Cuando se te acabe el saldo de USD 5, Anthropic te avisa por mail. Podés
cargar de nuevo desde el mismo panel donde cargaste la primera vez
(**https://console.anthropic.com/settings/billing**).

También podés activar la **recarga automática** desde ese mismo panel,
así no se corta el servicio. Pero no es obligatorio.

## ¿Quién va a usar esta clave?

Solo el servidor de Supabase. La clave está guardada como "secret", lo que
significa que nadie (ni siquiera vos al verla en el panel) puede leer su
valor completo después de pegarla. Está cifrada.

Las edge functions del proyecto la usan para hablar con la API de Anthropic
en nombre de los usuarios. Cada vez que alguien sube una factura, Supabase
manda esa foto a Anthropic, Anthropic la lee, devuelve el JSON, y Rinde.Agro
muestra el resultado al usuario.

## Si algo sale mal

Cualquier error que tengas, mostrámelo (a Ignacio) o avisame por WhatsApp.
Lo arreglamos en 5 minutos.
