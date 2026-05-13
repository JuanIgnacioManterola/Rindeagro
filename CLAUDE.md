# Rinde.Agro

App para gestión agropecuaria. Frontend single-file HTML + backend FastAPI + Supabase.

## Stack

- **Frontend:** `index.html` (~572KB, single-file) publicado en GitHub Pages → https://juanignaciomanterola.github.io/Rindeagro/
- **Backend:** FastAPI en `/Users/juanignaciomanterola/rindeagro-server/main.py`, deployado en Railway
- **DB/Auth:** Supabase JS v2 en frontend + Supabase REST API desde el server
- **Repo frontend:** https://github.com/JuanIgnacioManterola/Rindeagro

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
- `_renderAccesosColaborador` usa `.select('*')`, no `.select('*, owner:owner_id(id)')` — el join devolvía 400.

## Pendientes (roadmap corto)

- [ ] **Dominio `rindeagro.lat`** — verificar estado en el registrador, renovar o reconfigurar DNS. Bloqueante para links públicos.
- [ ] **Open Graph meta tags + imagen `assets/og-image.jpg`** — para previews al compartir links en WhatsApp/Twitter/etc.
- [ ] **Migrar FKs de Supabase a `ON DELETE CASCADE`** — actualmente `gastos`, `lluvias`, `analisis_suelo`, `campanas`, `eventos`, `mensajes_wa` son `NO ACTION`. Esto facilita borrar usuarios limpiamente sin transacciones manuales.
- [ ] **Habilitar RLS en tabla `precios_pizarra`** — security advisor lo marca como crítico.
- [ ] **Verificación de WhatsApp con código de 6 dígitos** — hoy es vinculación directa. A futuro: bot manda código, usuario lo ingresa en la web, recién ahí se vincula.
- [ ] **Panel de notificaciones por WhatsApp en "Mi Plan"** — toggles para resumen semanal, alertas de precio, recordatorios de operarios y admins.
- [ ] **Cuando vuelva `rindeagro.lat`**, revertir el workaround del hardcode del github.io en los links de invitación.

## Cosas en curso

- Bot de WhatsApp (Twilio Sandbox, ya recibe mensajes y reconoce números vinculados, falta terminar los flujos de carga de gastos/lluvias y los recordatorios programados con APScheduler).
- Integración de Mercado Pago para suscripciones (planes Semilla, Lote, Agrónomo, Corporativo en ARS atadas al dólar BNA).
