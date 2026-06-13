export const site = {
  name: "MealRecap",
  title: "MealRecap — AI Calorie & Macro Tracker",
  description:
    "Track meals in seconds. Type naturally, speak your food, or snap a photo. MealRecap turns meals into calories, macros, and a calm daily food history.",
  url: process.env.NEXT_PUBLIC_SITE_URL || "https://mealrecap.vercel.app",
  appStoreUrl: process.env.NEXT_PUBLIC_APP_STORE_URL || "#",
  supportEmail: process.env.NEXT_PUBLIC_SUPPORT_EMAIL || "support@mealrecap.app",
  privacyEmail: process.env.NEXT_PUBLIC_PRIVACY_EMAIL || "privacy@mealrecap.app",
  effectiveDate: "June 13, 2026",
  company: "MealRecap",
};

export const legalLinks = [
  { href: "/privacy", label: "Privacy" },
  { href: "/terms", label: "Terms" },
  { href: "/health-disclaimer", label: "Health Disclaimer" },
  { href: "/support", label: "Support" },
];
