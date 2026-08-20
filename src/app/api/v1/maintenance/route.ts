import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
export async function GET(){try{const supabase=await createClient();const now=new Date().toISOString();const {data,error}=await supabase.from("public_maintenance_status").select("service,message,starts_at,ends_at,min_build,max_build").lte("starts_at",now).gte("ends_at",now);if(error)throw error;return NextResponse.json({active:data??[],offlineCoreUnaffected:true})}catch{return NextResponse.json({active:[],offlineCoreUnaffected:true,fallback:true},{status:503})}}
