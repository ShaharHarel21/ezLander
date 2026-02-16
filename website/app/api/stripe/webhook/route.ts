import { NextRequest, NextResponse } from 'next/server'
import Stripe from 'stripe'

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2023-10-16',
})

const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!

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

async function handleCheckoutComplete(session: Stripe.Checkout.Session) {
  const customerId = session.customer as string
  const email = session.customer_email

  console.log(`Checkout completed for customer: ${customerId}, email: ${email}`)

  // Store subscription info in your database
  // await db.users.update({
  //   where: { email },
  //   data: {
  //     stripeCustomerId: customerId,
  //     subscriptionStatus: 'active',
  //   },
  // })
}

async function handleSubscriptionCreated(subscription: Stripe.Subscription) {
  const customerId = subscription.customer as string
  const plan = subscription.items.data[0].price.lookup_key // 'monthly' or 'yearly'

  console.log(`Subscription created: ${subscription.id}, plan: ${plan}`)

  // Update user subscription in database
  // await db.subscriptions.create({
  //   data: {
  //     stripeSubscriptionId: subscription.id,
  //     stripeCustomerId: customerId,
  //     plan,
  //     status: subscription.status,
  //     currentPeriodEnd: new Date(subscription.current_period_end * 1000),
  //   },
  // })
}

async function handleSubscriptionUpdated(subscription: Stripe.Subscription) {
  console.log(`Subscription updated: ${subscription.id}, status: ${subscription.status}`)

  // Update subscription status in database
  // await db.subscriptions.update({
  //   where: { stripeSubscriptionId: subscription.id },
  //   data: {
  //     status: subscription.status,
  //     currentPeriodEnd: new Date(subscription.current_period_end * 1000),
  //   },
  // })
}

async function handleSubscriptionDeleted(subscription: Stripe.Subscription) {
  console.log(`Subscription deleted: ${subscription.id}`)

  // Mark subscription as canceled in database
  // await db.subscriptions.update({
  //   where: { stripeSubscriptionId: subscription.id },
  //   data: {
  //     status: 'canceled',
  //   },
  // })
}

async function handlePaymentSucceeded(invoice: Stripe.Invoice) {
  const customerId = invoice.customer as string
  console.log(`Payment succeeded for customer: ${customerId}`)

  // You could send a receipt email here
}

async function handlePaymentFailed(invoice: Stripe.Invoice) {
  const customerId = invoice.customer as string
  console.log(`Payment failed for customer: ${customerId}`)

  // Send payment failed notification to user
  // await sendPaymentFailedEmail(customerId)
}
