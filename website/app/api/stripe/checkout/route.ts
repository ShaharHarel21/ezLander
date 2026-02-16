import { NextRequest, NextResponse } from 'next/server'
import Stripe from 'stripe'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
})

const PRICES = {
  monthly: process.env.STRIPE_MONTHLY_PRICE_ID!,
  yearly: process.env.STRIPE_YEARLY_PRICE_ID!,
}

export async function POST(request: NextRequest) {
  try {
    const { email, plan } = await request.json()

    if (!email || !plan) {
      return NextResponse.json(
        { error: 'Email and plan are required' },
        { status: 400 }
      )
    }

    if (!['monthly', 'yearly'].includes(plan)) {
      return NextResponse.json(
        { error: 'Invalid plan' },
        { status: 400 }
      )
    }

    // Check if customer already exists
    const customers = await stripe.customers.list({
      email,
      limit: 1,
    })

    let customerId: string | undefined

    if (customers.data.length > 0) {
      customerId = customers.data[0].id
    }

    // Create checkout session
    const session = await stripe.checkout.sessions.create({
      customer: customerId,
      customer_email: customerId ? undefined : email,
      mode: 'subscription',
      payment_method_types: ['card'],
      line_items: [
        {
          price: PRICES[plan as keyof typeof PRICES],
          quantity: 1,
        },
      ],
      subscription_data: {
        trial_period_days: plan === 'yearly' ? 14 : 7,
        metadata: {
          plan,
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
