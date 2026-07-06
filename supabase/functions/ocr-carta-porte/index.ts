// Supabase Edge Function: ocr-carta-porte
// Lee foto/PDF de una carta de porte electrónica argentina (granos) y devuelve
// los campos parseados para pre-llenar el modal de flete en el frontend.
//
// Variables de entorno requeridas (Supabase secrets):
//   ANTHROPIC_API_KEY  → key de console.anthropic.com
//
// Body esperado: { image_base64, mime_type }
//
// Respuesta:
//   {
//     ok: true,
//     data: {
//       fecha, cultivo, patente_camion, patente_acoplado, nombre_camionero,
//       nombre_transporte, toneladas, destino, empresa_destino,
//       ctg, carta_porte_nro, peso_bruto_kg, peso_tara_kg, peso_neto_kg,
//       humedad_porcentaje
//     }
//   }

import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") || ""
const CLAUDE_MODEL = Deno.env.get("CLAUDE_MODEL") || "claude-sonnet-4-5-20250929"

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

const SYSTEM_PROMPT = `Sos un asistente especializado en parsear cartas de porte electrónicas (CPE) argentinas para transporte de granos. Te paso una imagen o PDF de una CPE y tenés que devolver los datos en JSON.

Reglas:
- Devolvé SOLO JSON válido, sin texto antes ni después, sin bloque \`\`\`.
- Si no podés identificar algún campo, dejá el valor en null.
- Las fechas SIEMPRE en formato YYYY-MM-DD.
- Patentes en mayúsculas, sin espacios ni guiones (ej: "AB123CD", "ABC123").
- Toneladas como número decimal con punto (ej: 28.50).
- Pesos en kilogramos como número entero.
- Humedad como número decimal (ej: 13.5).
- Cultivo: usá SIEMPRE una de estas opciones capitalizadas: "Soja", "Maíz", "Trigo", "Girasol", "Sorgo", "Cebada", "Maní". Si no se identifica, null.
- CTG: el número de Código de Trazabilidad de Granos (8 dígitos aprox), sin espacios.
- carta_porte_nro: número identificador de la CPE (13-15 dígitos usualmente).
- empresa_destino: la razón social del comprador/destinatario final (ej: "Cargill S.A.", "Bunge Argentina", "ACA").
- destino: el lugar geográfico o planta (ej: "Puerto San Lorenzo", "Rosario", "Timbúes").
- nombre_transporte: la razón social de la empresa transportista (dueña del camión).
- nombre_camionero: nombre y apellido del chofer.

Formato:
{
  "fecha": "2026-07-03",
  "cultivo": "Soja",
  "patente_camion": "AB123CD",
  "patente_acoplado": "AC456EF",
  "nombre_camionero": "Juan Perez",
  "nombre_transporte": "Transportes La Verdad SRL",
  "toneladas": 28.50,
  "destino": "Puerto San Lorenzo",
  "empresa_destino": "Cargill S.A.",
  "ctg": "12345678",
  "carta_porte_nro": "20250715123456",
  "peso_bruto_kg": 45000,
  "peso_tara_kg": 16500,
  "peso_neto_kg": 28500,
  "humedad_porcentaje": 13.5
}`

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS })
  if (req.method !== "POST") return jsonResp({ error: "Method not allowed" }, 405)

  if (!ANTHROPIC_API_KEY) {
    return jsonResp({ error: "ANTHROPIC_API_KEY no configurada. El admin tiene que setearla en Supabase Edge Functions secrets." }, 500)
  }

  let body: any = null
  try { body = await req.json() } catch { return jsonResp({ error: "JSON inválido" }, 400) }

  const image_base64 = String(body?.image_base64 || "")
  const mime_type   = String(body?.mime_type || "image/jpeg")
  if (!image_base64) return jsonResp({ error: "Falta image_base64" }, 400)

  const isImage = mime_type.startsWith("image/")
  const isPdf   = mime_type === "application/pdf"
  if (!isImage && !isPdf) return jsonResp({ error: "Tipo de archivo no soportado: " + mime_type }, 400)

  const content: any[] = []
  if (isPdf) {
    content.push({ type: "document", source: { type: "base64", media_type: "application/pdf", data: image_base64 } })
  } else {
    content.push({ type: "image", source: { type: "base64", media_type: mime_type, data: image_base64 } })
  }
  content.push({ type: "text", text: "Parseá los datos de esta carta de porte en JSON." })

  try {
    const r = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "x-api-key": ANTHROPIC_API_KEY,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json",
      },
      body: JSON.stringify({
        model: CLAUDE_MODEL,
        max_tokens: 1024,
        system: SYSTEM_PROMPT,
        messages: [{ role: "user", content }],
      }),
    })
    if (!r.ok) {
      const errTxt = await r.text().catch(() => "")
      return jsonResp({ error: "Claude API " + r.status, detail: errTxt.slice(0, 400) }, 502)
    }
    const data = await r.json() as any
    const text: string = (data?.content || [])
      .filter((c: any) => c.type === "text")
      .map((c: any) => c.text)
      .join("")
      .trim()

    let jsonStr = text
    const m = text.match(/\{[\s\S]*\}/)
    if (m) jsonStr = m[0]
    let parsed: any = null
    try { parsed = JSON.parse(jsonStr) } catch {
      return jsonResp({ error: "Respuesta de Claude no es JSON válido", raw: text.slice(0, 500) }, 502)
    }
    return jsonResp({ ok: true, data: parsed, model: CLAUDE_MODEL })
  } catch (e) {
    return jsonResp({ error: String((e as Error)?.message || e) }, 500)
  }
})

function jsonResp(obj: any, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { ...CORS, "content-type": "application/json" },
  })
}
