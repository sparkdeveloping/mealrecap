# MealRecap v14 — Editorial UI Upgrade

This build keeps the v13 public HTTP / local auth backend path and upgrades the SwiftUI experience.

## Design language

MealRecap now leans into a premium food-journal direction rather than a calorie-dashboard direction:

- editorial daily hero
- calories-in/out/net/goal balance meter
- macro meter deck
- meal constellation visuals
- horizontal food day strip
- image-led meal cards
- full meal detail sheet with macro bars and percent-of-day
- more polished floating dock
- softer glass composer

## Generated food images / Nano Banana direction

The app does not require generated food images to feel premium. v14 uses procedural food visuals so the UI works immediately without extra cost or latency.

When adding an image model later, use this product prompt shape from the backend for each meal:

```text
Create a single isolated studio food product image for a premium iOS nutrition journal.
Subject: {meal title}. Portion: {serving description}. Style: editorial Apple-like food photography, soft natural light, warm white background, porcelain plate when appropriate, realistic shadows, no hands, no utensils unless essential, centered object, transparent or near-white background, consistent scale, no text, no logo, no watermark.
```

Storage target:

```text
users/{localUserID}/mealVisuals/{yyyy-MM-dd}/{mealID}.png
```

The UI is designed so generated images can replace `MealVisual` later without changing the screen structure.
