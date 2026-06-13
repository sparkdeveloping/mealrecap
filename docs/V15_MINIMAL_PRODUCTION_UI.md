# MealRecap v15 — Minimal Production UI

This version keeps the working v13 public HTTP backend path and focuses on the app experience.

## Product/UI changes

- Removed the always-visible bottom-right vertical dock from the main Day screen.
- Top-left is now the MealRecap brand.
- Top-right is the calendar button.
- Upgrade is visible through the FREE/PRO badge and the composer action tray.
- Bottom composer is the primary interaction surface.
- The plus button spring-expands into Snap, Say, Recap, and Pro actions.
- Meals are compact rows instead of oversized cards.
- Daily summary is less card-heavy and more editorial/minimal.
- Added a compact balance meter showing calories in/out/goal progress.
- Real food photos are shown from Firebase Storage when `meal.photoPath` exists.
- Text-only logs use a quiet placeholder, not emoji/icon food art.

## Image direction

The UI is now real-photo-first. If the user snaps a plate, that actual photo becomes the meal visual.

For generated images later, wire an image endpoint to create consistent studio food cutouts only when there is no real user photo. Do not replace real meal photos with generated images.

## Files changed

- `MealRecap/Views/Home/DayView.swift`
- `MealRecap/Views/Home/Sections.swift`
- `MealRecap/Views/Components/MealCard.swift`
- `MealRecap/Views/Components/MealVisual.swift`
- `MealRecap/Views/Components/ChatComposer.swift`

`AppModel.swift` was intentionally not touched in v15.
