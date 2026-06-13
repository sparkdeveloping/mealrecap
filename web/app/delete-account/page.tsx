import type { Metadata } from "next";
import { LegalPage } from "@/components/LegalPage";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Delete Account",
  description: "Request deletion of your MealRecap account.",
};

export default function DeleteAccountPage() {
  return (
    <LegalPage
      title="Delete Account"
      intro="You can request deletion of your MealRecap account and associated app data. This page is provided for App Store compliance and user privacy."
    >
      <h2>How to request deletion</h2>
      <ol>
        <li>Open MealRecap.</li>
        <li>Go to Profile or Account & App settings.</li>
        <li>Use the account deletion option if available.</li>
        <li>If you do not see that option, email us from the email address connected to your account.</li>
      </ol>

      <h2>Email request</h2>
      <p>
        Send a deletion request to <a href={`mailto:${site.supportEmail}?subject=MealRecap%20Account%20Deletion%20Request`}>{site.supportEmail}</a> with the subject “MealRecap Account Deletion Request.”
      </p>
      <p>Please include the email address used for MealRecap. We may ask for verification before deleting data.</p>

      <h2>What is deleted</h2>
      <ul>
        <li>account profile information associated with MealRecap;</li>
        <li>meal history, notes, nutrition estimates, and goals;</li>
        <li>meal photos and related stored media where technically available;</li>
        <li>app-specific records connected to your account.</li>
      </ul>

      <h2>What may be retained</h2>
      <p>
        We may retain limited information when required for legal, security, fraud prevention, billing, tax, backup, or dispute-resolution purposes. Apple subscription billing history is managed by Apple.
      </p>

      <h2>Timing</h2>
      <p>We aim to process verified deletion requests within 30 days unless a longer period is required or permitted by law.</p>
    </LegalPage>
  );
}
