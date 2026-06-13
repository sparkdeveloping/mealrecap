import type { Metadata } from "next";
import { LegalPage } from "@/components/LegalPage";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Health & Nutrition Disclaimer",
  description: "MealRecap Health and Nutrition Disclaimer.",
};

export default function HealthDisclaimerPage() {
  return (
    <LegalPage
      title="Health & Nutrition Disclaimer"
      intro="MealRecap provides general wellness and nutrition tracking tools. It is not a medical device and does not provide medical advice."
    >
      <h2>1. Not medical advice</h2>
      <p>
        MealRecap is intended for general wellness, food logging, and informational purposes only. It is not medical advice, diagnosis, treatment, or a substitute for professional care.
      </p>

      <h2>2. Nutrition estimates are approximate</h2>
      <p>
        Calories, protein, carbs, fat, ingredients, serving sizes, and other nutrition values may be estimated by AI or third-party data sources. These estimates may be inaccurate, incomplete, or unsuitable for your needs.
      </p>

      <h2>3. Consult professionals</h2>
      <p>
        Before making changes to your diet, exercise, weight management, medication, or health routine, consult a qualified healthcare professional, registered dietitian, or other appropriate professional.
      </p>

      <h2>4. Allergies and medical conditions</h2>
      <p>
        Do not rely on MealRecap to identify allergens, unsafe ingredients, medical conflicts, or dietary restrictions. Always verify food contents independently, especially if you have allergies, diabetes, eating disorder history, pregnancy-related needs, kidney disease, heart disease, or other medical conditions.
      </p>

      <h2>5. Emergencies</h2>
      <p>
        MealRecap is not for emergencies. If you believe you are experiencing a medical emergency, call emergency services immediately.
      </p>

      <h2>6. Contact</h2>
      <p>Questions can be sent to <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>.</p>
    </LegalPage>
  );
}
