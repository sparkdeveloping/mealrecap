# App Review Checklist

## Bundle Identity

- Main bundle ID: `com.denzeltinashe.mealrecap`
- Display name: `MealRecap`
- Signing team: set in Xcode to the new Apple Developer Team before archive. The old team ID was removed from project build settings.


## Product IDs

MealRecap Pro subscriptions are centralized in `MealRecapProductID`:

- Weekly: `com.denzeltinashe.mealrecap.pro.weekly`
- Monthly: `com.denzeltinashe.mealrecap.pro.monthly`
- Yearly: `com.denzeltinashe.mealrecap.pro.yearly`

Prices and subscription periods are read from StoreKit `Product.displayPrice` and `Product.subscription`.

## Paywall Locations

- Header Pro button opens `PaywallView`.
- Profile Upgrade to Pro opens `PaywallView`.
- Smart action limits open `PaywallView` through `AppModel.markPaywallMilestoneIfNeeded`.
- Snap/Say/Day recap checks use `AppModel` entitlement and smart-action gating.

## Legal Links

`PaywallView` includes:

- Privacy Policy: `https://mealrecap.app/privacy`
- Terms of Use / EULA: Apple standard EULA, `https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`
- Restore purchases
- Not now
- Auto-renewal subscription note

Profile also links Privacy Policy, Terms of Use, Health & Nutrition Disclaimer, Support, and account deletion help.

## Apple Health Disclosure

Apple Health is kept in this build. The app reads active energy and related fitness data only after user opt-in.

Disclosure locations:

- Onboarding optional connections step: `Connect Apple Health`
- Profile: `Connect Apple Health` card
- Home stats: card labels Apple Health / Connect Apple Health / Active energy / unavailable states

Info.plist Health description matches read-only usage.

## Firebase Migration

- Expected Firebase iOS app bundle ID: `com.denzeltinashe.mealrecap`
- Local `GoogleService-Info.plist` must be replaced with the file downloaded from Firebase for the new iOS app registration before archive.
- Confirm the downloaded plist has `BUNDLE_ID = com.denzeltinashe.mealrecap`.
- Confirm `GOOGLE_APP_ID`, `CLIENT_ID`, and `REVERSED_CLIENT_ID` match the new Firebase iOS app if those keys are present.
- Firebase project may remain `food-sbj` if the backend/Auth/Firestore data are intentionally shared.
- Firebase config audit date: 2026-06-23.

## Test Account

- App Review test account: add current credentials in App Store Connect Review Notes.
- Confirm fresh install sign-in, sign-out, and Firestore meal save work with the new bundle ID.

## Testing Pro Purchase and Restore

1. Launch app with StoreKit configuration or sandbox account.
2. Open paywall from header/profile/smart-action limit.
3. Confirm weekly, monthly, yearly plans show length and StoreKit price.
4. Purchase a plan and verify paywall dismisses and Profile/Header show Pro.
5. Relaunch and verify cached Pro remains active while StoreKit refreshes.
6. Restore purchases from paywall and Profile.
7. Verify no active subscription state is user-friendly.
8. Verify unavailable products show Try again, Restore purchases, and Not now.
9. Confirm the local StoreKit configuration contains the same weekly/monthly/yearly product IDs as `MealRecapProductID`.

## Testing Snap / Say / Day Recap

- Snap: choose photo, analyze, review portion, Add to today. Cancel before add should not save.
- Say: enter voice recap text, analyze, review, Add to today. Cancel before add should not save.
- Day recap: submit day text, Review day, deselect a meal, adjust portions, Add selected meals.
- Free users should spend actions only after reviewed save succeeds.
- Pro users should not see paywalls for Snap/Say/Day recap and should not decrement smart actions.
