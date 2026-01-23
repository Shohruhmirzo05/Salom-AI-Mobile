# Salom AI Android

This is the Flutter implementation of the Salom AI mobile application.

## Setup

1. **Install Flutter**: Make sure you have the Flutter SDK installed on your machine.
2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```
3. **Run the App**:
   ```bash
   flutter run
   ```

## Architecture

- **State Management**: default_api:read_resource{ } (Riverpod)
- **Navigation**: GoRouter
- **Networking**: Dio + Supabase Flutter

## structure
- `lib/core`: Shared utilities, constants, API client.
- `lib/features`: Feature-based modules (Auth, Chat, etc).
- `lib/models`: Data models.
