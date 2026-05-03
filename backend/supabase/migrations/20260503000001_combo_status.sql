-- ============================================================
-- NAKORA — Migration : Colonne status pour combo_predictions
-- Sans cette colonne, les combinés ne peuvent jamais être évalués
-- (won / lost / partial) et le winrate reste toujours à zéro.
-- ============================================================

ALTER TABLE public.combo_predictions
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'won', 'partial', 'lost', 'void')),
  ADD COLUMN IF NOT EXISTS result_detail JSONB;

COMMENT ON COLUMN public.combo_predictions.status IS
  'Combo evaluation status: active (in progress), won (all legs correct), partial (some correct), lost (at least one incorrect), void (cancelled)';
COMMENT ON COLUMN public.combo_predictions.result_detail IS
  'Per-leg evaluation results: [{ prediction_id, is_correct }]';
