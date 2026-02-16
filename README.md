# ezLander

A macOS menu bar AI assistant that connects to calendar and email, powered by Claude AI.

## Features

- **Natural Language Interface**: Chat with AI to manage your day
- **Calendar Integration**: Google Calendar & Apple Calendar support
- **Email Management**: Send, draft, and search emails via Gmail
- **Menu Bar App**: Always one click away
- **Privacy First**: Your data stays on your device

## Project Structure

```
ezLander/
├── macos-app/          # Native Swift/SwiftUI menu bar app
│   └── EzLander/
│       ├── Views/      # SwiftUI views
│       ├── Services/   # API integrations
│       └── Models/     # Data models
├── website/            # Next.js marketing site
│   ├── app/            # App router pages
│   ├── components/     # React components
│   └── lib/            # Utilities
└── shared/             # Shared types & config
```

## Tech Stack

| Component | Technology |
|-----------|------------|
| Mac App | Swift/SwiftUI |
| AI | Claude API |
| Calendar | Google Calendar + Apple Calendar |
| Email | Gmail API |
| Website | Next.js 14 + Tailwind CSS |
| Payments | Stripe |
| Auth | OAuth 2.0 + Sign in with Apple |

## Getting Started

### macOS App

1. Open `macos-app/EzLander.xcodeproj` in Xcode
2. Add your API keys:
   - Anthropic API key in Keychain
   - Google Cloud OAuth credentials
3. Build and run (Cmd+R)

### Website

```bash
cd website
npm install
cp .env.example .env.local
# Add your Stripe keys to .env.local
npm run dev
```

## Configuration

### Required API Keys

- **Anthropic API Key**: For Claude AI integration
- **Google Cloud Console**: OAuth 2.0 credentials for Calendar + Gmail
- **Stripe**: For subscription payments
- **Apple Developer Account**: For notarization and distribution

### Environment Variables (Website)

```env
STRIPE_SECRET_KEY=sk_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_MONTHLY_PRICE_ID=price_...
STRIPE_YEARLY_PRICE_ID=price_...
NEXT_PUBLIC_APP_URL=https://ezlander.app
```

## Pricing

- **Monthly**: $9.99/month
- **Yearly**: $99/year (save 17%)

Both plans include a free trial (7 days monthly, 14 days yearly).

## Development

### macOS App Requirements

- Xcode 15+
- macOS 13.0+ (Ventura)
- Swift 5.9+

### Website Requirements

- Node.js 18+
- npm or pnpm

## Building for Distribution

### App Notarization

```bash
# Build archive
xcodebuild -scheme EzLander -archivePath EzLander.xcarchive archive

# Export notarized app
xcodebuild -exportArchive -archivePath EzLander.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath build/

# Create DMG
create-dmg build/EzLander.app build/
```

### Website Deployment

```bash
cd website
npm run build
# Deploy to Vercel, Netlify, or your preferred platform
```

## License

Proprietary. All rights reserved.

## Support

- Email: support@ezlander.app
- Website: https://ezlander.app
