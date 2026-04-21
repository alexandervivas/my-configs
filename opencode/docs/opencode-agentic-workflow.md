# OpenCode Agentic OpenSpec Workflow

## Purpose

This workflow implements a practical agentic execution model for OpenSpec in OpenCode:

- Specialized orchestrator for each critical phase.
- Specialized subagents for apply work.
- Automatic transitions by default.
- Human escalation only when policy deems it necessary.
- Model selection designed to balance quality and budget.

## Architecture

### Phase Orchestrators

- `opsx-explore-orchestrator`
- `opsx-propose-orchestrator`
- `opsx-apply-orchestrator`
- `opsx-archive-orchestrator`

### Apply Subagents

- `opsx-implementer`
- `opsx-test-fixer`
- `opsx-code-reviewer`
- `opsx-docs-refactor` (optional support role)

### Command Bindings

Commands are mapped to orchestrators in `.opencode/commands/*.md`:

- `/opsx-explore` -> `opsx-explore-orchestrator`
- `/opsx-propose` -> `opsx-propose-orchestrator`
- `/opsx-apply` -> `opsx-apply-orchestrator`
- `/opsx-archive` -> `opsx-archive-orchestrator`

All are configured with `subtask: true` to keep main context cleaner.

## Configuration Layout

- Provider/model catalog: `opencode.json`
- Agent definitions: `.opencode/agents/*.md`
- Command definitions: `.opencode/commands/*.md`
- Policy defaults: `workflow/policy.js`
- Policy execution engine: `workflow/engine.js`

## Phase Flow

Nominal phase order:

1. `explore`
2. `propose`
3. `apply`
4. `archive`

Automatic transition occurs when the current phase exits successfully and no escalation condition is active.

## Apply Orchestration Model

`opsx-apply-orchestrator` delegates by role:

- Implementation work -> `opsx-implementer`
- Failing test remediation -> `opsx-test-fixer`
- Risk review gate -> `opsx-code-reviewer`
- Documentation/low-risk cleanup -> `opsx-docs-refactor`

Permission boundary:

- `opsx-apply-orchestrator` uses `permission.task` with default deny + explicit allowlist.
- Only approved apply subagents are task-invokable.

## Escalation Policy

Automation escalates when one or more conditions are met:

- Retry budget exhausted (`maxAttemptsPerTask`).
- Phase runtime exceeds `maxPhaseMinutes`.
- Review outcomes remain in unresolved conflict.
- Critical decision category detected:
  - `security`
  - `data_integrity`
  - `compliance`
  - `irreversible_architecture`

### Escalation Packet

Escalation emits a structured packet with:

- `reason`
- `phase`
- `taskId`
- `attempts`
- `elapsedMinutes`
- `blockers`
- `options`
- `recommendation`
- `decisionRequired`
- `createdAt`

## OpenRouter + Budget-Aware Routing

Model tier concept:

- `low`
- `balanced`
- `premium`

Routing behavior:

- Choose base tier by task type.
- Promote tier after configured retry threshold.
- Demote for low-complexity first-attempt work.
- Apply deterministic fallback order by tier.
- Reject non-allowlisted model requests.
- Disable premium below budget floor ratio unless critical-category exception applies.

## Validation Strategy

Automated tests verify:

- Happy path end-to-end phase transitions.
- Retry path recovery before escalation.
- Blocked-task escalation after retry/time limits.
- Critical-decision escalation.
- Budget-floor circuit-breaker behavior.
- Configuration integrity (agents, commands, permissions).

Test entry points:

```bash
npm test
npm run dry-run
```

Outputs:

- `artifacts/test-report.txt`
- `artifacts/dry-run-report.txt`
- `artifacts/workflow-dry-run.json`
- `artifacts/dry-run-findings.md`

## Runbook

### Preflight

1. Ensure `OPENROUTER_API_KEY` is loaded from `.envrc`.
2. Run `npm test`.
3. Run `npm run dry-run`.
4. Verify OpenCode resolved config:

```bash
opencode debug config | rg "opsx-|openrouter"
```

### Execute a Change

1. Explore scope: `/opsx-explore <topic>`
2. Generate artifacts: `/opsx-propose <name-or-description>`
3. Implement tasks: `/opsx-apply <change-name>`
4. Archive when complete: `/opsx-archive <change-name>`

### Confirm Completion

```bash
openspec instructions apply --change "<change-name>" --json
```

Expected completion state:

- `progress.remaining = 0`
- `state = "all_done"`

## Troubleshooting

### Commands not using expected orchestrator

- Check `.opencode/commands/*.md` frontmatter `agent` field.
- Run `opencode debug config` and inspect resolved command map.

### Agent missing or not invokable

- Confirm corresponding `.opencode/agents/<name>.md` exists.
- For apply workers, verify `permission.task` allowlist on `opsx-apply-orchestrator`.

### Premium usage is too high

- Raise strictness of `budgetFloorRatio`.
- Increase promotion threshold.
- Reduce premium defaults in model tier map.

### Too many escalations

- Rebalance retry/time thresholds.
- Improve task decomposition in apply flow.
- Tighten review conflict resolution strategy.

## Extension Guidance

If you add new subagents:

1. Create `.opencode/agents/<name>.md`.
2. Add explicit allow rule in apply orchestrator `permission.task` if needed.
3. Document role in this file.
4. Add coverage in tests and dry-run scenarios.

If you add new critical decision categories:

1. Update `workflow/policy.js`.
2. Add corresponding tests in `tests/workflow-engine.test.js`.
3. Document expected escalation packet content.
