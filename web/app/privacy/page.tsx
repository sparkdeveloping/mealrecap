import type { Metadata } from "next";
import { LegalPage } from "@/components/LegalPage";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description: "MealRecap Privacy Policy.",
};

export default function PrivacyPage() {
  return (
    <LegalPage
      title="Privacy Policy"
      intro="This Privacy Policy explains what MealRecap collects, how we use it, and the choices you have. Replace placeholder contact details with your final company details before publishing."
    >
      <h2>1. Information we collect</h2>
      <p>Depending on how you use MealRecap, we may collect the following categories of information:</p>
      <ul>
        <li><strong>Account information:</strong> such as your email address or authentication identifier.</li>
        <li><strong>Meal information:</strong> meal descriptions, meal names, food items, calories, macros, notes, labels, and meal history.</li>
        <li><strong>Photos and voice inputs:</strong> meal photos you choose or capture, and voice input or transcripts when you use voice features.</li>
        <li><strong>Goals:</strong> calorie goals, protein goals, and related nutrition preferences you provide.</li>
        <li><strong>Apple Health information:</strong> only if you choose to connect Apple Health and grant permission.</li>
        <li><strong>Purchase status:</strong> subscription entitlement status provided by Apple or our subscription infrastructure.</li>
        <li><strong>Usage and diagnostics:</strong> app events, device information, crash logs, and performance data used to improve reliability.</li>
      </ul>

      <h2>2. How we use information</h2>
      <p>We use information to:</p>
      <ul>
        <li>provide meal logging, photo analysis, voice recap, nutrition estimates, and daily history;</li>
        <li>calculate progress toward calorie and protein goals;</li>
        <li>sync and secure your account data;</li>
        <li>process subscriptions and restore purchases;</li>
        <li>respond to support requests;</li>
        <li>monitor app reliability, prevent abuse, and improve MealRecap.</li>
      </ul>

      <h2>3. AI processing</h2>
      <p>
        MealRecap may use AI service providers to interpret meal descriptions, voice transcripts, and photos. These services help estimate meal names, calories, protein, carbs, fat, and related meal details. Nutrition estimates are approximate and may be incorrect.
      </p>

      <h2>4. Apple Health</h2>
      <p>
        Apple Health access is optional. MealRecap only reads or writes Health data after you grant permission through Apple’s Health permission sheet. You can change Health permissions at any time in the Settings app.
      </p>
      <p>
        MealRecap does not use Apple Health data for advertising, does not sell Apple Health data, and does not share Apple Health data with data brokers. Health data is used only to provide app features you request, such as nutrition and goal context.
      </p>

      <h2>5. Sharing information</h2>
      <p>We may share information with service providers that help operate MealRecap, such as cloud hosting, authentication, database, storage, AI processing, analytics, crash reporting, customer support, and subscription infrastructure. We may also disclose information if required by law or to protect rights, safety, and security.</p>

      <h2>6. Data retention</h2>
      <p>We keep information for as long as needed to provide MealRecap, comply with legal obligations, resolve disputes, maintain security, and enforce agreements. You may request deletion of your account and associated data.</p>

      <h2>7. Your choices</h2>
      <ul>
        <li>You can delete meals inside the app where supported.</li>
        <li>You can disconnect Apple Health permissions in iOS Settings.</li>
        <li>You can manage or cancel subscriptions through your Apple ID.</li>
        <li>You can request account deletion by visiting the Delete Account page or contacting us.</li>
      </ul>

      <h2>8. Children</h2>
      <p>MealRecap is not intended for children under 13. If you believe a child has provided personal information, contact us so we can take appropriate action.</p>

      <h2>9. International users</h2>
      <p>Your information may be processed in countries other than where you live. Where required, we use appropriate safeguards for cross-border data transfers.</p>

      <h2>10. Changes to this policy</h2>
      <p>We may update this Privacy Policy from time to time. If changes are material, we will provide notice as appropriate.</p>

      <h2>11. Contact</h2>
      <p>Privacy questions or requests can be sent to <a href={`mailto:${site.privacyEmail}`}>{site.privacyEmail}</a>.</p>
    </LegalPage>
  );
}
