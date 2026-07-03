-- ═══════════════════════════════════════════════════════════════════════════
-- Migración: agregar `momento_pulverizacion` a gastos
-- ═══════════════════════════════════════════════════════════════════════════
-- Motivación: la nueva tab "Cultivo" en la vista del campo arma una timeline
-- con siembra, cosecha, fertilización y pulverizaciones. Para etiquetar bien
-- cada pulverización (herbicida/fungicida/insecticida) necesitamos saber el
-- MOMENTO agronómico:
--   - barbecho     → antes de sembrar, quemar rastrojo/malezas
--   - presiembra   → cerca de la siembra
--   - postemergente→ después de la emergencia del cultivo
--   - aplicacion   → aplicación genérica sin momento específico (default)
--
-- Es opcional. Si es null, en la timeline el evento se muestra como
-- "Pulverización" sin sub-etiqueta.
--
-- Solo tiene sentido para rubros `herbicidas`, `fungicidas`, `insecticidas`.
-- El frontend no lo escribe para el resto.
-- ═══════════════════════════════════════════════════════════════════════════

alter table public.gastos
  add column if not exists momento_pulverizacion text
    check (momento_pulverizacion in ('barbecho','presiembra','postemergente','aplicacion') or momento_pulverizacion is null);

comment on column public.gastos.momento_pulverizacion is
  'Momento agronómico de una pulverización. Solo se setea para rubros herbicidas/fungicidas/insecticidas. Alimenta la timeline del cultivo.';
