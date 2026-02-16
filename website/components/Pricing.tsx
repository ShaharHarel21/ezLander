'use client'

import { useState } from 'react'
import { motion } from 'framer-motion'
import Link from 'next/link'

const plans = [
  {
    name: 'Monthly',
    price: 9.99,
    period: 'month',
    description: 'Perfect for trying out ezLander',
    features: [
      'Unlimited AI conversations',
      'Google Calendar integration',
      'Apple Calendar integration',
      'Gmail integration',
      'Priority support',
    ],
    cta: 'Start free trial',
    popular: false,
  },
  {
    name: 'Yearly',
    price: 99,
    period: 'year',
    description: 'Best value for power users',
    features: [
      'Everything in Monthly',
      'Save 17% compared to monthly',
      'Early access to new features',
      'Extended 14-day trial',
    ],
    cta: 'Start free trial',
    popular: true,
    badge: 'Best Value',
  },
]

export default function Pricing() {
  const [isYearly, setIsYearly] = useState(true)

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
            Simple, transparent pricing
          </motion.h2>
          <motion.p
            initial={{ opacity: 0, y: 20 }}
            whileInView={{ opacity: 1, y: 0 }}
            viewport={{ once: true }}
            transition={{ delay: 0.2 }}
            className="mt-4 text-xl text-gray-600 dark:text-gray-400 max-w-2xl mx-auto"
          >
            Start with a 7-day free trial. No credit card required.
          </motion.p>

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
        </div>

        {/* Pricing cards */}
        <div className="grid md:grid-cols-2 gap-8 max-w-4xl mx-auto">
          {plans.map((plan, index) => (
            <motion.div
              key={plan.name}
              initial={{ opacity: 0, y: 20 }}
              whileInView={{ opacity: 1, y: 0 }}
              viewport={{ once: true }}
              transition={{ delay: index * 0.1 }}
              className={`relative p-8 rounded-2xl ${
                plan.popular
                  ? 'bg-gradient-to-b from-primary-500 to-accent-500 text-white'
                  : 'bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700'
              }`}
            >
              {plan.badge && (
                <span className="absolute -top-3 left-1/2 -translate-x-1/2 px-4 py-1 bg-yellow-400 text-yellow-900 text-sm font-semibold rounded-full">
                  {plan.badge}
                </span>
              )}

              <div className="text-center mb-8">
                <h3 className={`text-xl font-semibold ${plan.popular ? 'text-white' : ''}`}>
                  {plan.name}
                </h3>
                <div className="mt-4">
                  <span className="text-5xl font-bold">
                    ${isYearly && plan.name === 'Yearly' ? plan.price : plan.price}
                  </span>
                  <span className={`${plan.popular ? 'text-white/80' : 'text-gray-500 dark:text-gray-400'}`}>
                    /{plan.period}
                  </span>
                </div>
                <p className={`mt-2 ${plan.popular ? 'text-white/80' : 'text-gray-600 dark:text-gray-400'}`}>
                  {plan.description}
                </p>
              </div>

              <ul className="space-y-4 mb-8">
                {plan.features.map((feature, i) => (
                  <li key={i} className="flex items-center gap-3">
                    <svg
                      className={`w-5 h-5 flex-shrink-0 ${
                        plan.popular ? 'text-white' : 'text-green-500'
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
                    <span className={plan.popular ? 'text-white/90' : ''}>{feature}</span>
                  </li>
                ))}
              </ul>

              <Link
                href="/download"
                className={`block w-full py-4 text-center rounded-xl font-semibold transition-colors ${
                  plan.popular
                    ? 'bg-white text-gray-900 hover:bg-gray-100'
                    : 'bg-gradient-to-r from-primary-500 to-accent-500 text-white hover:opacity-90'
                }`}
              >
                {plan.cta}
              </Link>
            </motion.div>
          ))}
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
