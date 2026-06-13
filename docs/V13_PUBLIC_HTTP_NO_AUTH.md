# V13 Public HTTP No-Auth Build

This build removes Firebase callable auth from the AI backend path.

Changes:
- Cloud Functions are now `onRequest` HTTPS functions, not `onCall` callable functions.
- Functions use `invoker: "public"`.
- iOS calls the functions with plain `URLSession` and expects `{ "result": ... }` JSON.
- No Firebase Auth token, App Check token, or callable context is required.
- Firestore and Storage rules are open for now.

Before TestFlight/App Store, lock this down again.
