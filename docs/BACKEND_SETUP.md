# Backend Setup

Firebase project ID: `food-sbj`

## Required Firebase products

- Authentication
- Firestore
- Storage
- Cloud Functions
- Remote Config
- Analytics
- Crashlytics
- App Check

## Auth providers

Enable:

- Email/password
- Apple

Disable:

- Anonymous

## Secrets

Run from repository root:

```bash
firebase login
firebase use food-sbj
firebase functions:secrets:set OPENAI_API_KEY
firebase functions:secrets:set USDA_API_KEY
```

Do not place these values in Swift, Info.plist, GoogleService-Info.plist, or any checked-in file.

## Deploy

```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

## App Check

The iOS app uses `DeviceCheckProviderFactory` for App Check. Enable App Check enforcement for Functions, Firestore, and Storage only after you verify real-device calls are working.

## Rules

Initial authenticated-user rules are included. Harden them before TestFlight/App Store release.
