import Hero from '@/components/Hero'
import Features from '@/components/Features'
import Pricing from '@/components/Pricing'
import FAQ from '@/components/FAQ'
import Footer from '@/components/Footer'
import Navbar from '@/components/Navbar'

const softwareJsonLd = {
  '@context': 'https://schema.org',
  '@type': 'SoftwareApplication',
  name: 'ezLander',
  description: 'A macOS menu bar AI assistant that connects to your calendar and email. Supports OpenAI, Claude, Google Gemini, and Kimi.',
  url: 'https://ezlander.app',
  applicationCategory: 'ProductivityApplication',
  operatingSystem: 'macOS 13+',
  offers: {
    '@type': 'Offer',
    price: '9.99',
    priceCurrency: 'USD',
  },
  softwareVersion: '1.2.0',
  author: {
    '@type': 'Organization',
    name: 'ezLander',
    url: 'https://ezlander.app',
  },
}

const faqJsonLd = {
  '@context': 'https://schema.org',
  '@type': 'FAQPage',
  mainEntity: [
    {
      '@type': 'Question',
      name: 'How does the free trial work?',
      acceptedAnswer: {
        '@type': 'Answer',
        text: 'You get 7 days of full access to all features, no credit card required. After the trial, you can choose to subscribe or the app will stop working until you do.',
      },
    },
    {
      '@type': 'Question',
      name: 'Which calendars are supported?',
      acceptedAnswer: {
        '@type': 'Answer',
        text: 'ezLander works with Google Calendar and Apple Calendar (including iCloud). You can connect both and choose which one to use as your default.',
      },
    },
    {
      '@type': 'Question',
      name: 'Is my data secure?',
      acceptedAnswer: {
        '@type': 'Answer',
        text: 'Absolutely. Your calendar events and emails are processed locally on your device. We never store your personal data on our servers. OAuth tokens are securely stored in your macOS Keychain.',
      },
    },
    {
      '@type': 'Question',
      name: 'What AI powers ezLander?',
      acceptedAnswer: {
        '@type': 'Answer',
        text: "ezLander supports multiple AI providers: OpenAI (GPT-4o), Anthropic's Claude, Google Gemini, and Kimi. You choose which provider to use and provide your own API key — your key stays securely on your device and is never sent to our servers.",
      },
    },
    {
      '@type': 'Question',
      name: 'Can I cancel anytime?',
      acceptedAnswer: {
        '@type': 'Answer',
        text: "Yes, you can cancel your subscription at any time. You'll continue to have access until the end of your billing period.",
      },
    },
    {
      '@type': 'Question',
      name: 'What macOS versions are supported?',
      acceptedAnswer: {
        '@type': 'Answer',
        text: 'ezLander requires macOS 13 (Ventura) or later. We always support the latest macOS version.',
      },
    },
    {
      '@type': 'Question',
      name: 'Do you offer refunds?',
      acceptedAnswer: {
        '@type': 'Answer',
        text: "Yes, we offer a 30-day money-back guarantee. If you're not satisfied, contact us for a full refund.",
      },
    },
    {
      '@type': 'Question',
      name: 'How do I get support?',
      acceptedAnswer: {
        '@type': 'Answer',
        text: 'Email us at support@ezlander.app. We typically respond within 24 hours. Pro subscribers get priority support.',
      },
    },
  ],
}

const organizationJsonLd = {
  '@context': 'https://schema.org',
  '@type': 'Organization',
  name: 'ezLander',
  url: 'https://ezlander.app',
  sameAs: [
    'https://twitter.com/ezlander',
    'https://github.com/shahar-harell/ezLander',
  ],
}

export default function Home() {
  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(softwareJsonLd) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(faqJsonLd) }}
      />
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(organizationJsonLd) }}
      />
      <Navbar />
      <Hero />
      <Features />
      <Pricing />
      <FAQ />
      <Footer />
    </>
  )
}
