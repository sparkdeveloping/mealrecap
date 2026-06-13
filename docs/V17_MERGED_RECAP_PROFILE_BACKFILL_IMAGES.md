# MealRecap v17 — Merged Recap, Profile, and Backfill Images

This build keeps the public HTTPS/local-auth backend path and focuses on simplifying the product experience.

## UI changes

- Recap is no longer a separate section below meals.
- The user prompt is shown as a small green bubble above the meal it generated.
- Assistant notes are shown directly under the related meal row.
- The meal list is minimal and journal-like, with no heavy cards.
- Top-left stays `MealRecap`.
- Top-right now has Calendar and Profile buttons.
- Bottom composer remains a text field with a springy plus button.

## Profile screen

The Profile screen includes:

- Daily stats
- Upgrade / Pro entry point
- Restore purchases
- Generate missing meal photos
- Privacy Policy
- Terms of Use
- Health & Nutrition Disclaimer
- Sign out
- Delete account and current local user data

The legal text is in-app placeholder legal copy for development. Replace it with your final hosted legal documents before App Store submission.

## Meal images

New text/photo/day recap logs already ask the backend to generate a clean photorealistic generated meal image using the Gemini/Nano Banana path when `GEMINI_API_KEY` is configured.

Existing meals without `photoPath` are now backfillable through the new backend function:

- `backfillMealImages`

The iOS app auto-requests missing images once per day view load, and the Profile screen also has a manual `Generate missing meal photos` action.

## Deploy

```bash
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions,firestore,storage
```

If you already set `GEMINI_API_KEY`, just deploy.
