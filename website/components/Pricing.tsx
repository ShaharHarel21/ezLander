'use client'

import { useState, useEffect } from 'react'
import { motion } from 'framer-motion'
import Link from 'next/link'
import { useSearchParams } from 'next/navigation'

const tiers = [
  {
    name: 'Pro',
    key: 'pro',
    monthlyPrice: 9.99,
    yearlyPrice: 99,
    tokenLimit: '2M tokens/month',
    description: 'Perfect for getting started with AI assistance',
    features: [
      'GPT-4o powered AI assistant',
      '2M tokens per month',
      'Google Calendar integration',
      'Apple Calendar integration',
      'Gmail integration',
      'Priority support',
    ],
    cta: 'Start free trial',
    popular: false,
  },
  {
    name: 'Max',
    key: 'max',
    monthlyPrice: 19.99,
    yearlyPrice: 199,
    tokenLimit: '5M tokens/month',
    description: 'For power users who need more',
    features: [
      'Everything in Pro',
      '5M tokens per month',
      'Early access to new features',
      'Extended 14-day trial',
    ],
    cta: 'Start free trial',
    popular: true,
    badge: 'Most Popular',
  },
]

export default function Pricing() {
  const searchParams = useSearchParams()
  const [isYearly, setIsYearly] = useState(true)
  const [referralCode, setReferralCode] = useState('')
  const [referralValid, setReferralValid] = useState<boolean | null>(null)
  const [referralMaskedEmail, setReferralMaskedEmail] = useState('')
  const [showReferralInput, setShowReferralInput] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [isCheckingOut, setIsCheckingOut] = useState(false)

  useEffect(() => {
    const ref = searchParams.get('ref')
    if (ref) {
      setReferralCode(ref)
      validateReferralCode(ref)
    }
  }, [searchParams])

  async function validateReferralCode(code: string) {
    if (!code) {
      setReferralValid(null)
      return
    }
    setIsLoading(true)
    try {
      const res = await fetch(`/api/referral/validate?code=${encodeURIComponent(code)}`)
      const data = await res.json()
      setReferralValid(data.valid)
      if (data.referrer_email_masked) {
        setReferralMaskedEmail(data.referrer_email_masked)
      }
    } catch {
      setReferralValid(false)
    } finally {
      setIsLoading(false)
    }
  }

  async function handleCheckout(tierKey: string) {
    setIsCheckingOut(true)
    const planKey = `${tierKey}_${isYearly ? 'yearly' : 'monthly'}`
    try {
      const res = await fetch('/api/stripe/checkout', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          plan: planKey,
          ...(referralValid && referralCode ? { referral_code: referralCode } : {}),
        }),
      })
      const data = await res.json()
      if (data.url) {
        window.location.href = data.url
      }
    } catch (error) {
      console.error('Checkout error:', error)
    } finally {
      setIsCheckingOut(false)
    }
  }

  return (
    <section id="pricing" className="py-20 px-4 sm:px-6 lg:px-8 bg-gray-50 dark:bg-gray-900/50">
      <div className="max-w-7xl mx-auto">
        {/* Section header */}
        <div className="text-center mb-16">
          <motion.span
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            className="inline-block text-primary-600 dark:text-primary-400 font-semibold mb-4"
          >
            Pricing
          </motion.span>
          <motion.h2
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.1 }}
            className="text-4xl sm:text-5xl font-bold"
          >
            Choose your plan
          </motion.h2>
          <motion.p
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.2 }}
            className="mt-4 text-xl text-gray-600 dark:text-gray-400 max-w-2xl mx-auto"
          >
            Start with a free trial. No credit card required.
          </motion.p>

          {/* Referral banner */}
          {referralValid && (
            <motion.div
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              className="mt-6 inline-flex items-center gap-2 bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 text-green-700 dark:text-green-400 px-4 py-2 rounded-lg text-sm font-medium"
            >
              <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
                <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
              </svg>
              Referral code {referralCode} applied! You&apos;ll get a 14-day free trial
            </motion.div>
          )}

          {referralValid === false && referralCode && (
            <motion.div
              initial={{ opacity: 0, y: -10 }}
              animate={{ opacity: 1, y: 0 }}
              className="mt-6 inline-flex items-center gap-2 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 text-red-700 dark:text-red-400 px-4 py-2 rounded-lg text-sm font-medium"
            >
              Invalid referral code
            </motion.div>
          )}

          {/* Toggle */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.3 }}
            className="mt-8 flex items-center justify-center gap-4"
          >
            <span className={`font-medium ${!isYearly ? 'text-gray-900 dark:text-white' : 'text-gray-500 dark:text-gray-400'}`}>
              Monthly
            </span>
            <button
              onClick={() => setIsYearly(!isYearly)}
              className="relative w-14 h-8 rounded-full bg-primary-500 transition-colors"
              role="switch"
              aria-checked={isYearly}
              aria-label="Toggle yearly pricing"
            >
              <span
                className={`absolute top-1 w-6 h-6 bg-white rounded-full shadow transition-transform ${
                  isYearly ? 'translate-x-7' : 'translate-x-1'
                }`}
              />
            </button>
            <span className={`font-medium ${isYearly ? 'text-gray-900 dark:text-white' : 'text-gray-500 dark:text-gray-400'}`}>
              Yearly
              <span className="ml-2 text-xs bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 px-2 py-1 rounded-full">
                Save 17%
              </span>
            </span>
          </motion.div>

          {/* Referral code input */}
          {!referralValid && (
            <motion.div
              initial={{ opacity: 0 }}
              whileInView={{ opacity: 1 }}
              viewport={{ once: true }}
              transition={{ delay: 0.4 }}
              className="mt-4"
            >
              {!showReferralInput ? (
                <button
                  onClick={() => setShowReferralInput(true)}
                  className="text-sm text-primary-600 dark:text-primary-400 hover:underline"
                >
                  Have a referral code?
                </button>
              ) : (
                <div className="flex items-center justify-center gap-2 mt-2">
                  <input
                    type="text"
                    value={referralCode}
                    onChange={(e) => setReferralCode(e.target.value.toUpperCase())}
                    placeholder="EZ-XXXXXX"
                    className="px-3 py-2 border border-gray-300 dark:border-gray-600 rounded-lg text-sm bg-white dark:bg-gray-800 w-40 text-center font-mono"
                  />
                  <button
                    onClick={() => validateReferralCode(referralCode)}
                    disabled={isLoading || !referralCode}
                    className="px-4 py-2 bg-primary-500 text-white text-sm rounded-lg hover:bg-primary-600 disabled:opacity-50"
                  >
                    {isLoading ? 'Checking...' : 'Apply'}
                  </button>
                </div>
              )}
            </motion.div>
          )}
        </div>

        {/* Pricing cards */}
        <div className="grid md:grid-cols-2 gap-8 max-w-4xl mx-auto mt-4">
          {tiers.map((tier, index) => {
            const displayPrice = isYearly
              ? (tier.yearlyPrice / 12).toFixed(2)
              : tier.monthlyPrice.toFixed(2)
            const billedText = isYearly
              ? `Billed $${tier.yearlyPrice}/year`
              : null

            return (
              <motion.div
                key={tier.name}
                initial={{ opacity: 0, y: 20 }}
                whileInView={{ opacity: 1, y: 0 }}
                viewport={{ once: true }}
                transition={{ delay: index * 0.1 }}
                className={`relative p-8 rounded-2xl ${
                  tier.popular
                    ? 'bg-gradient-to-b from-primary-500 to-accent-500 text-white'
                    : 'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700'
                }`}
              >
                {tier.badge && (
                  <span className="absolute -top-3 left-1/2 -translate-x-1/2 px-4 py-1 bg-yellow-400 text-yellow-900 text-sm font-semibold rounded-full">
                    {tier.badge}
                  </span>
                )}

                <div className="text-center mb-8">
                  <h3 className={`text-xl font-semibold ${tier.popular ? 'text-white' : ''}`}>
                    {tier.name}
                  </h3>
                  <div className={`mt-1 text-sm font-medium ${tier.popular ? 'text-white/80' : 'text-primary-600 dark:text-primary-400'}`}>
                    {tier.tokenLimit}
                  </div>
                  <div className="mt-4">
                    <span className="text-5xl font-bold">
                      ${displayPrice}
                    </span>
                    <span className={`${tier.popular ? 'text-white/80' : 'text-gray-500 dark:text-gray-400'}`}>
                      /month
                    </span>
                    {billedText && (
                      <span className={`block text-sm mt-1 ${tier.popular ? 'text-white/70' : 'text-gray-500 dark:text-gray-400'}`}>
                        {billedText}
                      </span>
                    )}
                  </div>
                  <p className={`mt-2 ${tier.popular ? 'text-white/80' : 'text-gray-600 dark:text-gray-400'}`}>
                    {tier.description}
                  </p>
                </div>

                <ul className="space-y-4 mb-8">
                  {tier.features.map((feature, i) => (
                    <li key={i} className="flex items-center gap-3">
                      <svg
                        className={`w-5 h-5 flex-shrink-0 ${
                          tier.popular ? 'text-white' : 'text-green-500'
                        }`}
                        fill="currentColor"
                        viewBox="0 0 20 20"
                      >
                        <path
                          fillRule="evenodd"
                          d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                          clipRule="evenodd"
                        />
                      </svg>
                      <span className={tier.popular ? 'text-white/90' : ''}>{feature}</span>
                    </li>
                  ))}
                </ul>

                <button
                  onClick={() => handleCheckout(tier.key)}
                  disabled={isCheckingOut}
                  className={`block w-full py-4 text-center rounded-xl font-semibold transition-colors disabled:opacity-50 ${
                    tier.popular
                      ? 'bg-white text-gray-900 hover:bg-gray-100'
                      : 'bg-gradient-to-r from-primary-500 to-accent-500 text-white hover:opacity-90'
                  }`}
                >
                  {isCheckingOut ? 'Redirecting...' : tier.cta}
                </button>
                <p className={`mt-3 text-xs text-center ${tier.popular ? 'text-white/70' : 'text-gray-500 dark:text-gray-400'}`}>
                  Cancel anytime. 30-day money-back guarantee.
                </p>
              </motion.div>
            )
          })}
        </div>

        {/* FAQ teaser */}
        <motion.div
          initial={{ opacity: 0 }}
          whileInView={{ opacity: 1 }}
          viewport={{ once: true }}
          className="mt-16 text-center"
        >
          <p className="text-gray-600 dark:text-gray-400">
            Have questions?{' '}
            <Link href="#faq" className="text-primary-600 dark:text-primary-400 hover:underline">
              Check out our FAQ
            </Link>
          </p>
        </motion.div>
      </div>
    </section>
  )
}
