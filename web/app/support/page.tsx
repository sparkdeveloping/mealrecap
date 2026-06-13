import type { Metadata } from "next";
import Link from "next/link";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Support",
  description: "Get help with MealRecap.",
};

export default function SupportPage() {
  return (
    <main>
      <section className="legal-hero container">
        <p className="eyebrow">Support</p>
        <h1>How can we help?</h1>
        <p className="hero-copy">Find answers, contact support, or manage your MealRecap account.</p>
        <div className="actions">
          <a className="cta" href={`mailto:${site.supportEmail}`}>Email support</a>
          <Link className="secondary-cta" href="/delete-account">Delete account</Link>
        </div>
      </section>

      <section className="section container">
        <div className="faq">
          <article className="faq-item">
            <h3>How do I log a meal?</h3>
            <p>Open MealRecap and type what you ate, use voice recap, or choose Snap to take or select a meal photo.</p>
          </article>
          <article className="faq-item">
            <h3>Are nutrition values exact?</h3>
            <p>No. MealRecap provides estimates. Review and adjust meals when needed, especially for health or fitness goals.</p>
          </article>
          <article className="faq-item">
            <h3>How do I manage MealRecap Pro?</h3>
            <p>Subscriptions are managed through your Apple ID. Open the App Store subscription settings to cancel, renew, or change plans.</p>
          </article>
          <article className="faq-item">
            <h3>How do I restore purchases?</h3>
            <p>Open MealRecap, go to Profile, and tap Restore Purchases.</p>
          </article>
          <article className="faq-item">
            <h3>How do I change Apple Health permissions?</h3>
            <p>Open the iOS Settings app, go to Health, then Data Access & Devices, and update MealRecap permissions.</p>
          </article>
          <article className="faq-item">
            <h3>How do I contact support?</h3>
            <p>Email <a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a> with your question, account email, device model, and screenshots if helpful.</p>
          </article>
        </div>
      </section>
    </main>
  );
}
