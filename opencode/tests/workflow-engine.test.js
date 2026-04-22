import test from "node:test";
import assert from "node:assert/strict";
import { WorkflowEngine } from "../workflow/engine.js";

test("happy path transitions all phases automatically", () => {
  const engine = new WorkflowEngine();
  const result = engine.runWorkflowSimulation({
    phases: {
      apply: {
        tasks: [{ id: "2.1", outcomes: ["success"], taskType: "coding" }]
      }
    }
  });

  assert.equal(result.status, "completed");
  assert.equal(result.transitions.length, 3);
  assert.equal(result.transitions[0].from, "explore");
  assert.equal(result.transitions[2].to, "archive");
});

test("retry path recovers before escalation", () => {
  const engine = new WorkflowEngine();
  const result = engine.runWorkflowSimulation({
    phases: {
      apply: {
        tasks: [
          {
            id: "2.2",
            outcomes: ["fail", "success"],
            taskType: "testing",
            complexity: "medium"
          }
        ]
      }
    }
  });

  assert.equal(result.status, "completed");
  assert.equal(result.routingEvents.length, 2);
});

test("blocked task escalates after retry budget exhaustion", () => {
  const engine = new WorkflowEngine();
  const result = engine.runWorkflowSimulation({
    phases: {
      apply: {
        tasks: [
          {
            id: "2.3",
            outcomes: ["fail", "fail", "fail"],
            taskType: "coding",
            blockers: ["Compilation still failing"]
          }
        ]
      }
    }
  });

  assert.equal(result.status, "escalated");
  assert.equal(result.escalation.reason, "retry_exhausted");
  assert.equal(result.escalation.taskId, "2.3");
});

test("critical decision escalates immediately", () => {
  const engine = new WorkflowEngine();
  const result = engine.runWorkflowSimulation({
    phases: {
      apply: {
        criticalDecisionCategory: "security"
      }
    }
  });

  assert.equal(result.status, "escalated");
  assert.equal(result.escalation.reason, "critical_decision");
});

test("budget floor disables premium tier for non-critical work", () => {
  const engine = new WorkflowEngine();
  const route = engine.routeModel({
    taskType: "critical_review",
    retryCount: 3,
    remainingBudgetRatio: 0.1,
    criticalDecisionCategory: null
  });

  assert.equal(route.ok, true);
  assert.notEqual(route.selectedTier, "premium");
  assert.equal(route.premiumDisabledByBudget, true);
});

test("budget floor still allows premium for critical allowed categories", () => {
  const engine = new WorkflowEngine();
  const route = engine.routeModel({
    taskType: "critical_review",
    retryCount: 3,
    remainingBudgetRatio: 0.1,
    criticalDecisionCategory: "security"
  });

  assert.equal(route.ok, true);
  assert.equal(route.selectedTier, "premium");
});

test("rejects non-allowlisted model request", () => {
  const engine = new WorkflowEngine();
  const route = engine.routeModel({ requestedModel: "openrouter/nonexistent/model" });

  assert.equal(route.ok, false);
  assert.equal(route.error, "model_not_allowlisted");
});
