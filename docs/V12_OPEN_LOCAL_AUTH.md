# MealRecap v12 — Open Local Auth Build

This build removes Firebase Auth, Firebase ID token refreshes, App Check requirements, and backend auth checks from the app flow.

## App behavior

- Users sign in with a local email/password stored on the device.
- The app creates a stable local user id like `local_...`.
- Firestore, Storage, and Cloud Functions use that local id only to group data.
- No Firebase Auth token is required for chat, voice, camera, Firestore, Storage, or Cloud Functions.

## Backend behavior

- Callable functions do not enforce App Check.
- Callable functions do not require `request.auth`.
- The backend uses `_localUserID` from the app, then `_clientAuthUID`, then `local-user`.

## Rules

Firestore and Storage rules are open in this build.

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

After deploying, clean the iOS build:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/MealRecap-*
```

Delete the app from the simulator, rebuild, create a local account, and test text logging.
