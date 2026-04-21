# Reusable Prompt: Replicate This OpenCode + OpenSpec Agentic Setup In A Scala Repository

Use this prompt in another repository that already uses OpenCode and OpenSpec.

## Prompt

You are setting up an OpenCode-native OpenSpec workflow in a Scala project.

Follow these instructions exactly.

### Important Existing Conditions (Already True In Target Repo)

Assume all of the following are already present and must be respected:

1. `AGENTS.md` exists and defines project-specific engineering rules.
2. OpenSpec commands and skills are already installed and wired in the project.
3. The project already has established Scala conventions, build tooling, and architecture docs.

Do not re-bootstrap OpenSpec or overwrite existing command/skill behavior unless explicitly required by this task.

### Objective

Implement the same agentic architecture and control model as this reference design, adapted for Scala:

1. OpenSpec critical phases use dedicated orchestrators:
- explore
- propose
- apply
- archive

2. Apply phase uses specialized subagents:
- implementer
- test-fixer
- code-reviewer
- docs-refactor (optional support role)

3. Phase transitions are automatic by default.

4. Escalation to human happens only when:
- retry budget is exhausted,
- phase time budget is exhausted,
- unresolved review conflicts exist,
- critical decision category is detected (`security`, `data_integrity`, `compliance`, `irreversible_architecture`).

5. Model routing balances skill and budget with three tiers:
- low
- balanced
- premium

6. Budget guardrails prevent runaway premium spend.

### Mandatory First Steps (Context Ingestion)

Before writing files, read and synthesize project context from:

1. `AGENTS.md` (highest-priority behavioral constraints)
2. Existing OpenSpec command/skill files under `.opencode/skills` and `.opencode/commands` (or equivalent existing locations)
3. Scala project docs and conventions (for example in `README.md`, `docs/`, architecture records)
4. Build/test configuration (for example `build.sbt`, `project/*.scala`, module structure)

Produce a short internal mapping of constraints:
- Scala version and language features in use
- Build tool and test commands
- Code style and lint/format expectations
- Module boundaries
- Naming conventions
- Forbidden patterns and risk-sensitive areas

### Scala-Specific Adaptation Requirements

The resulting agent/subagent setup MUST be enriched for Scala delivery, not generic coding.

At minimum:

1. `implementer` prompt must include:
- idiomatic Scala expectations for the repo
- package/import conventions
- immutability and error-handling preferences used by the project
- module ownership boundaries

2. `test-fixer` prompt must include:
- project test stack (for example ScalaTest/MUnit/specs2)
- deterministic test repair policy
- minimal patching rule (avoid broad refactors)
- required test command(s) and module scoping approach

3. `code-reviewer` prompt must include:
- Scala-specific defect checklist (null safety, effect handling, concurrency assumptions, binary/source compatibility if relevant)
- regression and performance risk checks aligned with project architecture
- dependency and API surface change scrutiny

4. `docs-refactor` prompt must include:
- Scala docs/style expectations
- restriction against behavior-changing refactors unless explicitly delegated

5. Orchestrators must reference project docs and `AGENTS.md` as required context for every decision.

### Required Output Files

Create or update these files (adapting to existing repo structure without duplicate sources of truth):

1. `opencode.json`
- Configure `provider.openrouter.options.apiKey` as `{env:OPENROUTER_API_KEY}`.
- Add/adjust model catalog entries for tiered routing defaults.
- Keep this file focused on provider/model catalog.

2. `.opencode/agents/*.md`
Create or update:
- `opsx-explore-orchestrator.md`
- `opsx-propose-orchestrator.md`
- `opsx-apply-orchestrator.md`
- `opsx-archive-orchestrator.md`
- `opsx-implementer.md`
- `opsx-test-fixer.md`
- `opsx-code-reviewer.md`
- `opsx-docs-refactor.md`

Agent requirements:
- Orchestrators use `mode: primary`.
- Worker agents use `mode: subagent` and `hidden: true`.
- `opsx-apply-orchestrator` includes `permission.task` default deny + explicit allowlist for apply workers.
- Prompts explicitly include Scala/project context from `AGENTS.md` and project docs.

3. `.opencode/commands/*.md`
Ensure command files exist and map to orchestrators:
- `opsx-explore.md`
- `opsx-propose.md`
- `opsx-apply.md`
- `opsx-archive.md`

Command requirements:
- each command has `agent: <corresponding-orchestrator>`
- each command sets `subtask: true`
- preserve existing OpenSpec semantics in the project

4. Policy implementation
- `workflow/policy.js` for escalation/routing constants
- `workflow/engine.js` for routing selection, escalation classification, escalation packet generation, and simulation helper

5. Validation tests
- tests for workflow policy behavior
- tests for command/agent wiring and permissions
- tests adapted to the repository's test execution strategy

If the repo is Scala-only and already has a preferred test framework, place policy/config tests where they best fit the project conventions (Node harness is acceptable only if already adopted for ops tooling).

6. Documentation
Update or create docs that explain:
- architecture and phase flow
- Scala-specific agent enrichment decisions
- routing and budget tuning knobs
- escalation contract
- local validation runbook

### Implementation Constraints

- Respect `AGENTS.md` rules as non-negotiable constraints.
- Do not remove existing OpenSpec command/skill setup unless replacing with an equivalent canonical location.
- Use one canonical command directory and one canonical agent definition style.
- Avoid duplicate sources of truth for command bindings.
- Keep secrets out of tracked files.
- Ensure `.envrc` is ignored by git.

### Acceptance Criteria

All criteria must pass before completion:

1. Existing OpenSpec commands/skills remain functional after changes.
2. New orchestrator/subagent setup is present and wired.
3. Agent prompts include Scala/project-specific requirements derived from `AGENTS.md` and docs.
4. Apply orchestrator task permissions are default-deny + explicit allowlist.
5. Validation suite passes.
6. Dry-run/simulation demonstrates:
- happy path completed
- retry recovery completed
- blocked path escalated
- critical decision escalated
- budget-floor behavior enforced
7. Documentation clearly explains how Scala-specific constraints were incorporated.

### Final Output Requirements

At the end, provide:

1. Summary of changes grouped by file area.
2. Evidence of validation (commands run and results).
3. Explicit list of project-specific Scala rules pulled from `AGENTS.md`/docs and where each was applied in agent prompts.
4. Follow-up recommendations (for example model ID tuning via `/models`, Scala test target refinement, stricter escalation thresholds).

### Optional Enhancements

- Add CI checks that validate command/agent wiring and policy tests.
- Add a compatibility checklist for multi-module Scala repos.
- Add curated escalation examples based on common Scala failure modes.

