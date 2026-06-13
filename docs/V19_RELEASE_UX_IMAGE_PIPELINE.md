# MealRecap v19 — Release UX + Image Reliability

This build keeps the open/local auth path and focuses on the actual user experience:

- Meal entry now shows a full-screen white composition stage while typing.
- The composer suggests up to 3 repeated meals/prompts.
- Submitting shows a visible animated progress state so users never wait blindly.
- The bottom input remains minimal: field + springy plus button.
- The plus button expands into Snap, Say, Recap, and Pro.
- Meal rows are grouped by intelligent time sections: Morning, Midday, Afternoon, Evening, Late.
- Meal notes/descriptions are hidden from the feed and moved into the detail screen.
- Tapping a meal opens a full-screen detail/editor.
- Meal detail uses SwiftUI zoom navigation transition from the meal row source.
- Day swiping uses a smoother spring animation.
- Profile now shows cumulative stats, not just today's stats.
- Meal images retry through multiple Gemini/Nano Banana model IDs and API versions.
- Meal image REST payload was simplified to match Google’s current REST examples.
- MealVisual now retries loading when photoPath changes from nil to generated path.

## Critical image fix

The previous MealVisual had a subtle bug: it marked the URL as already requested even when the meal had no photo path yet. When Firestore later updated the meal with a generated `photoPath`, the view refused to fetch the new Storage URL. v19 removes that stale guard.

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

Make sure the Gemini secret exists:

```bash
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions
```

## Check images

```bash
firebase functions:list
firebase functions:log --only generateMealImage -n 50
firebase functions:log --only backfillMealImages -n 50
```

If generated images still do not appear, check for:

- 401/403: wrong key, disabled API, billing/project restriction.
- 404: model unavailable to your account/project.
- 429: quota/rate limit.
- no inline image: Gemini returned text only; v19 logs model + API version for every failed attempt.
