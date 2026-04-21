## Why

OpenSpec workflows currently rely on a single general-purpose agent flow, which limits specialization and makes quality/cost control inconsistent. We need an OpenCode-native agentic workflow where each critical OpenSpec phase is executed by specialized agents with explicit model routing that balances capability and budget.

## What Changes

- Add an OpenCode-native orchestration workflow for OpenSpec phases: `explore`, `propose`, `apply`, and `archive`.
- Add specialized `apply` subagents: `implementer`, `test-fixer`, `code-reviewer`, plus optional support roles (for example docs/refactor) under orchestrator control.
- Add automatic phase transitions between critical phases, with escalation to human only for blocked work or high-impact decisions.
- Add a model-routing policy for OpenRouter that uses capability tiers, fallback rules, retry budgets, and escalation triggers.
- Add budget guardrails: per-task attempt limits, per-phase time limits, tier promotion/demotion rules, and fail-safe behavior when budget thresholds are reached.
- Add workflow validation requirements to test end-to-end execution after implementation, including success, retry, and escalation paths.

## Capabilities

### New Capabilities
- `opencode-openspec-agent-orchestration`: Defines OpenCode agent roles, ownership boundaries, and orchestration behavior across OpenSpec phases.
- `opencode-openrouter-model-routing`: Defines tiered model selection, fallback policy, and budget-governed routing logic for OpenRouter.
- `opencode-openspec-workflow-validation`: Defines end-to-end and failure-path tests that validate autonomous transitions and escalation behavior.

### Modified Capabilities
- None.

## Impact

- Affected areas: `.opencode/command/*`, OpenCode agent definitions/configuration (for example `opencode.json` and/or `.opencode/agents/*`), and OpenSpec workflow documentation.
- External dependency: OpenRouter provider and `OPENROUTER_API_KEY` from `.envrc`.
- Operational impact: adds measurable control over quality/cost tradeoffs and reduces manual phase coordination.
- Security impact: requires secret-handling rules to keep API keys out of version control and logs.
