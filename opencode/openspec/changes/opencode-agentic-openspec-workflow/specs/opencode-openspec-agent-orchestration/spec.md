## ADDED Requirements

### Requirement: Phase-Orchestrator Assignment
The workflow SHALL assign a dedicated OpenCode orchestrator agent to each OpenSpec critical phase (`explore`, `propose`, `apply`, `archive`) and execute that phase under the assigned orchestrator.

#### Scenario: Execute phase with assigned orchestrator
- **WHEN** a user invokes a phase command
- **THEN** the system runs the phase with the configured orchestrator agent for that phase

#### Scenario: Missing orchestrator configuration
- **WHEN** a phase command is invoked but no orchestrator is configured
- **THEN** the system MUST fail fast with a configuration error that identifies the missing phase mapping

### Requirement: Apply Subagent Role Contracts
The `apply` phase SHALL support role-specific subagents at minimum for `implementer`, `test-fixer`, and `code-reviewer`, with explicit role boundaries.

#### Scenario: Delegate implementation to implementer
- **WHEN** an apply task requires code changes
- **THEN** the orchestrator delegates the implementation step to the `implementer` subagent

#### Scenario: Delegate failing tests to test-fixer
- **WHEN** tests fail during apply execution
- **THEN** the orchestrator delegates test remediation to the `test-fixer` subagent

#### Scenario: Delegate review to code-reviewer
- **WHEN** a patch candidate is ready for validation
- **THEN** the orchestrator delegates review to the `code-reviewer` subagent before marking the task complete

### Requirement: Automatic Phase Transition
The workflow SHALL transition between phases automatically after successful completion of the current phase.

#### Scenario: Automatic progression to next phase
- **WHEN** the current phase completes and no escalation condition is active
- **THEN** the system advances to the next configured phase without human intervention

### Requirement: Escalation Conditions
The workflow MUST escalate to human decision-making when blocked or high-impact conditions are detected.

#### Scenario: Escalate on retry exhaustion
- **WHEN** task retries exceed configured limits
- **THEN** the system pauses automation and emits a human escalation packet

#### Scenario: Escalate on critical decision classification
- **WHEN** a decision is classified as security, data-integrity, compliance, or irreversible architecture risk
- **THEN** the system pauses automation and requests explicit human direction
