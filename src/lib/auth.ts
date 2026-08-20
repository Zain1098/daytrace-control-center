import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

export async function requireOwner() {
  const supabase = await createClient();
  const { data: claims } = await supabase.auth.getClaims();
  const userId = claims?.claims?.sub;
  if (typeof userId !== "string") redirect("/login");
  const { data: owner } = await supabase.from("platform_admins").select("user_id, display_name").eq("user_id", userId).maybeSingle();
  if (!owner) redirect("/access-denied");
  return { supabase, userId, owner };
}
