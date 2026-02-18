import type { Metadata, Viewport } from 'next'
import { Inter } from 'next/font/google'
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
  description: 'Manage your calendar and email with natural language from your Mac menu bar. Supports OpenAI, Claude, Gemini, and Kimi.',
  keywords: ['AI assistant', 'macOS', 'menu bar', 'calendar', 'email', 'productivity', 'ChatGPT', 'Claude', 'Gemini'],
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
    description: 'Manage your calendar and email with natural language from your Mac menu bar. Supports OpenAI, Claude, Gemini, and Kimi.',
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
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <main className="min-h-screen">
          {children}
        </main>
      </body>
    </html>
  )
}
