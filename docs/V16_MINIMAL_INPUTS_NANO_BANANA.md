# MealRecap v16 — Minimal Inputs + Nano Banana Images

## UI direction

This build moves MealRecap away from bulky cards and the always-visible right-side input dock.

Changes:

- Top-left is the app name: `MealRecap`.
- Top-right is the calendar button.
- The day is a clean, scrollable journal with a large calorie number, one thin progress meter, macro line, and compact stats.
- Meals are compact rows instead of cards.
- The bottom input is one text field with a springy plus button.
- The plus button expands into Snap / Say / Recap / Pro.
- Content can scroll underneath the bottom input and beyond the safe area instead of feeling boxed in.
- Fake emoji food art was removed. Meal visuals now prefer real/generated Firebase Storage images.

## Nano Banana / Gemini image generation

The backend now supports Gemini native image generation for MealRecap food visuals.

Set the extra Firebase secret before deploying functions:

```bash
firebase functions:secrets:set GEMINI_API_KEY
```

Then deploy:

```bash
npm config set registry https://registry.npmjs.org/
rm -rf functions/node_modules
rm -f functions/package-lock.json

cd functions
npm install --no-audit --no-fund
npm run build
node -e "require('./lib/index.js'); console.log('functions load ok')"
cd ..

firebase use food-sbj
firebase deploy --only functions,firestore,storage
```

## What the backend does

- Text meal logs are parsed by OpenAI.
- Nutrition hints still use USDA + Open Food Facts.
- After parsing, the backend asks Gemini image generation to create a premium 1:1 photoreal food image.
- The generated image is saved to Firebase Storage under:

```text
users/{localUserId}/generatedMealImages/{yyyy-MM-dd}/...
```

- The returned meal includes `photoPath`, which the iOS app displays with `MealVisual`.
- For camera logs, the uploaded user photo is used as reference and the backend attempts to generate a clean studio-style version of the same food.

## Important

This still uses the current open/local-auth backend mode from v13-v15. Auth/App Check/rules can be tightened later after the product flow and UI are settled.
