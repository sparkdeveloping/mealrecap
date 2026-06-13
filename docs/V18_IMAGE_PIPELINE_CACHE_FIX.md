# V18 — Production Meal Image Pipeline

This build replaces the broken Gemini image request body that caused:

```text
Unknown name "responseFormat" at 'generation_config'
```

## What changed

- Removed deprecated/invalid `generationConfig.responseFormat`.
- Uses Gemini image generation with `generationConfig.responseModalities = ["Image"]`.
- Adds `generateMealImage` as a public HTTPS function for single-image testing and future UI actions.
- Keeps `backfillMealImages` for existing meals.
- Adds image caching so repeated meals reuse the same generated image instead of paying repeatedly.
- Saves generated images under `generatedFoodImages/`.
- Stores cache metadata in Firestore under `foodImageCache/{cacheKey}`.
- Backfill now replaces old raw uploaded meal photo paths with refined generated images.
- Camera/photo analysis now preserves generated `result.photoPath` over the raw uploaded photo path.
- iOS HTTP timeout increased for slower image generation/backfill.

## Deploy

```bash
./scripts/generate-xcode-project.sh

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

## Verify the new function exists

```bash
firebase functions:list
```

You should now see:

```text
generateMealImage
backfillMealImages
analyzeMealText
analyzeDayRecap
analyzeMealPhoto
ping
```

## Backfill existing meals

In the app, open Profile → Generate missing meal photos.

Then check logs:

```bash
firebase functions:log --only backfillMealImages -n 50
```

## Expected behavior

- New text meals return `photoPath` immediately when Gemini succeeds.
- New day recap meals return `photoPath` per generated meal.
- New photo meals use the uploaded image as a reference, then save the generated studio image.
- Existing meals without images can be backfilled.
- Existing raw user meal photos can be refined into generated studio images.
- Repeated meals reuse cached generated images.

## If images still do not show

Check:

```bash
firebase functions:log --only backfillMealImages -n 50
firebase functions:log --only generateMealImage -n 50
```

A 400 response from Gemini means request format/model issue.
A 401/403 response means Gemini key/billing/project access issue.
A 429 response means quota or billing limit.
