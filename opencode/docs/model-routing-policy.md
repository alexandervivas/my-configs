# Model Routing and Budget Policy

## Goal

Provide predictable model selection that balances capability and cost while minimizing uncontrolled escalation and spend spikes.

## Policy Surface

Routing and escalation policy constants are defined in `workflow/policy.js`.
Execution behavior is implemented in `workflow/engine.js`.

## Tier Definitions

- `low`: low-cost deterministic tasks (triage, small docs checks).
- `balanced`: default for coding, testing, and standard review.
- `premium`: difficult/high-risk tasks and tie-break decisions.

## Routing Inputs

The router uses:

- `taskType`
- `complexity`
- `retryCount`
- `remainingBudgetRatio`
- `criticalDecisionCategory`
- `attemptedModels`
- `requestedModel` (optional explicit override)

## Core Rules

1. Determine base tier from `defaultTierByTaskType`.
2. If `complexity=low` and first attempt, demote one tier.
3. If retries hit `promotionRetries`, promote one tier.
4. Use `fallbackByTier` ordering for deterministic fallback.
5. If `requestedModel` is not in allowlist, reject with `model_not_allowlisted`.
6. If `remainingBudgetRatio < budgetFloorRatio`, disable premium except configured critical exceptions.

## Budget and Safety Guardrails

- `maxAttemptsPerTask`
- `maxPhaseMinutes`
- `budgetFloorRatio`
- `allowPremiumUnderBudgetFloorFor`

These collectively prevent runaway loops and uncontrolled premium usage.

## Practical Tuning Playbook

If quality is too low:

1. Increase `promotionRetries` aggressiveness only slightly.
2. Improve fallback ordering inside each tier.
3. Add targeted premium exception categories if justified.

If spend is too high:

1. Raise `budgetFloorRatio`.
2. Restrict premium exception categories.
3. Move more task types to `low` or `balanced` defaults.
4. Reduce max attempts where convergence is unlikely.

If escalations are too frequent:

1. Increase attempt/time thresholds modestly.
2. Improve task decomposition in apply flow.
3. Reduce reviewer conflict triggers where false positives occur.

## Validation Matrix

The policy is validated via tests:

- Happy path auto progression
- Retry recovery
- Retry-exhausted escalation
- Critical-decision escalation
- Budget-floor premium restriction
- Allowlist rejection

Run:

```bash
npm test
npm run dry-run
```

## Configuration Locations

- `opencode.json`: provider + model catalog
- `.opencode/agents/*.md`: agent/subagent model selections
- `.opencode/commands/*.md`: command invocation behavior
- `workflow/policy.js`: policy constants
- `workflow/engine.js`: policy mechanics
