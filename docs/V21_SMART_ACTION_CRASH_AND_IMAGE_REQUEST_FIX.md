# V21 — Smart Action Crash + Gemini Image Request Fix

This build fixes the add-entry crash seen during the “Analyzing and creating your meal…” state.

## Fixes

- Removed `Firestore.runTransaction` from `SmartActionService.consume`.
- Replaced it with a simple async read/write path to avoid the internal Firestore queue assertion crash on simulator.
- Updated Gemini image generation payload to use `generationConfig.responseModalities = ["TEXT", "IMAGE"]`.
- Removed the old assumption that image models work with an empty `generationConfig`.

## Notes

The console haptic warnings from the iOS simulator are not the crash. The relevant issue was the Firestore transaction queue assertion.

After deploying, test:

```bash
firebase functions:log --only generateMealImage -n 50
firebase functions:log --only backfillMealImages -n 50
```
