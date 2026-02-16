import { NextRequest, NextResponse } from 'next/server'

export async function POST(request: NextRequest) {
  try {
    // Track download for analytics
    const userAgent = request.headers.get('user-agent') || 'unknown'
    const ip = request.headers.get('x-forwarded-for') || request.headers.get('x-real-ip') || 'unknown'

    console.log('Download tracked:', {
      timestamp: new Date().toISOString(),
      userAgent,
      ip: ip.split(',')[0], // First IP in chain
    })

    // You could store this in a database for analytics
    // await db.downloads.create({
    //   data: {
    //     userAgent,
    //     ip: ip.split(',')[0],
    //     timestamp: new Date(),
    //   },
    // })

    return NextResponse.json({ success: true })
  } catch (error) {
    console.error('Download tracking error:', error)
    return NextResponse.json(
      { error: 'Failed to track download' },
      { status: 500 }
    )
  }
}

export async function GET() {
  // Redirect to actual DMG file
  // In production, this would serve from your CDN or S3
  return NextResponse.redirect(
    'https://ezlander.app/releases/ezLander-latest.dmg'
  )
}
