import {
  DEFAULT_POLICY,
  allAllowlistedModels,
  isCriticalDecision
} from "./policy.js";

function promoteTier(tier) {
  if (tier === "low") return "balanced";
  if (tier === "balanced") return "premium";
  return "premium";
}

function demoteTier(tier) {
  if (tier === "premium") return "balanced";
  if (tier === "balanced") return "low";
  return "low";
}

export class WorkflowEngine {
  constructor(policy = DEFAULT_POLICY) {
    this.policy = policy;
  }

  classifyEscalation({ attempts, elapsedMinutes, conflictingReviews, criticalDecisionCategory }) {
    if (isCriticalDecision(criticalDecisionCategory, this.policy)) {
      return "critical_decision";
    }
    if (conflictingReviews) {
      return "review_conflict";
    }
    if (attempts >= this.policy.escalation.maxAttemptsPerTask) {
      return "retry_exhausted";
    }
    if (elapsedMinutes > this.policy.escalation.maxPhaseMinutes) {
      return "time_exhausted";
    }
    return null;
  }

  createEscalationPacket({
    reason,
    phase,
    taskId,
    attempts,
    elapsedMinutes,
    blockers = [],
    options = [],
    recommendation,
    decisionRequired
  }) {
    return {
      reason,
      phase,
      taskId,
      attempts,
      elapsedMinutes,
      blockers,
      options,
      recommendation,
      decisionRequired,
      createdAt: new Date().toISOString()
    };
  }

  routeModel({
    taskType = "coding",
    complexity = "medium",
    retryCount = 0,
    remainingBudgetRatio = 1,
    criticalDecisionCategory = null,
    attemptedModels = [],
    requestedModel = null
  } = {}) {
    const policy = this.policy;
    const allowlistedModels = allAllowlistedModels(policy);

    if (requestedModel && !allowlistedModels.has(requestedModel)) {
      return {
        ok: false,
        error: "model_not_allowlisted",
        requestedModel
      };
    }

    let tier =
      policy.routing.defaultTierByTaskType[taskType] ??
      policy.routing.defaultTierByTaskType.coding;

    if (complexity === "low" && retryCount === 0) {
      tier = demoteTier(tier);
    }

    if (retryCount >= policy.routing.promotionRetries) {
      tier = promoteTier(tier);
    }

    const criticalUnderBudget =
      remainingBudgetRatio < policy.routing.budgetFloorRatio &&
      isCriticalDecision(criticalDecisionCategory, policy) &&
      policy.routing.allowPremiumUnderBudgetFloorFor.includes(criticalDecisionCategory);

    const premiumDisabledByBudget =
      remainingBudgetRatio < policy.routing.budgetFloorRatio && !criticalUnderBudget;

    const fallbackOrder = policy.routing.fallbackByTier[tier] ?? [tier, "balanced", "low"];

    let selectedModel = null;
    let selectedTier = null;

    for (const candidateTier of fallbackOrder) {
      if (premiumDisabledByBudget && candidateTier === "premium") {
        continue;
      }
      const candidateModel = policy.modelTiers[candidateTier].find(
        (model) => !attemptedModels.includes(model)
      );
      if (candidateModel) {
        selectedModel = candidateModel;
        selectedTier = candidateTier;
        break;
      }
    }

    if (!selectedModel) {
      return {
        ok: false,
        error: "no_model_available",
        tier,
        fallbackOrder,
        attemptedModels
      };
    }

    return {
      ok: true,
      selectedModel,
      selectedTier,
      requestedTier: tier,
      fallbackOrder,
      premiumDisabledByBudget
    };
  }

  runWorkflowSimulation(plan) {
    const transitions = [];
    const routingEvents = [];
    const phaseOrder = this.policy.phaseOrder;

    let remainingBudgetRatio = plan.remainingBudgetRatio ?? 1;

    for (const phase of phaseOrder) {
      const phasePlan = plan.phases?.[phase] ?? { result: "success" };

      if (phasePlan.criticalDecisionCategory) {
        const escalation = this.createEscalationPacket({
          reason: "critical_decision",
          phase,
          taskId: null,
          attempts: 0,
          elapsedMinutes: phasePlan.elapsedMinutes ?? 0,
          blockers: [
            `Critical decision category detected: ${phasePlan.criticalDecisionCategory}`
          ],
          options: [
            "Approve the decision and continue automation",
            "Provide a safer alternative",
            "Pause and redesign before continuing"
          ],
          recommendation: "Request explicit human decision before proceeding.",
          decisionRequired: `Resolve ${phasePlan.criticalDecisionCategory} decision`
        });
        return { status: "escalated", transitions, routingEvents, escalation };
      }

      if (phase === "apply") {
        const tasks = phasePlan.tasks ?? [];
        for (const task of tasks) {
          let attempts = 0;
          let resolved = false;
          const attemptedModels = [];
          const outcomes = task.outcomes ?? ["success"];

          while (!resolved) {
            const route = this.routeModel({
              taskType: task.taskType ?? "coding",
              complexity: task.complexity ?? "medium",
              retryCount: attempts,
              remainingBudgetRatio,
              criticalDecisionCategory: task.criticalDecisionCategory ?? null,
              attemptedModels
            });

            if (!route.ok) {
              const escalation = this.createEscalationPacket({
                reason: route.error,
                phase,
                taskId: task.id,
                attempts,
                elapsedMinutes: task.elapsedMinutes ?? 0,
                blockers: ["No policy-compliant model available"],
                options: [
                  "Adjust model allowlist",
                  "Relax routing policy",
                  "Escalate to human"
                ],
                recommendation: "Update model routing configuration.",
                decisionRequired: "Confirm routing policy changes"
              });
              return { status: "escalated", transitions, routingEvents, escalation };
            }

            attemptedModels.push(route.selectedModel);
            routingEvents.push({
              phase,
              taskId: task.id,
              attempt: attempts + 1,
              selectedTier: route.selectedTier,
              selectedModel: route.selectedModel,
              premiumDisabledByBudget: route.premiumDisabledByBudget
            });

            const outcome = outcomes[Math.min(attempts, outcomes.length - 1)] ?? "success";
            attempts += 1;

            if (outcome === "success") {
              resolved = true;
              break;
            }

            const escalationReason = this.classifyEscalation({
              attempts,
              elapsedMinutes: task.elapsedMinutes ?? 0,
              conflictingReviews: task.conflictingReviews ?? false,
              criticalDecisionCategory: task.criticalDecisionCategory ?? null
            });

            if (escalationReason) {
              const escalation = this.createEscalationPacket({
                reason: escalationReason,
                phase,
                taskId: task.id,
                attempts,
                elapsedMinutes: task.elapsedMinutes ?? 0,
                blockers: task.blockers ?? ["Task did not converge within policy limits"],
                options: [
                  "Increase retry/time budget",
                  "Change model tier policy",
                  "Provide manual guidance"
                ],
                recommendation: "Provide human guidance and resume automation.",
                decisionRequired: `Unblock task ${task.id}`
              });
              return { status: "escalated", transitions, routingEvents, escalation };
            }

            remainingBudgetRatio = Math.max(0, remainingBudgetRatio - (task.budgetBurnPerAttempt ?? 0.05));
          }
        }
      }

      const currentIndex = phaseOrder.indexOf(phase);
      const next = phaseOrder[currentIndex + 1];
      if (next) {
        transitions.push({ from: phase, to: next, automatic: true });
      }
    }

    return {
      status: "completed",
      transitions,
      routingEvents,
      escalation: null
    };
  }
}
