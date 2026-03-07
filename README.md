# ezLander

A macOS menu bar AI assistant that connects to your calendar and email with subscription-managed AI access built in.

![ezLander](https://img.shields.io/badge/macOS-13.0+-blue) ![Swift](https://img.shields.io/badge/Swift-5.9+-orange) ![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Managed AI Access**: Subscribers use ezLander's built-in server-side AI access
- **In-App Sign In**: Access the app from inside the menu bar popover
- **Natural Language Interface**: Chat with AI to manage your day
- **Calendar Integration**: Google Calendar & Apple Calendar support
- **Email Management**: Send, draft, and search emails via Gmail
- **Menu Bar App**: Always one click away
- **Auto-Updates**: Check for and download updates automatically
- **Privacy First**: Calendar and email integrations stay on-device unless required for the connected provider APIs

---

## Installation Guide

### Prerequisites

- **macOS 13.0** (Ventura) or later
- **Xcode 15+** (for building from source)
- **Apple Developer Account** (free account works for local development)

### Option 1: Download Pre-built Release

1. Go to [Releases](https://github.com/shahar-harell/ezLander/releases)
2. Download the latest `EzLander.dmg`
3. Open the DMG and drag EzLander to Applications
4. Launch EzLander from Applications

### Option 2: Build from Source

#### Step 1: Clone the Repository

```bash
git clone https://github.com/shahar-harell/ezLander.git
cd ezLander/macos-app
```

#### Step 2: Open in Xcode

```bash
open EzLander.xcodeproj
```

#### Step 3: Configure Code Signing

1. In Xcode, select the **EzLander** project in the navigator
2. Select the **EzLander** target
3. Go to **Signing & Capabilities** tab
4. Change **Team** to your Apple Developer account (or "None" for unsigned local builds)
5. Change **Bundle Identifier** to something unique (e.g., `com.yourname.ezlander`)

#### Step 4: Build and Run

Press `Cmd + R` to build and run the app. The app will appear in your menu bar.

#### Step 5: Install to Applications (Optional)

To install the built app to your Applications folder:

1. In Xcode, go to **Product > Archive**
2. In the Organizer window, click **Distribute App**
3. Select **Copy App** and save to your Applications folder

Or, for quick local testing:
```bash
# Find the built app
find ~/Library/Developer/Xcode/DerivedData -name "EzLander.app" -type d 2>/dev/null | head -1

# Copy to Applications (replace path with actual path from above)
cp -R "/path/to/EzLander.app" /Applications/
```

---

## Setup Guide

### 1. Sign In Inside the App

After launching ezLander:

1. Click the menu bar icon
2. Sign in or create your ezLander account from the in-app access screen
3. Subscribe on `ezlander.app` if your account does not already have an active plan
4. Return to the app and refresh access

Subscribers automatically use ezLander's managed AI access. There are no API keys or model settings to configure in the app.

### 2. Set Up Google Calendar & Gmail (Optional)

To enable calendar and email features, you need to create Google OAuth credentials:

#### Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project (or select existing one)
3. Enable these APIs:
   - **Google Calendar API**
   - **Gmail API**

#### Create OAuth Credentials

1. Go to **APIs & Services > Credentials**
2. Click **Create Credentials > OAuth client ID**
3. Choose **iOS** as application type
4. Set **Bundle ID** to: `com.ezlander.app` (or your custom bundle ID)
5. Download the credentials

#### Configure in ezLander

The app uses the default client ID for development. For production use, you'll need to update `OAuthService.swift` with your own client ID.

### 3. Connect Your Accounts

In the Settings:

1. Click **Connect** next to Google Calendar
2. Complete the OAuth flow in your browser
3. Gmail will be connected automatically (same OAuth scope)

For Apple Calendar:
1. Click **Connect** next to Apple Calendar
2. Grant calendar access permission when prompted

---

## Project Structure

```
ezLander/
├── macos-app/                    # Native Swift/SwiftUI menu bar app
│   └── EzLander/
│       ├── EzLanderApp.swift     # App entry point
│       ├── Views/
│       │   ├── MainPopover.swift # Main chat interface
│       │   ├── ChatView.swift    # Chat messages view
│       │   └── SettingsView.swift# Settings panel
│       ├── Services/
│       │   ├── AIService.swift   # Managed AI gateway
│       │   ├── ProxyAIService.swift
│       │   ├── GoogleCalendarService.swift
│       │   ├── AppleCalendarService.swift
│       │   ├── GmailService.swift
│       │   └── OAuthService.swift
│       └── Models/
├── website/                      # Next.js marketing site
│   ├── app/
│   │   ├── page.tsx              # Landing page
│   │   ├── pricing/page.tsx
│   │   └── download/page.tsx
│   └── components/
└── README.md
```

---

## Configuration

### Environment Variables (Website)

If running the website locally:

```env
STRIPE_SECRET_KEY=sk_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_MONTHLY_PRICE_ID=price_...
STRIPE_YEARLY_PRICE_ID=price_...
NEXT_PUBLIC_APP_URL=https://ezlander.app
```

---

## Troubleshooting

### "Google Calendar API has not been used in project"

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services > Library**
4. Search for "Google Calendar API" and enable it
5. Do the same for "Gmail API"
6. Wait a few minutes for changes to propagate
7. Reconnect in ezLander settings

### Calendar Shows "No Upcoming Events"

1. Make sure you've completed the Google OAuth flow
2. Check that Google Calendar API is enabled in your Google Cloud project
3. Try disconnecting and reconnecting Google Calendar

### Access Is Still Locked After Subscribing

1. Make sure you signed in inside the app with the same email used for billing
2. Complete checkout on `ezlander.app`
3. Return to the app and use **Refresh Access**

---

## Development

### Requirements

- Xcode 15+
- macOS 13.0+ (Ventura)
- Swift 5.9+

### Building

```bash
cd macos-app
xcodebuild -scheme EzLander -configuration Debug build
```

### Running Tests

```bash
xcodebuild -scheme EzLander test
```

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

MIT License - see [LICENSE](LICENSE) for details.

---

## Support

- **Issues**: [GitHub Issues](https://github.com/shahar-harell/ezLander/issues)
- **Website**: [ezlander.app](https://ezlander.app)
