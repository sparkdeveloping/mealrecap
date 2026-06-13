# MealRecap Landing Page

A polished Next.js landing page and legal/support site for MealRecap.

## Included pages

Use these URLs after deploying the project to Vercel with the project name `mealrecap`:

- `mealrecap.vercel.app/` — landing page / marketing URL
- `mealrecap.vercel.app/privacy` — App Store Privacy Policy URL
- `mealrecap.vercel.app/terms` — Terms of Use
- `mealrecap.vercel.app/support` — App Store Support URL
- `mealrecap.vercel.app/health-disclaimer` — Health & Nutrition Disclaimer
- `mealrecap.vercel.app/delete-account` — account deletion instructions
- `mealrecap.vercel.app/contact` — contact page

## Local development

```bash
npm install
npm run dev
```

Then open `http://localhost:3000`.

## Deploy to Vercel

1. Push this folder to GitHub.
2. Create a new Vercel project.
3. Set the project name to `mealrecap` if you want the URL `mealrecap.vercel.app`.
4. Add environment variables if needed.
5. Deploy.

## Environment variables

Copy `.env.example` to `.env.local` for local development:

```bash
NEXT_PUBLIC_SITE_URL=https://mealrecap.vercel.app
NEXT_PUBLIC_APP_STORE_URL=https://apps.apple.com/app/idYOUR_APP_ID
NEXT_PUBLIC_SUPPORT_EMAIL=support@mealrecap.app
NEXT_PUBLIC_PRIVACY_EMAIL=privacy@mealrecap.app
```

Replace the App Store ID and email addresses before launch.

## App Store Connect fields

Suggested values:

- Support URL: `https://mealrecap.vercel.app/support`
- Marketing URL: `https://mealrecap.vercel.app/`
- Privacy Policy URL: `https://mealrecap.vercel.app/privacy`
- Terms of Use: `https://mealrecap.vercel.app/terms`
- Health Disclaimer: `https://mealrecap.vercel.app/health-disclaimer`

## Legal note

The privacy policy, terms, and health disclaimer are practical launch drafts, not legal advice. Review them with a qualified attorney before publishing.
