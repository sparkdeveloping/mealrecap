# MealRecap v23 — Google GenAI SDK Image Fix

This version fixes the Gemini image-generation failure shown in logs:

```text
Unknown name "responseModalities" at 'generation_config'
```

The backend now uses the official `@google/genai` SDK first, instead of hand-building a brittle REST payload. It also keeps a REST fallback without `generationConfig`.

## Changed

- `functions/src/index.ts`
- `functions/package.json`
- Removed `functions/node_modules`
- Removed `functions/package-lock.json`

## Deploy

```bash
npm config set registry https://registry.npmjs.org/

cd functions
rm -rf node_modules
rm -f package-lock.json
npm install --no-audit --no-fund
npm run build
cd ..

firebase deploy --only functions,firestore,storage
```

## Confirm

```bash
firebase functions:log --only mrv22AnalyzeMealText -n 100
firebase functions:log --only mrv22GenerateMealImage -n 100
firebase functions:log --only mrv22BackfillMealImages -n 100
```

Look for:

```text
gemini.sdk.request
gemini.sdk.imageReceived
storage.upload.done
image.done
```

If `gemini.sdk.failed` appears, the log will include the SDK error and model name.
