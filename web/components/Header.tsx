import Link from "next/link";
import { site } from "@/lib/site";

export function Header() {
  return (
    <header className="header" aria-label="Site header">
      <Link href="/" className="logo" aria-label="MealRecap home">
        <span>MEAL</span>
        <span>RECAP</span>
      </Link>
      <nav className="nav" aria-label="Main navigation">
        <Link href="/privacy">Privacy</Link>
        <Link href="/support">Support</Link>
        <a className="nav-primary secondary-cta" href={site.appStoreUrl} aria-label="Download MealRecap on the App Store">
          Download
        </a>
      </nav>
    </header>
  );
}
