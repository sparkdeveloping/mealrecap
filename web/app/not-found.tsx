import Link from "next/link";

export default function NotFound() {
  return (
    <main>
      <section className="legal-hero container">
        <p className="eyebrow">404</p>
        <h1>Page not found.</h1>
        <p className="hero-copy">The page you are looking for does not exist.</p>
        <Link className="cta" href="/">Go home</Link>
      </section>
    </main>
  );
}
