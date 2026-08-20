-- DayTrace Control Center: additive control-plane schema only.
-- It never stores or controls phone-local tasks, timers, reminders, reports, or SQLite data.
create extension if not exists pgcrypto;

create table public.platform_admins (
  user_id uuid primary key references auth.users(id) on delete restrict,
  display_name text not null default 'Platform owner',
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  constraint platform_admins_no_blank_name check (length(trim(display_name)) > 0)
);

create or replace function public.is_platform_admin()
returns boolean language sql stable security definer set search_path = public, auth
as $$ select exists (select 1 from public.platform_admins where user_id = (select auth.uid())) $$;
revoke all on function public.is_platform_admin() from public;
grant execute on function public.is_platform_admin() to authenticated;

create table public.platform_releases (
  id uuid primary key default gen_random_uuid(), version_name text not null check (version_name ~ '^\\d+\\.\\d+\\.\\d+$'),
  build_number integer not null check (build_number > 0), release_tag text not null check (release_tag ~ '^v?\\d+\\.\\d+\\.\\d+\\+\\d+$'),
  github_release_url text not null check (github_release_url ~ '^https://'), apk_url text not null check (apk_url ~ '^https://'),
  release_notes text not null default '', mandatory boolean not null default false,
  minimum_supported_version text not null check (minimum_supported_version ~ '^\\d+\\.\\d+\\.\\d+\\+\\d+$'),
  rollout_state text not null default 'draft' check (rollout_state in ('draft','published','rolled_back')),
  sha256 text check (sha256 is null or sha256 ~ '^[A-Fa-f0-9]{64}$'), published_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), created_by uuid not null references auth.users(id),
  unique (build_number), unique (release_tag)
);
create index platform_releases_published_idx on public.platform_releases (published_at desc) where rollout_state = 'published';

create table public.remote_config_entries (
  id uuid primary key default gen_random_uuid(), key text not null unique check (key ~ '^[a-z][a-z0-9_.-]{1,80}$'),
  value_type text not null check (value_type in ('string','number','boolean','json','enum')), value_json jsonb not null, default_value_json jsonb not null,
  description text not null check (length(description) between 3 and 500), min_build integer check (min_build is null or min_build >= 0), max_build integer check (max_build is null or max_build > 0),
  enabled boolean not null default true, version integer not null default 1 check (version > 0),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), updated_by uuid not null references auth.users(id),
  check (max_build is null or min_build is null or max_build >= min_build),
  check (key not like 'core.%' and key not like 'database.%' and key not like 'timer.%' and key not like 'task.%' and key not like 'timeline.%' and key not like 'reminder.%')
);
create index remote_config_enabled_idx on public.remote_config_entries (key) where enabled;

create table public.feature_flags (
  id uuid primary key default gen_random_uuid(), key text not null unique check (key ~ '^[a-z][a-z0-9_.-]{1,80}$'), description text not null check (length(description) between 3 and 500),
  owner_notes text not null default '', enabled boolean not null default false, optional_service_only boolean not null default true check (optional_service_only),
  min_build integer check (min_build is null or min_build >= 0), max_build integer check (max_build is null or max_build > 0), starts_at timestamptz, ends_at timestamptz, retired_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), updated_by uuid not null references auth.users(id),
  check (key not like 'core.%' and key not like 'database.%' and key not like 'timer.%' and key not like 'task.%' and key not like 'timeline.%' and key not like 'reminder.%'),
  check (ends_at is null or starts_at is null or ends_at > starts_at)
);

create table public.service_maintenance_windows (
  id uuid primary key default gen_random_uuid(), service text not null check (service in ('dashboard_api','remote_config','backup_upload','ai_proxy','update_metadata')),
  status text not null check (status in ('scheduled','active','ended','cancelled')), message text not null check (length(message) between 3 and 500),
  starts_at timestamptz not null, ends_at timestamptz not null, min_build integer check (min_build is null or min_build >= 0), max_build integer check (max_build is null or max_build > 0),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(), updated_by uuid not null references auth.users(id), check (ends_at > starts_at)
);
create index maintenance_active_idx on public.service_maintenance_windows (starts_at, ends_at) where status in ('scheduled','active');

create table public.backup_imports (
  id uuid primary key default gen_random_uuid(), storage_path text not null unique, source_filename text not null, size_bytes bigint not null check (size_bytes > 0), sha256 text not null check (sha256 ~ '^[A-Fa-f0-9]{64}$'),
  schema_version integer not null check (schema_version > 0), created_at_utc timestamptz not null, record_counts jsonb not null default '{}'::jsonb, validation_warnings jsonb not null default '[]'::jsonb,
  retention_until timestamptz, status text not null default 'inspected' check (status in ('inspected','expired','deleted')), uploaded_at timestamptz not null default now(), uploaded_by uuid not null references auth.users(id)
);
create index backup_imports_uploaded_idx on public.backup_imports (uploaded_at desc);

create table public.platform_settings (
  key text primary key check (key in ('github_repository','vercel_project','backup_retention_days','remote_config_default_build')), value_json jsonb not null, updated_at timestamptz not null default now(), updated_by uuid not null references auth.users(id)
);
create table public.health_checks (
  id uuid primary key default gen_random_uuid(), service text not null check (service in ('vercel','dashboard_api','supabase_database','supabase_storage','github_releases','remote_config','ai_proxy')), state text not null check (state in ('healthy','degraded','unavailable','not_configured')), checked_at timestamptz not null default now(), latency_ms integer check (latency_ms is null or latency_ms >= 0), error_summary text, guidance text not null default '', checked_by uuid references auth.users(id)
);
create index health_checks_recent_idx on public.health_checks (service, checked_at desc);

create table public.audit_log (
  id bigint generated always as identity primary key, actor_id uuid references auth.users(id), action text not null, entity_type text not null, entity_id text, before_metadata jsonb, after_metadata jsonb, request_id text, created_at timestamptz not null default now(),
  check (before_metadata is null or not (before_metadata ? 'secret')), check (after_metadata is null or not (after_metadata ? 'secret'))
);
create index audit_log_created_idx on public.audit_log (created_at desc); create index audit_log_entity_idx on public.audit_log (entity_type, entity_id);

create or replace function public.write_platform_audit()
returns trigger language plpgsql security definer set search_path = public, auth as $$
begin
  if tg_op = 'DELETE' then
    insert into public.audit_log(actor_id,action,entity_type,entity_id,before_metadata,request_id)
    values ((select auth.uid()),tg_op,tg_table_name,coalesce(to_jsonb(old)->>'id',to_jsonb(old)->>'user_id'),to_jsonb(old)-'storage_path',(nullif(current_setting('request.headers',true),'')::jsonb)->>'x-request-id');
    return old;
  end if;
  insert into public.audit_log(actor_id,action,entity_type,entity_id,before_metadata,after_metadata,request_id)
  values ((select auth.uid()),tg_op,tg_table_name,coalesce(to_jsonb(new)->>'id',to_jsonb(new)->>'user_id'),case when tg_op='UPDATE' then to_jsonb(old)-'storage_path' else null end,to_jsonb(new)-'storage_path',(nullif(current_setting('request.headers',true),'')::jsonb)->>'x-request-id');
  return new;
end $$;
revoke all on function public.write_platform_audit() from public;

create trigger audit_releases after insert or update or delete on public.platform_releases for each row execute function public.write_platform_audit();
create trigger audit_configs after insert or update or delete on public.remote_config_entries for each row execute function public.write_platform_audit();
create trigger audit_flags after insert or update or delete on public.feature_flags for each row execute function public.write_platform_audit();
create trigger audit_maintenance after insert or update or delete on public.service_maintenance_windows for each row execute function public.write_platform_audit();
create trigger audit_backups after insert or update or delete on public.backup_imports for each row execute function public.write_platform_audit();
create trigger audit_settings after insert or update or delete on public.platform_settings for each row execute function public.write_platform_audit();
create trigger audit_platform_admins after insert or update or delete on public.platform_admins for each row execute function public.write_platform_audit();

create or replace function public.prevent_last_owner_removal()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from public.platform_admins) <= 1 then raise exception 'Cannot remove the final platform owner'; end if;
  return old;
end $$;
revoke all on function public.prevent_last_owner_removal() from public;
create trigger protect_final_owner before delete on public.platform_admins for each row execute function public.prevent_last_owner_removal();

alter table public.platform_admins enable row level security; alter table public.platform_releases enable row level security; alter table public.remote_config_entries enable row level security; alter table public.feature_flags enable row level security; alter table public.service_maintenance_windows enable row level security; alter table public.backup_imports enable row level security; alter table public.platform_settings enable row level security; alter table public.health_checks enable row level security; alter table public.audit_log enable row level security;
revoke all on all tables in schema public from anon, authenticated;
grant select,insert,update,delete on public.platform_admins,public.platform_releases,public.remote_config_entries,public.feature_flags,public.service_maintenance_windows,public.backup_imports,public.platform_settings,public.health_checks to authenticated;
grant select on public.audit_log to authenticated;
grant usage,select on sequence public.audit_log_id_seq to authenticated;
create policy owner_all_admins on public.platform_admins for all to authenticated using ((select public.is_platform_admin())) with check ((select public.is_platform_admin()));
create policy owner_all_releases on public.platform_releases for all to authenticated using ((select public.is_platform_admin())) with check ((select public.is_platform_admin()));
create policy owner_all_config on public.remote_config_entries for all to authenticated using ((select public.is_platform_admin())) with check ((select public.is_platform_admin()));
create policy owner_all_flags on public.feature_flags for all to authenticated using ((select public.is_platform_admin())) with check ((select public.is_platform_admin()));
create policy owner_all_maintenance on public.service_maintenance_windows for all to authenticated using ((select public.is_platform_admin())) with check ((select public.is_platform_admin()));
create policy owner_all_backups on public.backup_imports for all to authenticated using ((select public.is_platform_admin())) with check ((select public.is_platform_admin()));
create policy owner_all_settings on public.platform_settings for all to authenticated using ((select public.is_platform_admin())) with check ((select public.is_platform_admin()));
create policy owner_all_health on public.health_checks for all to authenticated using ((select public.is_platform_admin())) with check ((select public.is_platform_admin()));
create policy owner_read_audit on public.audit_log for select to authenticated using ((select public.is_platform_admin()));

create view public.public_remote_config with (security_invoker = false) as select key, value_type as type, value_json as value, default_value_json as default_value, min_build, max_build from public.remote_config_entries where enabled;
create view public.public_maintenance_status with (security_invoker = false) as select service,message,starts_at,ends_at,min_build,max_build from public.service_maintenance_windows where status in ('scheduled','active');
revoke all on public.public_remote_config,public.public_maintenance_status from public; grant select on public.public_remote_config,public.public_maintenance_status to anon,authenticated;

insert into storage.buckets (id,name,public,file_size_limit,allowed_mime_types) values ('daytrace-backups','daytrace-backups',false,52428800,array['application/json']) on conflict (id) do nothing;
create policy owner_select_backup_objects on storage.objects for select to authenticated using (bucket_id='daytrace-backups' and (select public.is_platform_admin()));
create policy owner_insert_backup_objects on storage.objects for insert to authenticated with check (bucket_id='daytrace-backups' and (select public.is_platform_admin()));
create policy owner_update_backup_objects on storage.objects for update to authenticated using (bucket_id='daytrace-backups' and (select public.is_platform_admin())) with check (bucket_id='daytrace-backups' and (select public.is_platform_admin()));
create policy owner_delete_backup_objects on storage.objects for delete to authenticated using (bucket_id='daytrace-backups' and (select public.is_platform_admin()));
