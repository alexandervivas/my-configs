# Dry Run Findings

Date: 2026-04-20

## Results

- Happy path: completed
- Retry recovery path: completed
- Blocked-task path: escalated as expected (`retry_exhausted`)
- Critical-decision path: escalated as expected (`critical_decision`)
- Budget-floor path: premium disabled for non-critical work (`selectedTier: balanced`)

## Tuning Actions

- Keep `maxAttemptsPerTask=3` as baseline.
- Keep `budgetFloorRatio=0.15` to protect premium spend.
- Allow premium exceptions only for `security` and `data_integrity` categories.
- Revisit tier model IDs after selecting available OpenRouter models in `/models`.
