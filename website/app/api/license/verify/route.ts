import { NextRequest, NextResponse } from 'next/server'
import Stripe from 'stripe'
import bcrypt from 'bcryptjs'
import { db } from '@/lib/db'
import { users } from '@/lib/db/schema'
import { eq } from 'drizzle-orm'

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

async function getReferralData(email: string) {
  try {
    const user = await db.query.users.findFirst({
      where: eq(users.email, email),
    })
    if (user) {
      return {
        referral_code: user.referralCode,
        referral_credits_days: user.referralCreditsDays,
        referrals_count: user.referralsCount,
      }
    }
  } catch (e) {
    console.error('Error fetching referral data:', e)
  }
  return {}
}

function isAdminEmail(email: string): boolean {
  if (!process.env.ADMIN_EMAIL) return false
  return email.toLowerCase() === process.env.ADMIN_EMAIL.toLowerCase()
}

export async function POST(request: NextRequest) {
  try {
    const { email, password } = await request.json()

    if (!email) {
      return NextResponse.json(
        { error: 'Email is required', message: 'Please enter your email address.' },
        { status: 400 }
      )
    }

    const adminEmail = isAdminEmail(email)

    // Admin email bypass
    if (adminEmail) {
      if (!password) {
        return NextResponse.json({
          is_active: false,
          requires_password: true,
          is_admin_email: true,
          message: 'Admin login requires a password.',
        })
      }

      const hash = process.env.ADMIN_PASSWORD_HASH
      if (!hash) {
        return NextResponse.json(
          { error: 'Admin not configured', message: 'Admin account is not configured. Please contact support.' },
          { status: 500 }
        )
      }

      const valid = await bcrypt.compare(password, hash)
      if (!valid) {
        return NextResponse.json(
          {
            is_active: false,
            is_admin_email: true,
            message: 'Invalid password. Please try again.',
          },
          { status: 401 }
        )
      }

      return NextResponse.json({
        is_active: true,
        plan: 'admin',
        status: 'admin',
        is_admin_email: true,
        message: 'Welcome back, admin!',
      })
    }

    // Find customer by email
    const customers = await stripe.customers.list({
      email,
      limit: 1,
    })

    if (customers.data.length === 0) {
      // No Stripe customer — check referral credits
      return await checkReferralCredits(email)
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
          const referralData = await getReferralData(email)
          return NextResponse.json({
            is_active: true,
            plan: getPlanLookupKey(sub),
            expires_at: endDate.toISOString(),
            status: 'canceled',
            is_admin_email: false,
            message: `Your subscription is active until ${endDate.toLocaleDateString()}.`,
            ...referralData,
          })
        }

        // Canceled and expired
        return NextResponse.json({
          is_active: false,
          plan: getPlanLookupKey(sub),
          expires_at: new Date(sub.current_period_end * 1000).toISOString(),
          status: 'expired',
          is_admin_email: false,
          message: `Your subscription expired on ${new Date(sub.current_period_end * 1000).toLocaleDateString()}. Please renew to continue using ezLander.`,
        })
      }

      // No active subscription — check referral credits
      return await checkReferralCredits(email)
    }

    const subscription = subscriptions.data[0]
    const plan = getPlanLookupKey(subscription)
    const expiresAt = new Date(subscription.current_period_end * 1000)
    const referralData = await getReferralData(email)

    return NextResponse.json({
      is_active: true,
      plan,
      expires_at: expiresAt.toISOString(),
      status: subscription.status,
      is_admin_email: false,
      message: 'Your subscription is active.',
      ...referralData,
    })
  } catch (error) {
    console.error('License verification error:', error)
    return NextResponse.json(
      { error: 'Failed to verify license', message: 'Something went wrong. Please try again later.' },
      { status: 500 }
    )
  }
}

async function checkReferralCredits(email: string) {
  try {
    const user = await db.query.users.findFirst({
      where: eq(users.email, email),
    })

    if (user && user.referralCreditsDays > 0) {
      // First-time credit use: activate
      if (!user.creditsActivatedAt) {
        await db
          .update(users)
          .set({ creditsActivatedAt: new Date().toISOString() })
          .where(eq(users.email, email))
        user.creditsActivatedAt = new Date().toISOString()
      }

      const activatedAt = new Date(user.creditsActivatedAt)
      const expiresAt = new Date(
        activatedAt.getTime() + user.referralCreditsDays * 24 * 60 * 60 * 1000
      )

      if (expiresAt > new Date()) {
        return NextResponse.json({
          is_active: true,
          plan: 'referral_credit',
          expires_at: expiresAt.toISOString(),
          status: 'referral_credit',
          is_admin_email: false,
          message: `You have ${user.referralCreditsDays} days of referral credit active.`,
          referral_code: user.referralCode,
          referral_credits_days: user.referralCreditsDays,
          referrals_count: user.referralsCount,
        })
      }
    }
  } catch (e) {
    console.error('Error checking referral credits:', e)
  }

  return NextResponse.json({
    is_active: false,
    plan: null,
    expires_at: null,
    is_admin_email: false,
    message: 'No active subscription found. Please subscribe to use ezLander.',
  })
}
