# DayTrace Control Center

Private, owner-only control plane for the Android-only, offline-first DayTrace app. It manages optional remote metadata only: Android release metadata, safe remote configuration, optional-service flags, maintenance windows, explicit backup inspection, audit events, and health checks.

## Non-negotiable boundary

DayTrace phone-local Drift/SQLite data stays on the device. This project cannot view, edit, delete, sync, wipe, or remotely operate phone-local tasks, timers, reminders, timeline, reports, or settings. The Android app must continue working from local defaults when every remote service is unavailable.

## Architecture

- Next.js App Router, strict TypeScript, Tailwind CSS, accessible semantic controls, and responsive layout from 360px upward.
- Supabase Auth cookies with an owner allowlist (`platform_admins`); no signup page or public dashboard data.
- Additive Supabase migration in `supabase/migrations/` with RLS, restricted grants, private Storage, immutable audit triggers, and protected final-owner deletion.
- GitHub Releases remain the APK binary store. Dashboard release metadata is review/control data, never a forced installer.

## Local setup

1. Copy `.env.example` to `.env.local` and fill values locally.
2. Install: `npm.cmd install`.
3. Log in to Supabase CLI and link the intended empty control-plane project.
4. Apply and verify: `npx.cmd supabase db push --linked`, then `npx.cmd supabase db advisors`.
5. In Supabase Auth, disable public signup and create the owner account. Add its `auth.users.id` to `public.platform_admins` through a controlled SQL session before first dashboard login.
6. Run `npm.cmd run dev`, then `npm.cmd run lint`, `npm.cmd run typecheck`, and `npm.cmd run build`.

## Deployment

Create a private `daytrace-control-center` GitHub repository, commit source only, set the listed environment variables in Vercel, and deploy with `npx.cmd vercel --prod`. Keep `SUPABASE_SERVICE_ROLE_KEY`, GitHub tokens, signing material, and `.env.local` out of Git and browser bundles.

## Security controls

- Default-deny RLS on every control-plane table; owner policies call `is_platform_admin()`.
- Privileged SECURITY DEFINER functions specify safe search paths, revoke public execute, and are only reachable through owner-gated RLS paths.
- Audit records are append-only to clients and omit backup object paths / secret-shaped values.
- Storage bucket `daytrace-backups` is private with owner-only CRUD policies.
- Final owner cannot be removed; dangerous deletion UI must require typed confirmation before a production action is wired.

## API contract and rollout

See [Android integration](docs/ANDROID_INTEGRATION.md). Remote configuration and maintenance endpoints return a safe failure payload when unavailable. They never control local core behavior.

## Verification checklist

- Test an allowlisted owner and authenticated non-owner against every dashboard route and table.
- Confirm `anon` cannot query base tables; confirm published view exposes only safe metadata.
- Inspect browser bundles for `SUPABASE_SERVICE_ROLE_KEY` and GitHub token values.
- Test a storage upload, audit trigger, release publish/rollback, config validation, and last-owner guard.
- Verify Vercel desktop and 360px routes after production deployment.
