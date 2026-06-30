// Supabase Edge Function: ocr-pago
// Lee foto/PDF de un cheque o de un voucher/contrato de crédito y devuelve
// los campos parseados para que el frontend pre-llene el modal correspondiente.
//
// Variables de entorno requeridas (Supabase secrets):
//   ANTHROPIC_API_KEY  → key de console.anthropic.com
//
// Body esperado: { image_base64, mime_type, tipo: 'cheque' | 'credito' }
//
// Respuesta para cheque:
//   {
//     tipo: 'cheque',
//     beneficiario, importe, moneda, fecha_emision, fecha_cobro, banco, numero_cheque
//   }
// Respuesta para crédito:
//   {
//     tipo: 'credito',
//     descripcion, cuota_importe, moneda, n_cuotas, frecuencia, fecha_primera, beneficiario
//   }

import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") || ""
const CLAUDE_MODEL = Deno.env.get("CLAUDE_MODEL") || "claude-sonnet-4-5-20250929"

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

const SYSTEM_PROMPT_CHEQUE = `Sos un asistente especializado en parsear cheques bancarios argentinos. Te paso una imagen de un cheque emitido y tenés que devolver los datos en JSON.

Reglas:
- Devolvé SOLO JSON válido, sin texto antes ni después, sin bloque \`\`\`.
- Si no podés identificar algún campo, dejá el valor en null.
- Las fechas SIEMPRE en formato YYYY-MM-DD.
- Moneda: 'ARS' o 'USD'. Si no se puede determinar, 'ARS'.
- El importe debe ser un número decimal (sin separadores de miles, con punto decimal).
- numero_cheque debe incluir solo dígitos relevantes (no códigos de banco).

Formato:
{
  "tipo": "cheque",
  "beneficiario": "Nombre o razón social",
  "importe": 1500000.00,
  "moneda": "ARS",
  "fecha_emision": "2026-05-17",
  "fecha_cobro": "2026-08-15",
  "banco": "Banco Nación",
  "numero_cheque": "00045678"
}`

const SYSTEM_PROMPT_CREDITO = `Sos un asistente especializado en parsear contratos o vouchers de créditos bancarios argentinos. Te paso una imagen/PDF de un crédito otorgado y tenés que devolver los datos en JSON.

Reglas:
- Devolvé SOLO JSON válido, sin texto antes ni después, sin bloque \`\`\`.
- Si no podés identificar algún campo, dejá el valor en null.
- Fechas en formato YYYY-MM-DD.
- Moneda: 'ARS' o 'USD'. Si no se puede determinar, 'ARS'.
- cuota_importe: importe de cada cuota individual (no el total).
- n_cuotas: cantidad total de cuotas.
- frecuencia: 'mensual' | 'bimestral' | 'trimestral' | 'semestral' | 'anual'.
- fecha_primera: fecha de la primera cuota.

Formato:
{
  "tipo": "credito",
  "descripcion": "Préstamo Banco Galicia para sembradora",
  "cuota_importe": 500000.00,
  "moneda": "ARS",
  "n_cuotas": 12,
  "frecuencia": "mensual",
  "fecha_primera": "2026-06-15",
  "beneficiario": "Banco Galicia"
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
  const tipo        = String(body?.tipo || "cheque").toLowerCase()
  if (!image_base64) return jsonResp({ error: "Falta image_base64" }, 400)
  if (tipo !== "cheque" && tipo !== "credito") return jsonResp({ error: "tipo debe ser 'cheque' o 'credito'" }, 400)

  const isImage = mime_type.startsWith("image/")
  const isPdf   = mime_type === "application/pdf"
  if (!isImage && !isPdf) return jsonResp({ error: "Tipo de archivo no soportado: " + mime_type }, 400)

  const systemPrompt = tipo === "cheque" ? SYSTEM_PROMPT_CHEQUE : SYSTEM_PROMPT_CREDITO
  const userText = tipo === "cheque"
    ? "Parseá los datos de este cheque emitido en JSON."
    : "Parseá los datos de este crédito bancario en JSON."

  const content: any[] = []
  if (isPdf) {
    content.push({ type: "document", source: { type: "base64", media_type: "application/pdf", data: image_base64 } })
  } else {
    content.push({ type: "image", source: { type: "base64", media_type: mime_type, data: image_base64 } })
  }
  content.push({ type: "text", text: userText })

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
        system: systemPrompt,
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
    parsed.tipo = tipo
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
