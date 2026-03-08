import { NextRequest, NextResponse } from 'next/server'
import Stripe from 'stripe'
import { db } from '@/lib/db'
import { users } from '@/lib/db/schema'
import { eq } from 'drizzle-orm'
import { REFERRAL_CAP, REFERRED_TRIAL_DAYS } from '@/lib/referral'
import { STRIPE_PLANS, type StripePlanKey } from '@/lib/stripe'
import { verifyAuthToken } from '@/lib/auth-utils'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
})

const VALID_PLANS: StripePlanKey[] = ['pro_monthly', 'pro_yearly', 'max_monthly', 'max_yearly']

export async function POST(request: NextRequest) {
  try {
    // Require authentication
    const auth = await verifyAuthToken(request)
    if (!auth) {
      return NextResponse.json(
        { error: 'Authentication required' },
        { status: 401 }
      )
    }

    const { email: rawEmail, plan, referral_code } = await request.json()
    const email = rawEmail || auth.email

    if (!plan) {
      return NextResponse.json(
        { error: 'Plan is required' },
        { status: 400 }
      )
    }

    if (!VALID_PLANS.includes(plan)) {
      return NextResponse.json(
        { error: 'Invalid plan. Must be one of: pro_monthly, pro_yearly, max_monthly, max_yearly' },
        { status: 400 }
      )
    }

    const planDetails = STRIPE_PLANS[plan as StripePlanKey]

    // Validate referral code if provided
    let validReferralCode: string | null = null
    if (referral_code) {
      const referrer = await db.query.users.findFirst({
        where: eq(users.referralCode, referral_code),
      })
      if (referrer && referrer.referralsCount < REFERRAL_CAP) {
        validReferralCode = referral_code
      }
    }

    // Determine trial period
    let trialDays = planDetails.trialDays
    if (validReferralCode) {
      trialDays = REFERRED_TRIAL_DAYS
    }

    // Check if customer already exists
    let customerId: string | undefined
    if (email) {
      const customers = await stripe.customers.list({
        email,
        limit: 1,
      })
      if (customers.data.length > 0) {
        customerId = customers.data[0].id
      }
    }

    // Create checkout session
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      customer_email: customerId ? undefined : (email || undefined),
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [
        {
          price: planDetails.priceId,
          quantity: 1,
        },
      ],
      subscription_data: {
        trial_period_days: trialDays,
        metadata: {
          plan,
          tier: planDetails.tier,
          ...(validReferralCode ? { referral_code: validReferralCode } : {}),
        },
      },
      success_url: `${process.env.NEXT_PUBLIC_APP_URL}/download?success=true&session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${process.env.NEXT_PUBLIC_APP_URL}/pricing?canceled=true`,
      allow_promotion_codes: true,
    })

    return NextResponse.json({ url: session.url })
  } catch (error) {
    console.error('Checkout session error:', error)
    return NextResponse.json(
      { error: 'Failed to create checkout session' },
      { status: 500 }
    )
  }
}
