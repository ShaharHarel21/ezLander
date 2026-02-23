# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

### macOS App (Swift/SwiftUI)
```bash
cd macos-app
open EzLander.xcodeproj          # Open in Xcode, then Cmd+R to run
xcodebuild -scheme EzLander -configuration Debug build   # CLI build
xcodebuild -scheme EzLander test                          # Run tests
```
- Requires Xcode 15+, macOS 13.0+ deployment target, Swift 5.9+
- Code signing must be configured in Xcode (Signing & Capabilities tab)

### Website (Next.js)
```bash
cd website
npm install
npm run dev      # Local dev server
npm run build    # Production build
npm run lint     # ESLint
```

## Architecture

### macOS App (`macos-app/EzLander/`)

**Entry point**: `EzLanderApp.swift` — SwiftUI `@main` app with `AppDelegate` that manages both dock icon (`.regular` activation policy) and menu bar icon via `MenuBarController`.

**UI layer**: `MenuBarController` owns an `NSPopover` hosting `MainPopover`, which is a tab-based SwiftUI view (chat, calendar, email, settings). The popover is 400x500px. Views use `@StateObject` ViewModels colocated in the same file (e.g., `CalendarViewModel` lives inside `CalendarView.swift`, `SettingsViewModel` inside `SettingsView.swift`).

**Services layer** (`Services/`): All services are singletons accessed via `.shared`. Key services:
- `AIService` — provider router; delegates to `OpenAIService`, `ClaudeService`, `GeminiService`, `KimiService`
- `OAuthService` — Google/Apple sign-in; handles URL callbacks via `com.ezlander.app` custom scheme
- `ClaudeOAuthService` — separate OAuth flow for Claude accounts
- `GoogleCalendarService`, `AppleCalendarService` — conform to `CalendarEventProvider` protocol
- `GmailService` — email operations
- `KeychainService` — API key storage
- `UpdateService` — GitHub releases-based auto-update (not Sparkle framework, despite appcast.xml)
- `KeyboardShortcutService` — global hotkeys

**Models** (`Models/`): `CalendarEvent` (with `CalendarEventProvider` protocol), `Email`, `User`.

**Theming**: `Theme.swift` defines color constants (`Color.warmPrimary`, `.warmAccent`, etc.) and `WarmGradientButtonStyle`. Brand colors are blue-to-purple gradient.

**State persistence**: `UserDefaults` for preferences, `KeychainService` for API keys.

### Website (`website/`)

Next.js 14 with TypeScript, Tailwind CSS, Framer Motion. Stripe integration for subscriptions. The `public/appcast.xml` is the Sparkle-format update feed consumed by the macOS app.

## Claude for Chrome
- Use `read_page` to get element refs from the accessibility tree
- Use `find` to locate elements by description
- Click/interact using `ref`, not coordinates
- NEVER take screenshots unless explicitly requested by the user
