import { NextRequest, NextResponse } from 'next/server'
import Stripe from 'stripe'
import { db } from '@/lib/db'
import { users, referrals, authUsers } from '@/lib/db/schema'
import { eq, and } from 'drizzle-orm'
import { generateReferralCode, REFERRAL_CAP, REFERRAL_REWARD_DAYS } from '@/lib/referral'
import { getTierFromPriceId } from '@/lib/stripe'
import { upsertSubscription, updateSubscriptionStatus, type SubscriptionStatus } from '@/lib/db/subscription-repo'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
})

const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!

function getPriceId(subscription: Stripe.Subscription): string {
  return subscription.items.data[0]?.price?.id ?? ''
}

function getPlanLookupKey(subscription: Stripe.Subscription): string {
  return (
    subscription.items.data.find(
      (item) => typeof item.price?.lookup_key === 'string'
    )?.price.lookup_key || 'unknown'
  )
}

export async function POST(request: NextRequest) {
  const body = await request.text()
  const signature = request.headers.get('stripe-signature')!

  let event: Stripe.Event

  try {
    event = stripe.webhooks.constructEvent(body, signature, webhookSecret)
  } catch (err) {
    console.error('Webhook signature verification failed:', err)
    return NextResponse.json({ error: 'Invalid signature' }, { status: 400 })
  }

  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session
        await handleCheckoutComplete(session)
        break
      }

      case 'customer.subscription.created': {
        const subscription = event.data.object as Stripe.Subscription
        await handleSubscriptionCreated(subscription)
        break
      }

      case 'customer.subscription.updated': {
        const subscription = event.data.object as Stripe.Subscription
        await handleSubscriptionUpdated(subscription)
        break
      }

      case 'customer.subscription.deleted': {
        const subscription = event.data.object as Stripe.Subscription
        await handleSubscriptionDeleted(subscription)
        break
      }

      case 'invoice.payment_succeeded': {
        const invoice = event.data.object as Stripe.Invoice
        await handlePaymentSucceeded(invoice)
        break
      }

      case 'invoice.payment_failed': {
        const invoice = event.data.object as Stripe.Invoice
        await handlePaymentFailed(invoice)
        break
      }

      default:
        console.log(`Unhandled event type: ${event.type}`)
    }

    return NextResponse.json({ received: true })
  } catch (error) {
    console.error('Webhook handler error:', error)
    return NextResponse.json(
      { error: 'Webhook handler failed' },
      { status: 500 }
    )
  }
}

async function findOrCreateAuthUser(email: string): Promise<string | null> {
  // Try to find existing auth user
  const existing = await db.query.authUsers.findFirst({
    where: eq(authUsers.email, email),
  })
  if (existing) return existing.id

  // Create new auth user
  const id = crypto.randomUUID()
  await db.insert(authUsers).values({
    id,
    email,
    name: email.split('@')[0],
  })
  return id
}

async function handleCheckoutComplete(session: Stripe.Checkout.Session) {
  const customerId = session.customer as string
  const email = session.customer_email || session.customer_details?.email

  console.log(`Checkout completed for customer: ${customerId}, email: ${email}`)

  if (!email) return

  // Ensure referred user has a DB record
  const existingUser = await db.query.users.findFirst({
    where: eq(users.email, email),
  })

  if (!existingUser) {
    await db.insert(users).values({
      email,
      referralCode: generateReferralCode(),
    })
  }

  // Upsert subscription in our DB
  const subscriptionId = session.subscription as string
  if (!subscriptionId) return

  const subscription = await stripe.subscriptions.retrieve(subscriptionId)
  const priceId = getPriceId(subscription)
  const tier = subscription.metadata?.tier
    ? (subscription.metadata.tier as 'pro' | 'max')
    : getTierFromPriceId(priceId)

  const authUserId = await findOrCreateAuthUser(email)
  if (authUserId) {
    await upsertSubscription(authUserId, {
      stripeCustomerId: customerId,
      stripeSubscriptionId: subscriptionId,
      tier,
      status: subscription.status === 'trialing' ? 'trialing' : 'active',
      currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
    })
  }

  // Process referral code
  const referralCode = subscription.metadata?.referral_code
  if (!referralCode) return

  const referrer = await db.query.users.findFirst({
    where: eq(users.referralCode, referralCode),
  })

  if (!referrer) return

  // Validate: not self-referral
  if (referrer.email === email) {
    console.log(`Self-referral blocked: ${email}`)
    return
  }

  // Validate: not duplicate
  const existingReferral = await db.query.referrals.findFirst({
    where: and(
      eq(referrals.referrerEmail, referrer.email),
      eq(referrals.referredEmail, email)
    ),
  })

  if (existingReferral) {
    console.log(`Duplicate referral blocked: ${referrer.email} -> ${email}`)
    return
  }

  // Validate: not at cap
  if (referrer.referralsCount >= REFERRAL_CAP) {
    console.log(`Referral cap reached for: ${referrer.email}`)
    return
  }

  // Record the referral
  await db.insert(referrals).values({
    referrerEmail: referrer.email,
    referredEmail: email,
    status: 'completed',
    completedAt: new Date().toISOString(),
  })

  // Credit the referrer
  await db
    .update(users)
    .set({
      referralCreditsDays: referrer.referralCreditsDays + REFERRAL_REWARD_DAYS,
      referralsCount: referrer.referralsCount + 1,
    })
    .where(eq(users.email, referrer.email))

  console.log(`Referral completed: ${referrer.email} earned ${REFERRAL_REWARD_DAYS} days from ${email}`)
}

async function handleSubscriptionCreated(subscription: Stripe.Subscription) {
  const customerId = subscription.customer as string
  const plan = getPlanLookupKey(subscription)

  console.log(`Subscription created: ${subscription.id}, plan: ${plan}`)

  // When a user re-subscribes, pause credit consumption
  const customer = await stripe.customers.retrieve(customerId) as Stripe.Customer
  const email = customer.email

  if (email) {
    const user = await db.query.users.findFirst({
      where: eq(users.email, email),
    })

    if (user && user.creditsActivatedAt) {
      await db
        .update(users)
        .set({ creditsActivatedAt: null })
        .where(eq(users.email, email))

      console.log(`Credits paused for re-subscribing user: ${email}`)
    }

    // Ensure subscription record exists
    const priceId = getPriceId(subscription)
    const tier = subscription.metadata?.tier
      ? (subscription.metadata.tier as 'pro' | 'max')
      : getTierFromPriceId(priceId)

    const authUserId = await findOrCreateAuthUser(email)
    if (authUserId) {
      await upsertSubscription(authUserId, {
        stripeCustomerId: customerId,
        stripeSubscriptionId: subscription.id,
        tier,
        status: subscription.status === 'trialing' ? 'trialing' : 'active',
        currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
      })
    }
  }
}

async function handleSubscriptionUpdated(subscription: Stripe.Subscription) {
  console.log(`Subscription updated: ${subscription.id}, status: ${subscription.status}`)

  const priceId = getPriceId(subscription)
  const tier = subscription.metadata?.tier
    ? (subscription.metadata.tier as 'pro' | 'max')
    : getTierFromPriceId(priceId)

  const statusMap: Record<string, SubscriptionStatus> = {
    active: 'active',
    trialing: 'trialing',
    canceled: 'canceled',
    past_due: 'past_due',
    unpaid: 'expired',
  }

  const mappedStatus: SubscriptionStatus = statusMap[subscription.status] ?? 'expired'

  await updateSubscriptionStatus(subscription.id, mappedStatus, {
    tier,
    currentPeriodEnd: new Date(subscription.current_period_end * 1000).toISOString(),
  })
}

async function handleSubscriptionDeleted(subscription: Stripe.Subscription) {
  console.log(`Subscription deleted: ${subscription.id}`)

  await updateSubscriptionStatus(subscription.id, 'expired')
}

async function handlePaymentSucceeded(invoice: Stripe.Invoice) {
  const customerId = invoice.customer as string
  console.log(`Payment succeeded for customer: ${customerId}`)
}

async function handlePaymentFailed(invoice: Stripe.Invoice) {
  const customerId = invoice.customer as string
  console.log(`Payment failed for customer: ${customerId}`)
}
