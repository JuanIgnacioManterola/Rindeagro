// Diagnóstico de parpadeo / titileo / scroll trabado en rindeagro.app.
// Pegar en la consola del navegador (o ejecutarlo con la herramienta de
// JavaScript del Browser) con la sección problemática abierta.
// Devuelve un objeto con las 3 causas que ya nos pasaron:
//   1. capasCarasVisibles → elementos compuestos que no se ven (compositing)
//   2. mutaciones3s       → DOM reescribiéndose solo (re-renders en carrera)
//   3. animInfinitas      → animaciones CSS que nunca terminan
(async () => {
  const r = {}

  // 1) Capas compuestas "fantasma": backdrop-filter, o invisibles por opacity:0
  //    pero todavía fixed/transform/will-change. Con visibility:hidden o
  //    display:none el navegador no las compone, así que esas se saltean.
  const caras = []
  for (const el of document.querySelectorAll('body *')) {
    const s = getComputedStyle(el)
    if (s.visibility === 'hidden' || s.display === 'none') continue
    const bf = s.backdropFilter && s.backdropFilter !== 'none'
    const opacity0 = parseFloat(s.opacity) === 0
    if (bf || (opacity0 && (s.position === 'fixed' || s.transform !== 'none' || s.willChange !== 'auto'))) {
      caras.push({ el: el.id || String(el.className).slice(0, 40), bf, opacity0, pos: s.position })
    }
  }
  r.capasCarasVisibles = caras.length
  r.detalle = caras.slice(0, 20)

  // 2) Animaciones infinitas
  r.animInfinitas = document.getAnimations()
    .filter(a => a.effect && a.effect.getTiming().iterations === Infinity)
    .map(a => (a.animationName || '') + '@' + (a.effect.target.id || String(a.effect.target.className).slice(0, 30)))

  // 3) DOM que cambia solo durante 3 segundos sin tocar nada
  let n = 0
  const t = {}
  const mo = new MutationObserver(ms => {
    for (const m of ms) {
      n++
      const k = m.target.id || String(m.target.className).slice(0, 30) || m.target.nodeName
      t[k] = (t[k] || 0) + 1
    }
  })
  mo.observe(document.body, { subtree: true, childList: true, attributes: true, characterData: true })
  await new Promise(x => setTimeout(x, 3000))
  mo.disconnect()
  r.mutaciones3s = n
  r.topMutados = Object.entries(t).sort((a, b) => b[1] - a[1]).slice(0, 8)

  console.log('[diagnostico-parpadeo]', r)
  return r
})()
