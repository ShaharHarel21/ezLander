// Shared configuration between macOS app and website

export const APP_CONFIG = {
  name: 'ezLander',
  bundleId: 'com.ezlander.app',
  version: '1.23.0',
  minMacOSVersion: '13.0',
  website: 'https://ezlander.app',
  supportEmail: 'support@ezlander.app',
}

export const SUBSCRIPTION_TIERS = {
  pro: {
    name: 'Pro',
    tokenLimit: 2_000_000,
    monthlyPrice: 9.99,
    yearlyPrice: 99,
    features: [
      'GPT-4o powered AI assistant',
      '2M tokens per month',
      'Google Calendar integration',
      'Apple Calendar integration',
      'Gmail integration',
      'Priority support',
    ],
  },
  max: {
    name: 'Max',
    tokenLimit: 5_000_000,
    monthlyPrice: 19.99,
    yearlyPrice: 199,
    features: [
      'Everything in Pro',
      '5M tokens per month',
      'Early access to new features',
      'Extended 14-day trial',
    ],
  },
}

export const PRICING = {
  pro: {
    monthly: {
      price: 9.99,
      interval: 'month',
      trialDays: 7,
      planKey: 'pro_monthly',
    },
    yearly: {
      price: 99,
      interval: 'year',
      trialDays: 14,
      savings: '17%',
      planKey: 'pro_yearly',
    },
  },
  max: {
    monthly: {
      price: 19.99,
      interval: 'month',
      trialDays: 7,
      planKey: 'max_monthly',
    },
    yearly: {
      price: 199,
      interval: 'year',
      trialDays: 14,
      savings: '17%',
      planKey: 'max_yearly',
    },
  },
}

export const API_ENDPOINTS = {
  // Website API
  licenseVerify: '/api/license/verify',
  stripeCheckout: '/api/stripe/checkout',
  stripePortal: '/api/stripe/portal',
  stripeWebhook: '/api/stripe/webhook',
  download: '/api/download',
  aiProxy: '/api/ai/chat',
  usage: '/api/usage',
  authToken: '/api/auth/token',

  // External APIs
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
  subscriptionUpgraded: 'subscription_upgraded',

  // Integration events
  googleConnected: 'google_connected',
  appleCalendarConnected: 'apple_calendar_connected',
}
