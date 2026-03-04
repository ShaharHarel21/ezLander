import Stripe from 'stripe'
import type { SubscriptionTier } from '@/lib/tiers'

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
  typescript: true,
})

export const STRIPE_PLANS = {
  pro_monthly: {
    priceId: process.env.STRIPE_PRO_MONTHLY_PRICE_ID!,
    tier: 'pro' as SubscriptionTier,
    price: 9.99,
    interval: 'month' as const,
    trialDays: 7,
  },
  pro_yearly: {
    priceId: process.env.STRIPE_PRO_YEARLY_PRICE_ID!,
    tier: 'pro' as SubscriptionTier,
    price: 99,
    interval: 'year' as const,
    trialDays: 14,
  },
  max_monthly: {
    priceId: process.env.STRIPE_MAX_MONTHLY_PRICE_ID!,
    tier: 'max' as SubscriptionTier,
    price: 19.99,
    interval: 'month' as const,
    trialDays: 7,
  },
  max_yearly: {
    priceId: process.env.STRIPE_MAX_YEARLY_PRICE_ID!,
    tier: 'max' as SubscriptionTier,
    price: 199,
    interval: 'year' as const,
    trialDays: 14,
  },
}

export type StripePlanKey = keyof typeof STRIPE_PLANS

// Legacy plan IDs for backward compatibility during migration
const LEGACY_PRICE_IDS: Record<string, SubscriptionTier> = {
  [process.env.STRIPE_MONTHLY_PRICE_ID ?? '']: 'pro',
  [process.env.STRIPE_YEARLY_PRICE_ID ?? '']: 'pro',
}

export function getTierFromPriceId(priceId: string): SubscriptionTier {
  // Check new plans first
  for (const plan of Object.values(STRIPE_PLANS)) {
    if (plan.priceId === priceId) return plan.tier
  }
  // Fall back to legacy mapping
  return LEGACY_PRICE_IDS[priceId] ?? 'pro'
}

function getSubscriptionPlanLookupKey(subscription: Stripe.Subscription): string | null {
  return (
    subscription.items.data.find(
      (item) => typeof item.price?.lookup_key === 'string'
    )?.price.lookup_key ?? null
  )
}

export async function getCustomerByEmail(email: string) {
  const customers = await stripe.customers.list({
    email,
    limit: 1,
  })

  return customers.data[0] || null
}

export async function getActiveSubscription(customerId: string) {
  const subscriptions = await stripe.subscriptions.list({
    customer: customerId,
    status: 'active',
    limit: 1,
  })

  return subscriptions.data[0] || null
}

export async function createCheckoutSession(
  email: string,
  plan: StripePlanKey
) {
  const planDetails = STRIPE_PLANS[plan]

  // Check for existing customer
  const existingCustomer = await getCustomerByEmail(email)

  const session = await stripe.checkout.sessions.create({
    customer: existingCustomer?.id,
    customer_email: existingCustomer ? undefined : email,
    mode: 'subscription',
    payment_method_types: ['card'],
    line_items: [
      {
        price: planDetails.priceId,
        quantity: 1,
      },
    ],
    subscription_data: {
      trial_period_days: planDetails.trialDays,
      metadata: {
        tier: planDetails.tier,
        plan,
      },
    },
    success_url: `${process.env.NEXT_PUBLIC_APP_URL}/download?success=true`,
    cancel_url: `${process.env.NEXT_PUBLIC_APP_URL}/pricing?canceled=true`,
    allow_promotion_codes: true,
  })

  return session
}

export async function createBillingPortalSession(customerId: string) {
  const session = await stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: `${process.env.NEXT_PUBLIC_APP_URL}/download`,
  })

  return session
}

export async function cancelSubscription(subscriptionId: string) {
  return stripe.subscriptions.cancel(subscriptionId)
}

export async function getSubscriptionStatus(email: string) {
  const customer = await getCustomerByEmail(email)

  if (!customer) {
    return { isActive: false, plan: null, expiresAt: null }
  }

  const subscription = await getActiveSubscription(customer.id)

  if (!subscription) {
    return { isActive: false, plan: null, expiresAt: null }
  }

  const plan = getSubscriptionPlanLookupKey(subscription)
  const expiresAt = new Date(subscription.current_period_end * 1000)

  return {
    isActive: true,
    plan: plan ?? 'unknown',
    expiresAt,
    status: subscription.status,
    cancelAtPeriodEnd: subscription.cancel_at_period_end,
  }
}
