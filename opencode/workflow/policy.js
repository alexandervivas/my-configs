export const DEFAULT_POLICY = {
  phaseOrder: ["explore", "propose", "apply", "archive"],
  escalation: {
    maxAttemptsPerTask: 3,
    maxPhaseMinutes: 45,
    criticalDecisionCategories: [
      "security",
      "data_integrity",
      "compliance",
      "irreversible_architecture"
    ]
  },
  routing: {
    promotionRetries: 2,
    budgetFloorRatio: 0.15,
    defaultTierByTaskType: {
      triage: "low",
      docs: "low",
      coding: "balanced",
      testing: "balanced",
      review: "balanced",
      critical_review: "premium"
    },
    fallbackByTier: {
      low: ["low", "balanced", "premium"],
      balanced: ["balanced", "premium", "low"],
      premium: ["premium", "balanced", "low"]
    },
    allowPremiumUnderBudgetFloorFor: ["security", "data_integrity"]
  },
  modelTiers: {
    low: [
      "openrouter/anthropic/claude-3.5-haiku",
      "openrouter/openai/gpt-4.1-mini"
    ],
    balanced: [
      "openrouter/qwen/qwen3-coder",
      "openrouter/openai/gpt-4.1-mini"
    ],
    premium: [
      "openrouter/anthropic/claude-3.7-sonnet"
    ]
  }
};

export function allAllowlistedModels(policy = DEFAULT_POLICY) {
  const tiers = policy.modelTiers;
  return new Set([...tiers.low, ...tiers.balanced, ...tiers.premium]);
}

export function isCriticalDecision(category, policy = DEFAULT_POLICY) {
  if (!category) return false;
  return policy.escalation.criticalDecisionCategories.includes(category);
}
