# Salom AI Mobile

Mobile applications for Salom AI - iOS and Android.

## Structure

- `Salom-Ai-iOS/` - Native iOS app built with Swift and SwiftUI
- `android/` - Android app

## iOS Setup

### Requirements
- Xcode 15.0 or later
- iOS 15.0 or later
- CocoaPods

### Installation

1. Navigate to the iOS directory:
```bash
cd Salom-Ai-iOS
```

2. Install dependencies:
```bash
pod install
```

3. Open the workspace:
```bash
open Salom-Ai-iOS.xcworkspace
```

4. Configure environment:
   - Add your API keys and configuration in the appropriate files
   - Update team signing settings in Xcode

5. Build and run the app in Xcode

## Android Setup

### Requirements
- Android Studio
- Gradle

### Installation

1. Navigate to the Android directory:
```bash
cd android
```

2. Open the project in Android Studio

3. Sync Gradle files and build the project

## Configuration

Make sure to configure the following:
- API endpoints (point to your backend)
- OAuth credentials
- Push notification keys
- Any other environment-specific settings

## Notes

- The iOS app supports Sign in with Apple
- Both apps communicate with the Salom AI backend API
- Make sure your backend is running before testing the mobile apps

## Related Repositories

- [Salom-AI Backend](https://github.com/Shohruhmirzo05/Salom-AI) - Backend, Web, and Admin Panel
- [Salom-AI Telegram Bot](https://github.com/Shohruhmirzo05/Salom-AI-TelegramBot) - Telegram bot
