import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'ezLander - AI Assistant for Calendar & Email',
  description: 'Your AI-powered menu bar assistant for macOS. Manage your calendar and email with natural language.',
  keywords: ['AI assistant', 'macOS', 'menu bar', 'calendar', 'email', 'productivity'],
  authors: [{ name: 'ezLander' }],
  openGraph: {
    title: 'ezLander - AI Assistant for Calendar & Email',
    description: 'Your AI-powered menu bar assistant for macOS. Manage your calendar and email with natural language.',
    url: 'https://ezlander.app',
    siteName: 'ezLander',
    images: [
      {
        url: 'https://ezlander.app/og-image.png',
        width: 1200,
        height: 630,
      },
    ],
    locale: 'en_US',
    type: 'website',
  },
  twitter: {
    card: 'summary_large_image',
    title: 'ezLander - AI Assistant for Calendar & Email',
    description: 'Your AI-powered menu bar assistant for macOS.',
    images: ['https://ezlander.app/og-image.png'],
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
