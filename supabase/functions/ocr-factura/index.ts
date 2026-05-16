// Supabase Edge Function: ocr-factura
// Recibe imagen base64 + mime + tipo (factura/remito) y devuelve {items: [...]}
// Usa Claude API (Anthropic) con vision para extraer renglones de insumos.
//
// Variables de entorno requeridas (Supabase secrets):
//   ANTHROPIC_API_KEY  → key de console.anthropic.com
//
// Despliegue:
//   supabase functions deploy ocr-factura --no-verify-jwt=false
// O via MCP: mcp__supabase__deploy_edge_function

import "jsr:@supabase/functions-js/edge-runtime.d.ts"

const ANTHROPIC_API_KEY = Deno.env.get("ANTHROPIC_API_KEY") || ""
const CLAUDE_MODEL = Deno.env.get("CLAUDE_MODEL") || "claude-sonnet-4-5-20250929"

const CORS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
}

interface Item {
  nombre: string
  tipo: string
  cantidad: number
  unidad: string
  precio_unitario: number | null
}

const SYSTEM_PROMPT = `Sos un asistente especializado en agricultura argentina. Tu trabajo es leer facturas y remitos de insumos agropecuarios (herbicidas, fungicidas, insecticidas, fertilizantes, semillas) y extraer los renglones en formato JSON.

Reglas:
- Devolvé SOLO JSON válido, sin texto antes ni después, sin bloque \`\`\`.
- Si el documento es un REMITO, no incluyas precios (precio_unitario:null) aunque aparezcan.
- Si el documento es una FACTURA, incluí el precio unitario en USD si está, o convertí desde ARS al tipo de cambio si aparece. Si no hay precio, dejá null.
- Reconocé marcas argentinas comunes: glifosato, atrazina, paraquat, 2,4-D, dicamba, mancozeb, metalaxil, cipermetrina, lambdacialotrina, lufenuron, urea, DAP, MAP, fosfato monoamónico, etc.
- Clasificá cada insumo en uno de: herbicidas, fungicidas, insecticidas, fertilizantes, semillas, otros.
- Unidades: litros (L), kg, dosis, bolsas.
- Solo extrae renglones de INSUMOS. Ignorá: flete, descuentos, impuestos, intereses, totales, mano de obra.
- Si no podés identificar nada, devolvé {"items":[]}.

Formato:
{"items":[{"nombre":"Glifosato 48%","tipo":"herbicidas","cantidad":100,"unidad":"litros","precio_unitario":3.20}, ...]}`

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS })
  if (req.method !== "POST") return jsonResp({ error: "Method not allowed" }, 405)

  if (!ANTHROPIC_API_KEY) {
    return jsonResp({ error: "ANTHROPIC_API_KEY no configurada en el servidor" }, 500)
  }

  let body: any = null
  try { body = await req.json() } catch { return jsonResp({ error: "JSON inválido" }, 400) }

  const image_base64 = String(body?.image_base64 || "")
  const mime_type   = String(body?.mime_type || "image/jpeg")
  const tipo        = String(body?.tipo || "factura").toLowerCase()
  if (!image_base64) return jsonResp({ error: "Falta image_base64" }, 400)

  // PDFs: Claude API ahora soporta PDFs nativos también
  const isImage = mime_type.startsWith("image/")
  const isPdf   = mime_type === "application/pdf"
  if (!isImage && !isPdf) return jsonResp({ error: "Tipo de archivo no soportado: " + mime_type }, 400)

  const userText = `Este es un ${tipo} de un productor agropecuario argentino. Extraé los insumos en JSON según el formato indicado.`

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
        max_tokens: 2048,
        system: SYSTEM_PROMPT,
        messages: [{ role: "user", content }],
      }),
    })
    if (!r.ok) {
      const errTxt = await r.text().catch(() => "")
      return jsonResp({ error: "Claude API " + r.status, detail: errTxt }, 502)
    }
    const data = await r.json() as any
    const text: string = (data?.content || [])
      .filter((c: any) => c.type === "text")
      .map((c: any) => c.text)
      .join("")
      .trim()

    // Extraer JSON (Claude debería devolverlo limpio, pero por las dudas)
    let jsonStr = text
    const m = text.match(/\{[\s\S]*\}/)
    if (m) jsonStr = m[0]
    let parsed: any = null
    try { parsed = JSON.parse(jsonStr) } catch {
      return jsonResp({ error: "Respuesta de Claude no es JSON válido", raw: text.slice(0, 500) }, 502)
    }
    const items: Item[] = Array.isArray(parsed?.items) ? parsed.items : []
    return jsonResp({ items, model: CLAUDE_MODEL, tipo, count: items.length })
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
