import Stripe from 'stripe'

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
  typescript: true,
})

export const STRIPE_PLANS = {
  monthly: {
    priceId: process.env.STRIPE_MONTHLY_PRICE_ID!,
    price: 9.99,
    interval: 'month' as const,
    trialDays: 7,
  },
  yearly: {
    priceId: process.env.STRIPE_YEARLY_PRICE_ID!,
    price: 99,
    interval: 'year' as const,
    trialDays: 14,
  },
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
  plan: 'monthly' | 'yearly'
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

  const plan = subscription.items.data[0].price.lookup_key as 'monthly' | 'yearly'
  const expiresAt = new Date(subscription.current_period_end * 1000)

  return {
    isActive: true,
    plan,
    expiresAt,
    status: subscription.status,
    cancelAtPeriodEnd: subscription.cancel_at_period_end,
  }
}
