// Shared types between macOS app and website

export interface User {
  id: string
  email: string
  name: string
  picture?: string
  subscription?: Subscription
}

export interface Subscription {
  plan: 'trial' | 'monthly' | 'yearly'
  status: 'active' | 'canceled' | 'expired' | 'past_due'
  startDate: string
  expiresAt?: string
  stripeCustomerId?: string
}

export interface CalendarEvent {
  id: string
  title: string
  startDate: string
  endDate: string
  calendarType: 'google' | 'apple'
  description?: string
  location?: string
  isAllDay?: boolean
}

export interface Email {
  id: string
  to: string
  from?: string
  subject: string
  body: string
  date: string
  isRead?: boolean
  labels?: string[]
}

export interface ChatMessage {
  id: string
  role: 'user' | 'assistant'
  content: string
  toolCall?: ToolCall
  timestamp: string
}

export interface ToolCall {
  name: string
  parameters: Record<string, string>
  result?: string
}

// API Response types
export interface LicenseVerifyResponse {
  is_active: boolean
  plan: 'monthly' | 'yearly' | null
  expires_at: string | null
  status?: string
}

export interface CheckoutSessionResponse {
  url: string
}

export interface PortalSessionResponse {
  url: string
}

// Webhook event types
export type StripeWebhookEvent =
  | 'checkout.session.completed'
  | 'customer.subscription.created'
  | 'customer.subscription.updated'
  | 'customer.subscription.deleted'
  | 'invoice.payment_succeeded'
  | 'invoice.payment_failed'

// AI Tool definitions
export const AI_TOOLS = [
  {
    name: 'create_calendar_event',
    description: 'Create a new calendar event',
    parameters: {
      title: 'string',
      date: 'string (YYYY-MM-DD)',
      time: 'string (HH:MM)',
      duration: 'number (minutes)',
      calendar_type: "'google' | 'apple'",
    },
  },
  {
    name: 'list_calendar_events',
    description: 'List calendar events for a date range',
    parameters: {
      start_date: 'string (YYYY-MM-DD)',
      end_date: 'string (YYYY-MM-DD)',
      calendar_type: "'google' | 'apple' | 'both'",
    },
  },
  {
    name: 'send_email',
    description: 'Send an email via Gmail',
    parameters: {
      to: 'string (email address)',
      subject: 'string',
      body: 'string',
    },
  },
  {
    name: 'draft_email',
    description: 'Create an email draft for user review',
    parameters: {
      to: 'string (email address)',
      subject: 'string',
      body: 'string',
    },
  },
  {
    name: 'search_emails',
    description: 'Search emails in Gmail',
    parameters: {
      query: 'string (Gmail search syntax)',
    },
  },
] as const
