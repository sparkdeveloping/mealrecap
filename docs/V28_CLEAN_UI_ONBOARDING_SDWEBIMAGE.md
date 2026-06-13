# MealRecap v28 Clean UI + Onboarding + Image Cache

This package is built from the currently working MealRecap project and focuses on polish rather than backend rewrites.

## Included

- Added missing `OnboardingView.swift`
- Onboarding for name, calorie goal, and optional HealthKit access
- Sticky glass top header with stacked `MEAL / RECAP` branding
- Fixed plus input menu wrapping and field jump behavior
- Fullscreen composer uses `Create` instead of vague `Add`
- Better animated processing ribbon in composer
- Removed dev-facing `Generate photos` feed action
- Added ambient bokeh layer
- Detail screen hides default navigation back button to prevent duplicate exit controls
- Replaced segmented meal-type picker with non-truncating chips
- Added SDWebImageSwiftUI package and WebImage caching for meal visuals
- Added `imageURL` support while keeping `photoPath` fallback

## Setup

```bash
./scripts/generate-xcode-project.sh
rm -rf ~/Library/Developer/Xcode/DerivedData/MealRecap-*
```

Open Xcode and let packages resolve.

## Backend

No backend deployment is required for this UI polish package unless you also changed functions separately.
