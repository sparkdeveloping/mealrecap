import Link from "next/link";
import { legalLinks, site } from "@/lib/site";

export function Footer() {
  return (
    <footer className="footer">
      <div className="container footer-inner">
        <div>
          <div className="logo" aria-label="MealRecap">
            <span>MEAL</span>
            <span>RECAP</span>
          </div>
          <p>© 2026 {site.company}. All rights reserved.</p>
        </div>
        <div className="footer-links">
          {legalLinks.map((link) => (
            <Link key={link.href} href={link.href}>{link.label}</Link>
          ))}
          <Link href="/delete-account">Delete Account</Link>
          <Link href="/contact">Contact</Link>
        </div>
      </div>
    </footer>
  );
}
