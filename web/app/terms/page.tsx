import type { Metadata } from "next";
import { LegalPage } from "@/components/LegalPage";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Terms of Use",
  description: "MealRecap Terms of Use.",
};

export default function TermsPage() {
  return (
    <LegalPage
      title="Terms of Use"
      intro="These Terms govern your use of MealRecap. Replace placeholder contact details with your final company details before publishing."
    >
      <h2>1. Acceptance</h2>
      <p>By using MealRecap, you agree to these Terms. If you do not agree, do not use the app or website.</p>

      <h2>2. MealRecap service</h2>
      <p>MealRecap helps users log meals, estimate calories and macros, organize food history, and track nutrition goals. Estimates may be generated using AI and may be inaccurate or incomplete.</p>

      <h2>3. Not medical advice</h2>
      <p>MealRecap is for general wellness and informational purposes only. It is not medical, nutrition, diagnosis, treatment, or professional advice. Consult a qualified healthcare professional before making health, diet, or fitness decisions.</p>

      <h2>4. Your responsibilities</h2>
      <ul>
        <li>Provide accurate information where possible.</li>
        <li>Review AI estimates before relying on them.</li>
        <li>Use the app lawfully and respectfully.</li>
        <li>Do not upload content you do not have the right to use.</li>
        <li>Do not attempt to reverse engineer, abuse, overload, or interfere with the service.</li>
      </ul>

      <h2>5. Subscriptions and purchases</h2>
      <p>
        MealRecap may offer paid subscriptions such as weekly, monthly, or yearly MealRecap Pro plans. Prices, trial availability, and renewal terms are shown on Apple’s purchase sheet before you confirm payment.
      </p>
      <p>
        Subscriptions are billed through your Apple ID and automatically renew unless canceled at least 24 hours before the end of the current period. You can manage or cancel subscriptions in your Apple ID subscription settings. Refunds are handled by Apple according to Apple’s policies.
      </p>

      <h2>6. Accounts and deletion</h2>
      <p>You are responsible for maintaining access to your account. You may request account deletion using the Delete Account page or by contacting support.</p>

      <h2>7. Intellectual property</h2>
      <p>MealRecap, including its design, branding, software, and content, is owned by MealRecap or its licensors. You may not copy, distribute, or create derivative works except as allowed by law.</p>

      <h2>8. User content</h2>
      <p>You retain ownership of meal descriptions, photos, notes, and other content you submit. You grant MealRecap the rights needed to host, process, analyze, display, and improve the service using that content.</p>

      <h2>9. Availability</h2>
      <p>We aim to keep MealRecap reliable, but we do not guarantee uninterrupted or error-free operation. Features may change, pause, or be discontinued.</p>

      <h2>10. Disclaimer of warranties</h2>
      <p>MealRecap is provided “as is” and “as available” without warranties of any kind to the fullest extent permitted by law.</p>

      <h2>11. Limitation of liability</h2>
      <p>To the fullest extent permitted by law, MealRecap will not be liable for indirect, incidental, special, consequential, or punitive damages, or for loss of data, profits, goodwill, or other intangible losses.</p>

      <h2>12. Changes</h2>
      <p>We may update these Terms from time to time. Continued use of MealRecap after changes means you accept the updated Terms.</p>

      <h2>13. Contact</h2>
      <p>Questions can be sent to <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a>.</p>
    </LegalPage>
  );
}
