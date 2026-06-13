# V25 Storage Bucket + Image Persistence Fix

This build fixes the point where Gemini successfully returns a JPEG but the app still shows the placeholder.

The logs showed `gemini.sdk.imageReceived`, so image generation works. The likely remaining failure was after image receipt, during Firebase Storage persistence or image cache writing.

Changes:

- Explicitly initializes Firebase Admin with `storageBucket: "food-sbj.firebasestorage.app"`.
- Uses the explicit Firebase Storage bucket everywhere instead of relying on Admin SDK default bucket inference.
- Adds detailed request-id logging around:
  - `storage.buffer.ready`
  - `storage.exists.start/done`
  - `storage.save.start/done`
  - `storage.mediaURL.ready`
  - `imageCache.write.start/done`
  - `image.persist.done`
- Avoids public ACLs / `makePublic()`.
- Stores both `photoPath` and a direct Firebase media URL in `foodImageCache`.

After deploying and adding a new meal, look for:

```bash
firebase functions:log --only mrv24AnalyzeMealText -n 100
```

Expected success sequence:

```text
gemini.sdk.imageReceived
storage.buffer.ready
storage.exists.start
storage.exists.done
storage.save.start
storage.save.done
storage.mediaURL.ready
imageCache.write.start
imageCache.write.done
image.done
analysis.text.done
```

If a storage step fails, the log will now show the exact line and message.
