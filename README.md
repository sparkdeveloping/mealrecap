# MealRecap

MealRecap is a production-first SwiftUI calorie-in / calorie-out food journal.

It uses Firebase as the live backend, OpenAI through Cloud Functions, USDA FoodData Central and Open Food Facts for nutrition, HealthKit for calories out, Speech for voice input, camera/photo analysis, and StoreKit 2 for subscriptions.

## Locked product direction

- App name: MealRecap
- Bundle ID: `com.sbj.mealrecap`
- Minimum iOS: `26.0`
- UI: SwiftUI, light mode only
- Backend: one Firebase project, no emulators
- Auth: Email/password + Sign in with Apple, no anonymous auth
- AI: OpenAI via Firebase Cloud Functions only
- Nutrition: USDA + Open Food Facts first
- Monetization: StoreKit 2 with hook-first freemium
- Design: premium editorial food journal, no generic AI gradients

## First-time setup

1. Install Xcode 26+.
2. Install XcodeGen:

```bash
brew install xcodegen
```

3. Generate the Xcode project:

```bash
cd MealRecap
./scripts/generate-xcode-project.sh
```

4. In Xcode, select the MealRecap target and set your Apple Developer Team.
5. Confirm the capabilities are enabled:
   - Sign in with Apple
   - HealthKit
6. In Firebase Console for project `food-sbj`, enable:
   - Authentication
   - Firestore
   - Storage
   - Functions
   - Remote Config
   - Analytics
   - Crashlytics
   - App Check
7. Enable Firebase Auth providers:
   - Email/password
   - Apple
   - Anonymous disabled
8. Configure backend secrets:

```bash
firebase login
firebase use food-sbj
firebase functions:secrets:set OPENAI_API_KEY
firebase functions:secrets:set USDA_API_KEY
```

9. Deploy backend functions:

```bash
firebase use food-sbj
firebase deploy --only functions
```

The deploy hook runs `npm install` and `npm run build` inside `functions` before deployment, so `functions/lib/index.js` is generated automatically.

10. Create App Store Connect subscription products:

- `com.sbj.mealrecap.pro.monthly`
- `com.sbj.mealrecap.pro.yearly`

## Security note

Do not put OpenAI or USDA keys in the iOS app. They belong only in Firebase Functions secrets.

The keys previously pasted in chat should be rotated before release because they have been exposed.

## Build note

This repository intentionally contains no mock data and no Firebase emulator configuration. Empty states are real empty states, and all AI/nutrition/photo flows call the live backend.


## v12 Open Local Auth

This build uses local-only app auth and does not require Firebase Auth, Firebase ID tokens, or App Check for the core MealRecap flow. Deploy functions, Firestore rules, and Storage rules after replacing files. See `docs/V12_OPEN_LOCAL_AUTH.md`.

## v22 public backend rewrite

MealRecap v22 uses fresh public HTTPS Cloud Functions named `mrv22*` to avoid old callable/authenticated Cloud Run state. See `docs/V22_PUBLIC_BACKEND_REWRITE_IMAGE_LOGGING.md` for deploy and logging commands.
# mealrecap
