import { createBrowserClient } from "@supabase/ssr";
import { publicEnv } from "@/lib/env";
export const createClient = () => { const { url, key } = publicEnv(); return createBrowserClient(url, key); };
