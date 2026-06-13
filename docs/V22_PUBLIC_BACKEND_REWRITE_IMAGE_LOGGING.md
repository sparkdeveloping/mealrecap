# MealRecap v22 — Public Backend Rewrite + Image Logging

This build rewrites the backend request path so the iOS app uses brand-new public HTTPS functions instead of the old callable/auth Cloud Run services.

## Why this version exists

The previous logs showed requests were being rejected before app code ran:

- `The request was not authenticated`
- `Empty Authorization header value`
- older deploy metadata still showed callable/auth behavior

v22 avoids that by using fresh function names:

- `mrv22Ping`
- `mrv22AnalyzeMealText`
- `mrv22AnalyzeDayRecap`
- `mrv22AnalyzeMealPhoto`
- `mrv22GenerateMealImage`
- `mrv22BackfillMealImages`

The old function names are still exported for compatibility, but the iOS app now calls the v22 names.

## Image logging

Every request now receives a request id, for example:

```text
[7A1F2C99] mrv22AnalyzeMealText request.start
[7A1F2C99] mrv22AnalyzeMealText analysis.openai.done
[7A1F2C99] mrv22AnalyzeMealText image.cache.lookup
[7A1F2C99] mrv22AnalyzeMealText gemini.request
[7A1F2C99] mrv22AnalyzeMealText gemini.imageReceived
[7A1F2C99] mrv22AnalyzeMealText storage.upload.done
[7A1F2C99] mrv22AnalyzeMealText image.done
[7A1F2C99] mrv22AnalyzeMealText request.success
```

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

## Verify functions exist

```bash
firebase functions:list
```

You should see the `mrv22*` functions.

## Watch image logs

Text meal image flow:

```bash
firebase functions:log --only mrv22AnalyzeMealText -n 100
```

Single image generation:

```bash
firebase functions:log --only mrv22GenerateMealImage -n 100
```

Backfill:

```bash
firebase functions:log --only mrv22BackfillMealImages -n 100
```

## If public access still gets blocked

Open Google Cloud Shell and run:

```bash
gcloud config set project food-sbj

gcloud run services add-iam-policy-binding mrv22analyzemealtext \
  --region us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker"

gcloud run services add-iam-policy-binding mrv22analyzedayrecap \
  --region us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker"

gcloud run services add-iam-policy-binding mrv22analyzemealphoto \
  --region us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker"

gcloud run services add-iam-policy-binding mrv22generatemealimage \
  --region us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker"

gcloud run services add-iam-policy-binding mrv22backfillmealimages \
  --region us-central1 \
  --member="allUsers" \
  --role="roles/run.invoker"
```

Then retry the app.

## What changed

- Fresh public HTTPS endpoint names to escape old callable/auth Cloud Run state.
- iOS calls v22 endpoints only.
- Request-id based logs across OpenAI, Gemini, cache, Storage, and Firestore.
- Fixed `crypto.randomUUID()` runtime bug by using `randomUUID` from Node crypto.
- Added Gemini model fallback logging.
- Added image cache hit/miss logging.
- Added Storage upload byte/path logging.
