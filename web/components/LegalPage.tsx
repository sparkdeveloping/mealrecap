import Link from "next/link";
import { legalLinks, site } from "@/lib/site";

type LegalPageProps = {
  title: string;
  intro: string;
  children: React.ReactNode;
};

export function LegalPage({ title, intro, children }: LegalPageProps) {
  return (
    <main>
      <section className="legal-layout container">
        <article className="legal-card">
          <p className="legal-meta">Effective {site.effectiveDate}</p>
          <h1>{title}</h1>
          <p>{intro}</p>
          {children}
        </article>
        <aside className="side-nav" aria-label="Legal navigation">
          {legalLinks.map((link) => (
            <Link key={link.href} href={link.href}>{link.label}</Link>
          ))}
          <Link href="/delete-account">Delete Account</Link>
          <Link href="/contact">Contact</Link>
        </aside>
      </section>
    </main>
  );
}
