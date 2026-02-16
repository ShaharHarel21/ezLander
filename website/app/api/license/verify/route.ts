import { NextRequest, NextResponse } from 'next/server'
import Stripe from 'stripe'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
})

export async function POST(request: NextRequest) {
  try {
    const { email } = await request.json()

    if (!email) {
      return NextResponse.json(
        { error: 'Email is required' },
        { status: 400 }
      )
    }

    // Find customer by email
    const customers = await stripe.customers.list({
      email,
      limit: 1,
    })

    if (customers.data.length === 0) {
      return NextResponse.json({
        is_active: false,
        plan: null,
        expires_at: null,
      })
    }

    const customer = customers.data[0]

    // Get active subscriptions
    const subscriptions = await stripe.subscriptions.list({
      customer: customer.id,
      status: 'active',
      limit: 1,
    })

    if (subscriptions.data.length === 0) {
      // Check for canceled but still valid subscriptions
      const canceledSubs = await stripe.subscriptions.list({
        customer: customer.id,
        status: 'canceled',
        limit: 1,
      })

      if (canceledSubs.data.length > 0) {
        const sub = canceledSubs.data[0]
        const endDate = new Date(sub.current_period_end * 1000)

        if (endDate > new Date()) {
          // Still valid until end of period
          return NextResponse.json({
            is_active: true,
            plan: sub.items.data[0].price.lookup_key || 'unknown',
            expires_at: endDate.toISOString(),
            status: 'canceled',
          })
        }
      }

      return NextResponse.json({
        is_active: false,
        plan: null,
        expires_at: null,
      })
    }

    const subscription = subscriptions.data[0]
    const plan = subscription.items.data[0].price.lookup_key || 'unknown'
    const expiresAt = new Date(subscription.current_period_end * 1000)

    return NextResponse.json({
      is_active: true,
      plan,
      expires_at: expiresAt.toISOString(),
      status: subscription.status,
    })
  } catch (error) {
    console.error('License verification error:', error)
    return NextResponse.json(
      { error: 'Failed to verify license' },
      { status: 500 }
    )
  }
}
