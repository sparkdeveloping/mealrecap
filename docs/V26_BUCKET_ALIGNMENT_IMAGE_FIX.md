# V26 Bucket Alignment Image Fix

The verified Firebase Storage bucket is `food-sbj.appspot.com`.

This patch aligns both backend Admin SDK and iOS Firebase Storage SDK with that bucket:

- `functions/src/index.ts` uses `initializeApp({ storageBucket: "food-sbj.appspot.com" })`
- `MealRecap/Resources/GoogleService-Info.plist` uses `STORAGE_BUCKET = food-sbj.appspot.com`
- `MealVisual.swift` logs the active bucket/path and supports both Storage paths and direct HTTPS URLs

After deploying, add a new meal and check logs for:

```text
storage.persist.enter
storage.buffer.ready
storage.bucket.ready
storage.save.done
imageCache.write.done
image.done
```

Then rebuild the app so the corrected plist is bundled into the app. Delete the simulator app before running again so the old Firebase options cannot linger.
