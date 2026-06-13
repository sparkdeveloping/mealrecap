import type { Metadata } from "next";
import { site } from "@/lib/site";

export const metadata: Metadata = {
  title: "Contact",
  description: "Contact MealRecap.",
};

export default function ContactPage() {
  return (
    <main>
      <section className="legal-hero container">
        <p className="eyebrow">Contact</p>
        <h1>Contact MealRecap</h1>
        <p className="hero-copy">For support, privacy requests, partnership questions, or App Store review help, use the contacts below.</p>
      </section>
      <section className="container section">
        <div className="grid">
          <article className="card">
            <div className="icon">✉️</div>
            <h3>Support</h3>
            <p><a href={`mailto:${site.supportEmail}`}>{site.supportEmail}</a></p>
          </article>
          <article className="card">
            <div className="icon">🔒</div>
            <h3>Privacy</h3>
            <p><a href={`mailto:${site.privacyEmail}`}>{site.privacyEmail}</a></p>
          </article>
          <article className="card">
            <div className="icon">🍴</div>
            <h3>MealRecap</h3>
            <p>AI calorie and macro tracking for real-life meals.</p>
          </article>
        </div>
      </section>
    </main>
  );
}
