## 1. OpenCode Agent Foundation

- [x] 1.1 Define phase orchestrator agents for `explore`, `propose`, `apply`, and `archive` in OpenCode configuration.
- [x] 1.2 Bind each `/opsx-*` command to its phase orchestrator and verify command-to-agent resolution.
- [x] 1.3 Configure agent permissions so only orchestrators can spawn approved subagents.

## 2. Apply Subagent Swarm

- [x] 2.1 Implement `implementer` subagent contract and delegation hook from `apply` orchestrator.
- [x] 2.2 Implement `test-fixer` subagent contract and failing-test handoff loop.
- [x] 2.3 Implement `code-reviewer` subagent contract and completion gate before task closure.
- [x] 2.4 Add optional support-role integration pattern (for example docs/refactor) without breaking core flow.

## 3. OpenRouter Routing and Budget Controls

- [x] 3.1 Add tiered model policy (low-cost, balanced, premium) with explicit model allowlist and fallback order.
- [x] 3.2 Implement routing promotion/demotion logic based on retries, complexity, and risk tags.
- [x] 3.3 Implement guardrails for max task attempts, max phase runtime, and budget-threshold circuit breaker behavior.
- [x] 3.4 Add enforcement logs/telemetry for routing decisions and policy violations.

## 4. Transition and Escalation Engine

- [x] 4.1 Implement automatic phase progression when exit criteria are met and no escalation condition is active.
- [x] 4.2 Implement escalation detection for retry exhaustion, time exhaustion, and unresolved reviewer conflict.
- [x] 4.3 Implement critical-decision escalation path for security, data-integrity, compliance, and irreversible architecture flags.
- [x] 4.4 Implement structured escalation packet output (attempts, blockers, options, recommendation, decision requested).

## 5. Workflow Validation (Required)

- [x] 5.1 Add happy-path end-to-end test covering automatic `explore -> propose -> apply -> archive` transition behavior.
- [x] 5.2 Add retry-path test proving transient apply failures recover automatically within policy limits.
- [x] 5.3 Add blocked-task escalation test proving automation pauses and emits escalation packet after thresholds are exceeded.
- [x] 5.4 Add critical-decision escalation test proving automation pauses and requests explicit human decision.
- [x] 5.5 Add budget-threshold test proving premium-tier restriction/circuit-breaker behavior near budget floor.
- [x] 5.6 Run full test suite and capture pass/fail evidence for all required paths.

## 6. Documentation and Rollout

- [x] 6.1 Document agent roles, ownership boundaries, and escalation criteria for contributors.
- [x] 6.2 Document model tier policy, fallback behavior, and budget tuning knobs.
- [x] 6.3 Add secure setup notes for `.envrc`-based `OPENROUTER_API_KEY` usage and non-commit guidance.
- [x] 6.4 Execute a controlled dry run on a sample change and record findings/tuning actions.
