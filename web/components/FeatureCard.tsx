type FeatureCardProps = {
  icon: string;
  title: string;
  children: React.ReactNode;
};

export function FeatureCard({ icon, title, children }: FeatureCardProps) {
  return (
    <article className="card">
      <div className="icon" aria-hidden="true">{icon}</div>
      <h3>{title}</h3>
      <p>{children}</p>
    </article>
  );
}
