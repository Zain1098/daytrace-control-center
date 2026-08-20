import { DashboardShell } from "@/components/dashboard-shell";
import { requireOwner } from "@/lib/auth";
export default async function DashboardLayout({ children }: { children: React.ReactNode }) { await requireOwner(); return <DashboardShell>{children}</DashboardShell>; }
