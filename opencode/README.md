# OpenCode Agentic OpenSpec Workflow

This repository contains a complete, OpenCode-native workflow for running OpenSpec with specialized agents per phase and budget-aware model routing via OpenRouter.

## What This Gives You

- Dedicated orchestrators for OpenSpec phases: `explore`, `propose`, `apply`, `archive`
- Specialized apply subagents: `implementer`, `test-fixer`, `code-reviewer`, `docs-refactor`
- Automatic phase progression with deterministic escalation gates
- Tiered model routing (`low`, `balanced`, `premium`) with budget guardrails
- Local validation harness for happy path, retry path, escalation path, and budget-floor behavior

## How It Works

The workflow is split across a few clear locations:

- `opencode.json`: provider + model catalog config (OpenRouter + env key wiring)
- `.opencode/agents/*.md`: agent and subagent definitions
- `.opencode/commands/*.md`: command-to-orchestrator bindings
- `workflow/policy.js`: routing/escalation policy values
- `workflow/engine.js`: policy execution logic (simulation + escalation packet)
- `tests/*.test.js`: workflow and config validation tests

Detailed docs:
- `docs/opencode-agentic-workflow.md`
- `docs/model-routing-policy.md`
- `docs/security-setup.md`
- `docs/reusable-bootstrap-prompt.md`

## Quick Start

1. Set your OpenRouter key in `.envrc`:

```bash
export OPENROUTER_API_KEY='sk-or-...'
```

2. Load environment:

```bash
direnv allow
```

3. Validate configuration and policy behavior:

```bash
npm test
npm run dry-run
```

4. Launch OpenCode and run the workflow:

```bash
opencode
```

Then in TUI:
- `/models` (select your preferred OpenRouter models)
- `/opsx-explore <topic>`
- `/opsx-propose <change-name-or-description>`
- `/opsx-apply <change-name>`
- `/opsx-archive <change-name>`

## Self-Test Checklist

Use this checklist to verify everything end-to-end in your own environment:

1. `npm test` passes all tests.
2. `npm run dry-run` creates `artifacts/workflow-dry-run.json`.
3. `opencode debug config` shows:
   - `opsx-*` command bindings
   - `opsx-*` orchestrators and subagents
   - `openrouter` provider config
4. `openspec instructions apply --change <name> --json` reports progress and state correctly.
5. Escalation packet appears when retries/time limits are exceeded in controlled test scenarios.

## Security Notes

- Keep `.envrc` untracked.
- Keep API keys out of committed files.
- Rotate keys if they were ever exposed.
- Keep premium-tier usage controlled with budget thresholds.

## Reuse In Another Repo

Use the ready-to-copy bootstrap prompt in:

- `docs/reusable-bootstrap-prompt.md`

It includes assumptions, required files, validation criteria, and acceptance checks.
