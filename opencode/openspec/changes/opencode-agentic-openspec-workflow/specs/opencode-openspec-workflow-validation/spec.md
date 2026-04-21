## ADDED Requirements

### Requirement: End-to-End Workflow Validation
The change MUST include automated validation that exercises the complete OpenSpec workflow from phase entry through completion.

#### Scenario: Happy-path end-to-end workflow
- **WHEN** the workflow is executed with valid configuration and no blockers
- **THEN** all critical phases complete automatically and the run is marked successful

### Requirement: Retry-Path Validation
The validation suite SHALL verify behavior when transient failures occur during apply execution.

#### Scenario: Recover from transient failure
- **WHEN** apply execution encounters a transient implementation or test failure
- **THEN** the workflow retries according to policy and completes without human escalation if limits are not exceeded

### Requirement: Escalation-Path Validation
The validation suite SHALL verify escalation behavior for blocked and high-impact paths.

#### Scenario: Escalation packet on blocked task
- **WHEN** a task remains unresolved after retry and time thresholds
- **THEN** the system emits an escalation packet containing attempts, blockers, options, and recommendation

#### Scenario: Escalation packet on critical decision
- **WHEN** an execution step is tagged as high-impact decision risk
- **THEN** automation pauses and requests explicit human decision

### Requirement: Budget-Threshold Validation
The validation suite SHALL verify model-routing behavior when budget thresholds are approached.

#### Scenario: Circuit-breaker near budget floor
- **WHEN** remaining budget drops below the configured floor threshold
- **THEN** premium tier routing is disabled except for explicitly allowed critical cases

#### Scenario: Budget policy violation rejection
- **WHEN** an execution path attempts to bypass guardrails
- **THEN** the system rejects the action and records policy enforcement evidence
