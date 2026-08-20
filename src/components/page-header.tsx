export function PageHeader({ title, detail, actions }: { title: string; detail: string; actions?: React.ReactNode }) {
  return <header className="topbar"><div><div className="eyebrow">DayTrace / private control plane</div><h1>{title}</h1><div className="eyebrow" style={{ marginTop: 5 }}>{detail}</div></div>{actions ?? <div className="avatar" aria-label="Platform owner">ZU</div>}</header>;
}
