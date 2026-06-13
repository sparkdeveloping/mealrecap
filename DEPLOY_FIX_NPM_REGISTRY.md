# MealRecap v6 Deploy Fix

This version removes `functions/package-lock.json` and `functions/node_modules` from the repo.

Reason: previous generated zips accidentally contained npm lockfile metadata pointing at an internal package mirror. On another Mac, `npm ci` tried to download packages from that inaccessible internal URL.

Use:

```bash
npm config set registry https://registry.npmjs.org/
rm -rf functions/node_modules functions/package-lock.json
cd functions
npm install --no-audit --no-fund
npm run build
node -e "require('./lib/index.js'); console.log('functions load ok')"
cd ..
firebase deploy --only functions
```

The Firebase predeploy hook now runs `npm install --no-audit --no-fund` instead of `npm ci` because the lockfile is intentionally removed.
