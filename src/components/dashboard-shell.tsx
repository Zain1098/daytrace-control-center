"use client";

import { Activity, Archive, Bell, ClipboardList, Flag, HeartPulse, LayoutDashboard, Settings, ShieldCheck, SlidersHorizontal } from "lucide-react";
import Link from "next/link";
import { usePathname } from "next/navigation";

const nav = [
  ["Overview", "/overview", LayoutDashboard], ["Android releases", "/releases", Archive], ["Remote config", "/remote-config", SlidersHorizontal], ["Feature flags", "/feature-flags", Flag], ["Service maintenance", "/maintenance", Bell], ["Backup inspection", "/backups", ClipboardList], ["Audit & security", "/audit", ShieldCheck], ["System health", "/health", HeartPulse], ["Settings", "/settings", Settings],
] as const;

export function DashboardShell({ children }: { children: React.ReactNode }) {
  const path = usePathname();
  return <div className="shell"><aside className="sidebar"><Link className="brand" href="/overview"><span className="brand-mark"><Activity size={19}/></span><span>DayTrace<br/>Control Center</span></Link><div className="nav-label">Platform</div>{nav.map(([label, href, Icon]) => <Link key={href} href={href} className={`nav-link ${path === href ? "active" : ""}`}><Icon size={18}/><span>{label}</span></Link>)}<div className="side-note"><b>Offline boundary</b><br/>Phone-local tasks, timers, reminders, reports, and timeline data are never read or controlled here.</div></aside><main className="content">{children}</main><nav className="mobile-nav">{nav.slice(0,5).map(([label, href, Icon]) => <Link key={href} href={href}><Icon size={18}/><span>{label.split(" ")[0]}</span></Link>)}</nav></div>;
}
