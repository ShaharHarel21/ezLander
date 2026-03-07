export const SUBSCRIPTION_TIERS = {
  pro: {
    name: 'Pro',
    tokenLimit: 2_000_000,
    monthlyPrice: 9.99,
    yearlyPrice: 99,
    features: [
      'Managed AI assistant included',
      '2M tokens per month',
      'Google Calendar integration',
      'Apple Calendar integration',
      'Gmail integration',
      'Priority support',
    ],
  },
  max: {
    name: 'Max',
    tokenLimit: 5_000_000,
    monthlyPrice: 19.99,
    yearlyPrice: 199,
    features: [
      'Everything in Pro',
      '5M tokens per month',
      'Early access to new features',
      'Extended 14-day trial',
    ],
  },
} as const

export type SubscriptionTier = keyof typeof SUBSCRIPTION_TIERS

export function getTierTokenLimit(tier: SubscriptionTier): number {
  return SUBSCRIPTION_TIERS[tier].tokenLimit
}

export function isValidTier(tier: string): tier is SubscriptionTier {
  return tier === 'pro' || tier === 'max'
}
