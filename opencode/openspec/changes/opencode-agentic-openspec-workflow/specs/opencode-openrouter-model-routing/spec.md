## ADDED Requirements

### Requirement: Tiered Model Policy
The workflow SHALL implement at least three model tiers for OpenRouter routing: low-cost, balanced, and premium.

#### Scenario: Select balanced tier for default coding task
- **WHEN** an apply coding task begins without elevated risk flags
- **THEN** the router selects a model from the balanced tier

#### Scenario: Select low-cost tier for lightweight task
- **WHEN** a task is classified as deterministic triage or lightweight analysis
- **THEN** the router selects a model from the low-cost tier

### Requirement: Promotion and Demotion Rules
The workflow MUST promote or demote model tier based on configured retry, complexity, and risk signals.

#### Scenario: Promote after repeated failures
- **WHEN** a task reaches the promotion retry threshold
- **THEN** the router upgrades the next attempt to a higher tier model

#### Scenario: Demote after complexity drop
- **WHEN** work moves from high-complexity to lightweight validation
- **THEN** the router may select a lower-cost tier according to policy

### Requirement: Budget Guardrails
The workflow MUST enforce budget and execution guardrails, including attempt limits and time limits.

#### Scenario: Stop on task attempt limit
- **WHEN** the task attempt limit is reached
- **THEN** the workflow stops autonomous retries and escalates

#### Scenario: Stop on phase time limit
- **WHEN** phase runtime exceeds configured time budget
- **THEN** the workflow pauses and emits escalation details

### Requirement: Fallback and Allowlist Controls
The workflow SHALL route only to provider/model combinations allowed by explicit configuration and apply deterministic fallback ordering.

#### Scenario: Primary model unavailable
- **WHEN** the selected primary model fails or is unavailable
- **THEN** the router retries with the next configured fallback model in order

#### Scenario: Non-allowlisted model requested
- **WHEN** routing logic requests a model outside the allowlist
- **THEN** the request MUST be rejected and logged as policy violation
