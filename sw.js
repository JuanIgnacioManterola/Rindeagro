// Service Worker mínimo para que Rinde.Agro califique como PWA instalable.
// Estrategia: network-first sin caché — la app depende de datos frescos de
// Supabase/precios, no queremos servir HTML viejo. El SW solo existe para
// que Chrome ofrezca "Instalar Rinde.Agro" en el celular.
//
// Si en el futuro querés cache offline, agregá aquí la lógica de cache.match
// / caches.open.

self.addEventListener('install', function(event) {
  // Activarse inmediatamente sin esperar a que se cierren las tabs viejas
  self.skipWaiting()
})

self.addEventListener('activate', function(event) {
  // Tomar control de las tabs abiertas sin esperar un reload
  event.waitUntil(self.clients.claim())
})

self.addEventListener('fetch', function(event) {
  // Estrategia: dejar pasar todo directo a network (default browser behavior).
  // No interceptar nada — la app siempre habla con Supabase directo.
  // Este listener existe SOLO para que Chrome detecte el SW y habilite el
  // prompt de instalación PWA.
})
