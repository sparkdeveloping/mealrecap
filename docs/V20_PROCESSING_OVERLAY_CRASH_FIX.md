# v20 Processing Overlay Crash Fix

Fixes the missing `ProcessingOverlay` component and makes the full-screen composer submit state update on the main actor.

## Changed

- `MealRecap/Views/Components/ProcessingOverlay.swift`
- `MealRecap/Views/Components/ChatComposer.swift`

## Why

The previous build referenced `ProcessingOverlay` but did not include the file. The full-screen composer also changed SwiftUI state while running async work. This build keeps submit-state and dismissal changes on `@MainActor`.

## Run

```bash
./scripts/generate-xcode-project.sh
rm -rf ~/Library/Developer/Xcode/DerivedData/MealRecap-*
```

Then rebuild in Xcode.
