// Shared configuration between macOS app and website

export const APP_CONFIG = {
  name: 'ezLander',
  bundleId: 'com.ezlander.app',
  version: '1.0.0',
  minMacOSVersion: '13.0',
  website: 'https://ezlander.app',
  supportEmail: 'support@ezlander.app',
}

export const PRICING = {
  monthly: {
    price: 9.99,
    interval: 'month',
    trialDays: 7,
    features: [
      'Unlimited AI conversations',
      'Google Calendar integration',
      'Apple Calendar integration',
      'Gmail integration',
      'Priority support',
    ],
  },
  yearly: {
    price: 99,
    interval: 'year',
    trialDays: 14,
    savings: '17%',
    features: [
      'Everything in Monthly',
      'Save 17% compared to monthly',
      'Early access to new features',
      'Extended 14-day trial',
    ],
  },
}

export const API_ENDPOINTS = {
  // Website API
  licenseVerify: '/api/license/verify',
  stripeCheckout: '/api/stripe/checkout',
  stripePortal: '/api/stripe/portal',
  stripeWebhook: '/api/stripe/webhook',
  download: '/api/download',

  // External APIs
  claude: 'https://api.anthropic.com/v1/messages',
  googleCalendar: 'https://www.googleapis.com/calendar/v3',
  gmail: 'https://www.googleapis.com/gmail/v1',
  googleOAuth: 'https://accounts.google.com/o/oauth2/v2/auth',
  googleToken: 'https://oauth2.googleapis.com/token',
}

export const GOOGLE_SCOPES = [
  'https://www.googleapis.com/auth/calendar',
  'https://www.googleapis.com/auth/gmail.send',
  'https://www.googleapis.com/auth/gmail.readonly',
  'email',
  'profile',
]

export const CLAUDE_CONFIG = {
  model: 'claude-sonnet-4-20250514',
  maxTokens: 4096,
  apiVersion: '2023-06-01',
}

export const FEATURE_FLAGS = {
  enableAppleCalendar: true,
  enableGoogleCalendar: true,
  enableGmail: true,
  enableStreaming: true,
  enableAutoUpdates: true,
}

export const ANALYTICS_EVENTS = {
  // App events
  appLaunched: 'app_launched',
  appClosed: 'app_closed',
  chatMessageSent: 'chat_message_sent',
  calendarEventCreated: 'calendar_event_created',
  emailSent: 'email_sent',

  // Subscription events
  trialStarted: 'trial_started',
  subscriptionCreated: 'subscription_created',
  subscriptionCanceled: 'subscription_canceled',

  // Integration events
  googleConnected: 'google_connected',
  appleCalendarConnected: 'apple_calendar_connected',
}
