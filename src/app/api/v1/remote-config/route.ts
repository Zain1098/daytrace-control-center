import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export async function GET(){try{const supabase=await createClient();const {data,error}=await supabase.from("public_remote_config").select("key,type,value,default_value,min_build,max_build");if(error) throw error;return NextResponse.json({version:1,generatedAtUtc:new Date().toISOString(),settings:data??[]},{headers:{"Cache-Control":"public, max-age=60, stale-while-revalidate=300"}})}catch{return NextResponse.json({version:1,generatedAtUtc:new Date().toISOString(),settings:[],fallback:true},{status:503,headers:{"Cache-Control":"no-store"}})}}
