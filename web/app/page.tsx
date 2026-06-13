import { FeatureCard } from "@/components/FeatureCard";
import { PhoneMockup } from "@/components/PhoneMockup";
import { site } from "@/lib/site";

export default function Home() {
  return (
    <main>
      <section className="hero container">
        <div>
          <div className="eyebrow">AI food logging</div>
          <h1>Track meals in seconds.</h1>
          <p className="hero-copy">
            Type it, say it, or snap a photo. MealRecap turns real-life meals into calories,
            protein, carbs, fat, and a clean daily recap.
          </p>
          <div className="actions">
            <a className="cta" href={site.appStoreUrl}>Download on the App Store</a>
            <a className="secondary-cta" href="#how-it-works">See how it works</a>
          </div>
          <p className="microcopy">Built for fast logging, calm progress, and fewer food-database searches.</p>
        </div>
        <PhoneMockup />
      </section>

      <section className="section container" id="features">
        <div className="section-head">
          <h2>Food logging without the busywork.</h2>
          <p>
            MealRecap is designed for people who want nutrition awareness without turning every meal into a chore.
          </p>
        </div>
        <div className="grid">
          <FeatureCard icon="✍️" title="Type naturally">
            Write meals the way you would text a friend. MealRecap organizes your food into meals and macros.
          </FeatureCard>
          <FeatureCard icon="🎙️" title="Speak your recap">
            Say what you ate during the day and turn it into a structured nutrition recap.
          </FeatureCard>
          <FeatureCard icon="📷" title="Snap a photo">
            Use a meal photo to estimate calories and macros, then keep the photo in your food history.
          </FeatureCard>
          <FeatureCard icon="🎯" title="Daily goals">
            Track calorie and protein progress with a simple dashboard built around your personal targets.
          </FeatureCard>
          <FeatureCard icon="💚" title="Apple Health optional">
            Connect Apple Health when available, or continue with manual goals. You stay in control.
          </FeatureCard>
          <FeatureCard icon="✨" title="Meal memory">
            Usual meals and smart suggestions help make repeat logging faster over time.
          </FeatureCard>
        </div>
      </section>

      <section className="section container" id="how-it-works">
        <div className="section-head">
          <h2>Three ways to recap a meal.</h2>
          <p>Use the input mode that fits the moment. No barcode hunting required.</p>
        </div>
        <div className="steps">
          <article className="step">
            <span>01</span>
            <h3>Tell it</h3>
            <p>“Lunch was rice and chicken.” MealRecap estimates the meal and saves it to your day.</p>
          </article>
          <article className="step">
            <span>02</span>
            <h3>Snap it</h3>
            <p>Take or choose a meal photo, preview it, then analyze calories and macros.</p>
          </article>
          <article className="step">
            <span>03</span>
            <h3>Review it</h3>
            <p>See your calories, protein, macros, and meals in one calm daily recap.</p>
          </article>
        </div>
      </section>

      <section className="container">
        <div className="cta-panel">
          <div>
            <h2>Stop searching. Start eating.</h2>
            <p>
              MealRecap helps you understand what you ate without living inside a food database.
            </p>
          </div>
          <a className="cta" href={site.appStoreUrl}>Get MealRecap</a>
        </div>
      </section>
    </main>
  );
}
