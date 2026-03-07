import type { Metadata, Viewport } from 'next'
import { Inter } from 'next/font/google'
import SessionProvider from '@/components/SessionProvider'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const viewport: Viewport = {
  themeColor: [
    { media: '(prefers-color-scheme: light)', color: '#ffffff' },
    { media: '(prefers-color-scheme: dark)', color: '#0a0a0a' },
  ],
  colorScheme: 'light dark',
}

export const metadata: Metadata = {
  metadataBase: new URL('https://ezlander.app'),
  title: 'ezLander - AI Menu Bar Assistant for macOS',
  description: 'Manage your calendar and email with natural language from your Mac menu bar using ezLander’s subscription-managed AI access.',
  keywords: ['AI assistant', 'macOS', 'menu bar', 'calendar', 'email', 'productivity', 'subscription AI'],
  authors: [{ name: 'ezLander' }],
  creator: 'ezLander',
  publisher: 'ezLander',
  applicationName: 'ezLander',
  category: 'productivity',
  robots: { index: true, follow: true },
  alternates: {
    canonical: '/',
  },
  openGraph: {
    title: 'ezLander - AI Menu Bar Assistant for macOS',
    description: 'Manage your calendar and email with natural language from your Mac menu bar using ezLander’s subscription-managed AI access.',
    url: 'https://ezlander.app',
    siteName: 'ezLander',
    images: [
      {
        url: '/og-image.png',
        width: 1200,
        height: 630,
        alt: 'ezLander - AI Menu Bar Assistant for macOS',
      },
    ],
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'ezLander - AI Menu Bar Assistant for macOS',
    description: 'Manage your calendar and email with natural language from your Mac menu bar.',
    images: ['/og-image.png'],
  },
  icons: {
    icon: '/favicon.ico',
    apple: '/apple-touch-icon.png',
    shortcut: '/favicon.png',
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={`${inter.className} antialiased`}>
        <a
          href="#main-content"
          className="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 focus:z-[100] focus:px-4 focus:py-2 focus:bg-white focus:text-gray-900 focus:rounded-lg focus:shadow-lg focus:outline-none"
        >
          Skip to main content
        </a>
        <SessionProvider>
          <main id="main-content" className="min-h-screen">
            {children}
          </main>
        </SessionProvider>
      </body>
    </html>
  )
}
