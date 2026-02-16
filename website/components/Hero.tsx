'use client'

import { motion } from 'framer-motion'
import Link from 'next/link'

export default function Hero() {
  return (
    <section className="relative pt-32 pb-20 px-4 sm:px-6 lg:px-8 overflow-hidden">
      {/* Background gradient */}
      <div className="absolute inset-0 bg-gradient-to-b from-primary-50 to-transparent dark:from-primary-950/30 dark:to-transparent -z-10" />

      {/* Decorative blobs */}
      <div className="absolute top-20 left-10 w-72 h-72 bg-primary-300 rounded-full mix-blend-multiply filter blur-xl opacity-30 animate-float" />
      <div className="absolute top-40 right-10 w-72 h-72 bg-accent-300 rounded-full mix-blend-multiply filter blur-xl opacity-30 animate-float" style={{ animationDelay: '2s' }} />

      <div className="max-w-7xl mx-auto">
        <div className="text-center">
          {/* Badge */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5 }}
          >
            <span className="inline-flex items-center gap-2 px-4 py-2 bg-primary-100 dark:bg-primary-900/30 text-primary-700 dark:text-primary-300 rounded-full text-sm font-medium">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-primary-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-primary-500"></span>
              </span>
              Now available for macOS
            </span>
          </motion.div>

          {/* Headline */}
          <motion.h1
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.1 }}
            className="mt-8 text-5xl sm:text-6xl lg:text-7xl font-bold tracking-tight"
          >
            Your AI assistant
            <br />
            <span className="gradient-text">in the menu bar</span>
          </motion.h1>

          {/* Subheadline */}
          <motion.p
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.2 }}
            className="mt-6 text-xl text-gray-600 dark:text-gray-400 max-w-2xl mx-auto"
          >
            Manage your calendar and email with natural language. Just click the menu bar, type what you need, and let AI handle the rest.
          </motion.p>

          {/* CTA Buttons */}
          <motion.div
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.5, delay: 0.3 }}
            className="mt-10 flex flex-col sm:flex-row gap-4 justify-center"
          >
            <Link
              href="/download"
              className="inline-flex items-center justify-center gap-2 px-8 py-4 bg-gradient-to-r from-primary-500 to-accent-500 text-white rounded-xl font-semibold text-lg hover:opacity-90 transition-opacity shadow-lg shadow-primary-500/25"
            >
              <svg className="w-5 h-5" fill="currentColor" viewBox="0 0 24 24">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
              </svg>
              Download for macOS
            </Link>
            <Link
              href="#features"
              className="inline-flex items-center justify-center gap-2 px-8 py-4 bg-white dark:bg-gray-800 text-gray-900 dark:text-white rounded-xl font-semibold text-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors border border-gray-200 dark:border-gray-700"
            >
              Learn more
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
              </svg>
            </Link>
          </motion.div>

          {/* App Preview */}
          <motion.div
            initial={{ opacity: 0, y: 40 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.7, delay: 0.4 }}
            className="mt-16 relative"
          >
            <div className="relative mx-auto max-w-4xl">
              {/* Shadow/glow effect */}
              <div className="absolute -inset-4 bg-gradient-to-r from-primary-500 to-accent-500 rounded-2xl blur-2xl opacity-20" />

              {/* App screenshot placeholder */}
              <div className="relative bg-gray-900 rounded-2xl overflow-hidden shadow-2xl border border-gray-800">
                {/* Menu bar */}
                <div className="h-8 bg-gray-800 flex items-center px-4 gap-2">
                  <div className="flex gap-1.5">
                    <div className="w-3 h-3 rounded-full bg-red-500" />
                    <div className="w-3 h-3 rounded-full bg-yellow-500" />
                    <div className="w-3 h-3 rounded-full bg-green-500" />
                  </div>
                  <div className="flex-1" />
                  <div className="flex items-center gap-4 text-gray-400 text-xs">
                    <span>Mon Oct 23</span>
                    <span>10:30 AM</span>
                    <div className="w-4 h-4 bg-gradient-to-br from-primary-500 to-accent-500 rounded" />
                  </div>
                </div>

                {/* App content */}
                <div className="p-8 bg-gradient-to-b from-gray-900 to-gray-950">
                  <div className="bg-gray-800/50 rounded-xl p-6 backdrop-blur">
                    <div className="flex items-start gap-4">
                      <div className="w-10 h-10 bg-gradient-to-br from-primary-500 to-accent-500 rounded-lg flex items-center justify-center flex-shrink-0">
                        <svg className="w-6 h-6 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z" />
                        </svg>
                      </div>
                      <div className="flex-1">
                        <div className="text-white font-medium">ezLander</div>
                        <div className="text-gray-400 text-sm mt-1">How can I help you today?</div>
                      </div>
                    </div>

                    <div className="mt-6 space-y-4">
                      <div className="flex justify-end">
                        <div className="bg-primary-500 text-white px-4 py-2 rounded-2xl rounded-br-md max-w-xs">
                          Schedule a meeting with John tomorrow at 2pm
                        </div>
                      </div>
                      <div className="flex justify-start">
                        <div className="bg-gray-700 text-white px-4 py-2 rounded-2xl rounded-bl-md max-w-sm">
                          Done! I've created "Meeting with John" for tomorrow at 2:00 PM on your Google Calendar.
                        </div>
                      </div>
                    </div>

                    <div className="mt-6">
                      <div className="flex items-center gap-2 bg-gray-700/50 rounded-lg px-4 py-3">
                        <input
                          type="text"
                          placeholder="Ask me anything..."
                          className="flex-1 bg-transparent text-white placeholder-gray-500 outline-none text-sm"
                          disabled
                        />
                        <button className="w-8 h-8 bg-gradient-to-r from-primary-500 to-accent-500 rounded-lg flex items-center justify-center">
                          <svg className="w-4 h-4 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 12h14M12 5l7 7-7 7" />
                          </svg>
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </motion.div>

          {/* Social proof */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ duration: 0.5, delay: 0.6 }}
            className="mt-16 flex flex-col items-center"
          >
            <p className="text-sm text-gray-500 dark:text-gray-400">Trusted by professionals worldwide</p>
            <div className="mt-4 flex items-center gap-8 opacity-50">
              <span className="text-2xl font-bold text-gray-400">Google</span>
              <span className="text-2xl font-bold text-gray-400">Apple</span>
              <span className="text-2xl font-bold text-gray-400">Stripe</span>
            </div>
          </motion.div>
        </div>
      </div>
    </section>
  )
}
