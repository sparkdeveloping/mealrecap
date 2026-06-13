# MealRecap v24 Official GenAI Image Rewrite

This build replaces the brittle Gemini REST image payload with the official `@google/genai` SDK path shown in Google’s current JavaScript image generation docs.

## Important changes

- Swift now calls fresh `mrv24*` endpoints.
- Backend image generation uses only `GoogleGenAI.models.generateContent`.
- Removed all manual REST image calls.
- Removed all `generationConfig.responseModalities` and `responseFormat` payloads.
- Image logs now include `gemini.sdk.request`, `gemini.sdk.response`, `gemini.sdk.imageReceived`, and `image.done`.
- Compatibility endpoints remain exported, but the app calls `mrv24*`.

## Deploy

```bash
npm config set registry https://registry.npmjs.org/

cd functions
rm -rf node_modules
rm -f package-lock.json
npm install --no-audit --no-fund
npm run build
node -e "require('./lib/index.js'); console.log('functions load ok')"
cd ..

firebase deploy --only functions,firestore,storage
```

## Check logs

```bash
firebase functions:log --only mrv24AnalyzeMealText -n 100
firebase functions:log --only mrv24GenerateMealImage -n 100
firebase functions:log --only mrv24BackfillMealImages -n 100
```

Look for:

```text
gemini.sdk.request
gemini.sdk.response
gemini.sdk.imageReceived
storage.upload.done
image.done
```
