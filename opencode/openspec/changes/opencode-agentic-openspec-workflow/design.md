## Context

The repository already contains OpenSpec command wrappers (`/opsx-propose`, `/opsx-explore`, `/opsx-apply`, `/opsx-archive`) but does not yet define a dedicated agentic execution model in OpenCode. Current operation is effectively single-agent and manual for critical coordination points.

The target state is an OpenCode-native workflow where each critical OpenSpec phase is owned by a specialized agent and `apply` can delegate to focused subagents (implementer, test-fixer, code-reviewer). Model selection must run through OpenRouter and enforce cost-control policies so quality improves without uncontrolled spend.

Constraints:
- The workflow must be compatible with existing OpenSpec schema-driven artifacts.
- Transitions should be autonomous by default.
- Human intervention should only happen for blocked execution or high-impact decisions.
- Secrets are supplied via `.envrc` and must not leak into tracked files or logs.

Stakeholders:
- Primary: engineers using OpenCode for OpenSpec-driven delivery.
- Secondary: maintainers responsible for model spend and reliability.

## Goals / Non-Goals

**Goals:**
- Introduce explicit OpenCode agents for each phase (`explore`, `propose`, `apply`, `archive`).
- Introduce an `apply` subagent swarm with clear ownership boundaries.
- Enforce automatic phase transition rules with deterministic escalation conditions.
- Implement model routing based on capability tiers and budget constraints.
- Add workflow tests that validate success paths, retry loops, and escalation paths.

**Non-Goals:**
- Building a generic orchestration system outside OpenCode/OpenSpec.
- Replacing OpenSpec schemas or artifact semantics.
- Achieving fully autonomous handling of product/legal/compliance decisions.
- Optimizing for absolute lowest latency at the expense of quality and control.

## Decisions

### Decision 1: Orchestrator-per-phase architecture in OpenCode
Use one primary orchestrator agent for each OpenSpec phase (`opsx-explore`, `opsx-propose`, `opsx-apply`, `opsx-archive`) mapped in OpenCode command configuration.

Rationale:
- Keeps behavior aligned with existing command boundaries.
- Simplifies observability and debugging per phase.
- Avoids implicit responsibility overlap.

Alternative considered:
- Single global orchestrator for all phases. Rejected due to higher prompt complexity, weaker separation of concerns, and harder failure isolation.

### Decision 2: Multi-agent apply swarm with explicit role contracts
The `apply` orchestrator delegates work to subagents with role-specific responsibilities:
- `implementer`: code and task implementation
- `test-fixer`: diagnose failing tests and produce minimal corrective patches
- `code-reviewer`: review generated changes for defects/regressions/risk
- optional `docs-refactor`: documentation and low-risk cleanup tasks

Rationale:
- Strong task decomposition improves accuracy and reduces iteration waste.
- Enables targeted model selection per subtask type.

Alternative considered:
- Two-role setup (`implementer` + `reviewer`) only. Rejected because test remediation often needs dedicated loop isolation and budget caps.

### Decision 3: Automatic transitions with escalation gates
Phase progression is automatic unless blocked by policy conditions. Escalation is mandatory when one or more conditions are met:
- retry budget exhausted for a task
- time budget exhausted for a task/phase
- unresolved conflicting reviewer outcomes
- high-impact decision category detected (security, data integrity, compliance, irreversible architecture)

Rationale:
- Maximizes flow while preserving control for high-risk work.

Alternative considered:
- Manual approval at each phase boundary. Rejected as too slow and operationally expensive.

### Decision 4: Tiered OpenRouter model routing for cost-quality balance
Define routing tiers:
- Tier 1 (low-cost): triage, classification, lightweight checks
- Tier 2 (balanced): default implementation and standard review
- Tier 3 (premium): critical review, hard blockers, final tie-break decisions

Routing policy:
- Start tasks at Tier 2 by default for coding work.
- Route simple deterministic tasks to Tier 1.
- Promote to Tier 3 only after objective triggers (retries/risk tags).
- Demote back to lower tiers on task class changes.

Rationale:
- Controls spend while preserving quality where it matters.

Alternative considered:
- Single premium model for all steps. Rejected due to unacceptable cost profile.

### Decision 5: Budget and reliability guardrails are first-class policy
Budget controls are enforced in orchestration policy:
- max attempts per task
- max wall-clock duration per task
- per-session/token/cost budget thresholds
- model allowlist and fallback order
- circuit-breaker behavior near budget floor

Rationale:
- Prevents runaway autonomous loops and cost spikes.

Alternative considered:
- Soft budget monitoring only. Rejected because it detects overruns too late.

### Decision 6: Validation-first completion criteria
The workflow is not considered complete until tests cover:
- happy path (all automatic transitions)
- retry path (failing task recovered automatically)
- escalation path (human handoff packet emitted)
- budget-threshold path (tier restriction/circuit-breaker behavior)

Rationale:
- Ensures autonomy claims are verified, not inferred.

## Risks / Trade-offs

- [Over-orchestration complexity] -> Mitigation: keep role contracts minimal and document ownership boundaries per agent.
- [Budget guardrails too strict causing false escalations] -> Mitigation: calibrate thresholds via test scenarios and iterative tuning.
- [Model behavior variance across providers] -> Mitigation: pin provider/model allowlists and define deterministic fallback order.
- [Escalation storms on ambiguous tasks] -> Mitigation: improve task classification and add richer escalation packet context.
- [Secret exposure in logs/config] -> Mitigation: keep keys only in `.envrc`, redact logs, rotate keys upon exposure.

## Migration Plan

1. Define/update OpenCode agent configuration and command-to-agent mapping.
2. Introduce apply subagents with explicit permissions and ownership.
3. Add OpenRouter model tier mapping and fallback policy.
4. Add transition and escalation policy engine hooks.
5. Add workflow-level automated tests and fixtures.
6. Validate end-to-end in a controlled dry-run and then real change execution.
7. Tune thresholds from observed runtime/cost telemetry.

Rollback:
- Revert to current single-agent command execution by disabling subagent delegation and tier routing.
- Keep existing OpenSpec commands operational with conservative defaults.

## Open Questions

- Which exact model IDs should be used for Tier 1/2/3 in this repo’s default profile?
- Should budget limits be global per session, per phase, or both?
- Should escalation require a single human confirmation step before returning to automation?
