import fs from "node:fs";
import path from "node:path";
import { WorkflowEngine } from "../workflow/engine.js";

const engine = new WorkflowEngine();
const startedAt = new Date().toISOString();

const scenarios = {
  happyPath: engine.runWorkflowSimulation({
    phases: {
      apply: {
        tasks: [{ id: "2.1", outcomes: ["success"], taskType: "coding" }]
      }
    }
  }),
  retryRecovery: engine.runWorkflowSimulation({
    phases: {
      apply: {
        tasks: [{ id: "2.2", outcomes: ["fail", "success"], taskType: "testing" }]
      }
    }
  }),
  blockedEscalation: engine.runWorkflowSimulation({
    phases: {
      apply: {
        tasks: [{ id: "2.3", outcomes: ["fail", "fail", "fail"], taskType: "coding" }]
      }
    }
  }),
  criticalEscalation: engine.runWorkflowSimulation({
    phases: {
      apply: {
        criticalDecisionCategory: "security"
      }
    }
  }),
  budgetFloor: engine.routeModel({
    taskType: "critical_review",
    retryCount: 3,
    remainingBudgetRatio: 0.1,
    criticalDecisionCategory: null
  })
};

const output = {
  startedAt,
  finishedAt: new Date().toISOString(),
  scenarios
};

const outputFile = path.join("artifacts", "workflow-dry-run.json");
fs.writeFileSync(outputFile, JSON.stringify(output, null, 2));

console.log(`Wrote dry-run report to ${outputFile}`);
console.log(`happyPath status: ${scenarios.happyPath.status}`);
console.log(`retryRecovery status: ${scenarios.retryRecovery.status}`);
console.log(`blockedEscalation status: ${scenarios.blockedEscalation.status}`);
console.log(`criticalEscalation status: ${scenarios.criticalEscalation.status}`);
console.log(`budgetFloor selectedTier: ${scenarios.budgetFloor.selectedTier}`);
