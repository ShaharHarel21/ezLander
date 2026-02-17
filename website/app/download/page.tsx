'use client'

import { useState } from 'react'
import Link from 'next/link'
import Navbar from '@/components/Navbar'
import Footer from '@/components/Footer'

const systemRequirements = [
  'macOS 13.0 (Ventura) or later',
  'Apple Silicon or Intel processor',
  '50 MB of available disk space',
  'Internet connection for AI features',
]

const installSteps = [
  'Download the ZIP file from GitHub',
  'Extract the ZIP and drag ezLander.app to Applications',
  'Right-click the app and select "Open" on first launch',
  'Click "Allow" when prompted for accessibility permissions',
  'Sign in with your Google account',
  'Start using ezLander from your menu bar!',
]

// GitHub releases URL - direct link to v1.2.0
const DOWNLOAD_URL = 'https://github.com/ShaharHarel21/ezLander/releases/download/v1.2.0/EzLander-v1.2.0.zip'
const RELEASES_PAGE = 'https://github.com/ShaharHarel21/ezLander/releases'

export default function DownloadPage() {
  const [isDownloading, setIsDownloading] = useState(false)

  const handleDownload = () => {
    setIsDownloading(true)
    // Track download (optional)
    fetch('/api/download', { method: 'POST' }).catch(() => {})
    // Start actual download from GitHub
    window.location.href = DOWNLOAD_URL
    setTimeout(() => setIsDownloading(false), 3000)
  }

  return (
    <>
      <Navbar />
      <main className="pt-32 pb-20 px-4 sm:px-6 lg:px-8">
        <div className="max-w-4xl mx-auto">
          {/* Header */}
          <div className="text-center mb-12">
            <h1 className="text-4xl sm:text-5xl font-bold mb-4">
              Download ezLander
            </h1>
            <p className="text-xl text-gray-600 dark:text-gray-400">
              Get started in less than a minute
            </p>
          </div>

          {/* Download card */}
          <div className="bg-white dark:bg-gray-800 rounded-2xl shadow-xl p-8 mb-12">
            <div className="flex flex-col md:flex-row items-center gap-8">
              {/* App icon */}
              <div className="w-32 h-32 bg-gradient-to-br from-primary-500 to-accent-500 rounded-3xl flex items-center justify-center shadow-lg">
                <svg
                  className="w-16 h-16 text-white"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={1.5}
                    d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"
                  />
                </svg>
              </div>

              {/* Download info */}
              <div className="flex-1 text-center md:text-left">
                <h2 className="text-2xl font-bold mb-2">ezLander for macOS</h2>
                <p className="text-gray-600 dark:text-gray-400 mb-4">
                  Version 1.2.0 • ~1 MB
                </p>
                <button
                  onClick={handleDownload}
                  disabled={isDownloading}
                  className="inline-flex items-center gap-2 px-8 py-4 bg-gradient-to-r from-primary-500 to-accent-500 text-white rounded-xl font-semibold text-lg hover:opacity-90 transition-opacity disabled:opacity-50"
                >
                  {isDownloading ? (
                    <>
                      <svg
                        className="animate-spin w-5 h-5"
                        fill="none"
                        viewBox="0 0 24 24"
                      >
                        <circle
                          className="opacity-25"
                          cx="12"
                          cy="12"
                          r="10"
                          stroke="currentColor"
                          strokeWidth="4"
                        />
                        <path
                          className="opacity-75"
                          fill="currentColor"
                          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                        />
                      </svg>
                      Downloading...
                    </>
                  ) : (
                    <>
                      <svg
                        className="w-5 h-5"
                        fill="none"
                        stroke="currentColor"
                        viewBox="0 0 24 24"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"
                        />
                      </svg>
                      Download for macOS
                    </>
                  )}
                </button>
              </div>
            </div>

            {/* Trial info */}
            <div className="mt-8 p-4 bg-primary-50 dark:bg-primary-900/20 rounded-xl">
              <div className="flex items-center gap-3">
                <svg
                  className="w-6 h-6 text-primary-600 dark:text-primary-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                  />
                </svg>
                <p className="text-primary-800 dark:text-primary-200">
                  Includes a <strong>7-day free trial</strong>. No credit card required.
                </p>
              </div>
            </div>
          </div>

          {/* Installation instructions */}
          <div className="grid md:grid-cols-2 gap-8">
            {/* Steps */}
            <div className="bg-white dark:bg-gray-800 rounded-2xl p-8">
              <h3 className="text-xl font-bold mb-6">Installation</h3>
              <ol className="space-y-4">
                {installSteps.map((step, index) => (
                  <li key={index} className="flex items-start gap-4">
                    <span className="flex-shrink-0 w-8 h-8 bg-primary-100 dark:bg-primary-900/30 text-primary-600 dark:text-primary-400 rounded-full flex items-center justify-center font-semibold">
                      {index + 1}
                    </span>
                    <span className="text-gray-700 dark:text-gray-300 pt-1">
                      {step}
                    </span>
                  </li>
                ))}
              </ol>
            </div>

            {/* System requirements */}
            <div className="bg-white dark:bg-gray-800 rounded-2xl p-8">
              <h3 className="text-xl font-bold mb-6">System Requirements</h3>
              <ul className="space-y-4">
                {systemRequirements.map((req, index) => (
                  <li key={index} className="flex items-center gap-3">
                    <svg
                      className="w-5 h-5 text-green-500 flex-shrink-0"
                      fill="currentColor"
                      viewBox="0 0 20 20"
                    >
                      <path
                        fillRule="evenodd"
                        d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"
                        clipRule="evenodd"
                      />
                    </svg>
                    <span className="text-gray-700 dark:text-gray-300">{req}</span>
                  </li>
                ))}
              </ul>

              {/* Security note */}
              <div className="mt-8 p-4 bg-gray-50 dark:bg-gray-700/50 rounded-xl">
                <div className="flex items-start gap-3">
                  <svg
                    className="w-5 h-5 text-gray-500 mt-0.5"
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <path
                      strokeLinecap="round"
                      strokeLinejoin="round"
                      strokeWidth={2}
                      d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"
                    />
                  </svg>
                  <div>
                    <p className="font-medium text-gray-900 dark:text-white">
                      Notarized by Apple
                    </p>
                    <p className="text-sm text-gray-600 dark:text-gray-400">
                      ezLander is signed and notarized by Apple, ensuring it's safe to install.
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Help section */}
          <div className="mt-12 text-center space-y-2">
            <p className="text-gray-600 dark:text-gray-400">
              <a
                href={RELEASES_PAGE}
                target="_blank"
                rel="noopener noreferrer"
                className="text-primary-600 dark:text-primary-400 hover:underline"
              >
                View all releases on GitHub
              </a>
            </p>
            <p className="text-gray-600 dark:text-gray-400">
              Need help?{' '}
              <Link
                href="mailto:support@ezlander.app"
                className="text-primary-600 dark:text-primary-400 hover:underline"
              >
                Contact support
              </Link>
            </p>
          </div>
        </div>
      </main>
      <Footer />
    </>
  )
}
