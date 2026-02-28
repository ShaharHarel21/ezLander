import { NextRequest, NextResponse } from 'next/server'
import Stripe from 'stripe'
import bcrypt from 'bcryptjs'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
})

function getPlanLookupKey(subscription: Stripe.Subscription): string {
  return (
    subscription.items.data.find(
      (item) => typeof item.price?.lookup_key === 'string'
    )?.price.lookup_key || 'unknown'
  )
}

export async function POST(request: NextRequest) {
  try {
    const { email, password } = await request.json()

    if (!email) {
      return NextResponse.json(
        { error: 'Email is required' },
        { status: 400 }
      )
    }

    // Admin email bypass
    if (
      process.env.ADMIN_EMAIL &&
      email.toLowerCase() === process.env.ADMIN_EMAIL.toLowerCase()
    ) {
      if (!password) {
        return NextResponse.json({
          is_active: false,
          requires_password: true,
        })
      }

      const hash = process.env.ADMIN_PASSWORD_HASH
      if (!hash) {
        return NextResponse.json(
          { error: 'Admin not configured' },
          { status: 500 }
        )
      }

      const valid = await bcrypt.compare(password, hash)
      if (!valid) {
        return NextResponse.json(
          { error: 'Invalid password' },
          { status: 401 }
        )
      }

      return NextResponse.json({
        is_active: true,
        plan: 'admin',
        status: 'admin',
      })
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
            plan: getPlanLookupKey(sub),
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
    const plan = getPlanLookupKey(subscription)
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
