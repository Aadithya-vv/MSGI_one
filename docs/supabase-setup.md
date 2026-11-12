# Supabase development setup

Workspace: `D:\MSGI_nexus`. No hosted project is connected by Task 03C.2A.
Follow [hosted-deployment-plan.md](hosted-deployment-plan.md) only after separate
explicit authorization. Never reset the existing local database on port 54322.

## Verified local foundation

Task 03C.1 applied all three migrations from scratch in isolation: 69/69 pgTAP
assertions, 13 RLS tables and 17 application functions passed verification.
The original local stack was preserved. See the latest entries in
[verification.md](verification.md); earlier entries are historical.

`supabase/config.toml` is local configuration, not hosted Auth configuration.
Its project_id is a Docker namespace, not a hosted project reference. It uses
PostgreSQL 17, API port 54321 and database port 54322. Local email confirmation
is disabled and redirects use localhost. Do not copy those defaults to hosted
Auth. Seeds are enabled and reference `supabase/seed.sql`.

## Catalog approval

The seed is an executable, empty, repeatable template: no official institution
or department catalog exists in approved project documents. Obtain approved
names, department mappings, authoritative source, approval date and faculty
owner before filling it. UUIDs are database-generated; no institution-code
column exists. Institution conflicts use lower(name); department conflicts use
(institution_id, name), with exact department-name spelling. Reruns preserve
existing records and active flags. Renaming/deactivation requires separate review.
Validate every department mapping before execution because the join omits
unmatched institutions. Skills and cities need separate approved catalogs.
No synthetic users, demonstration profiles or administrator roles belong here.
Empty institution/department catalogs prevent useful real onboarding.

## Flutter build configuration

`BackendConfig.fromEnvironment()` reads `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY`. `main.dart` initializes Supabase only after validation;
missing/invalid configuration shows setup. Only HTTPS origins and public
`sb_publishable_` keys are accepted. Secret/service-role and legacy JWT keys are
rejected. Never pass a privileged value to the compiler: runtime validation
cannot remove it from an artifact. Client configuration is extractable.

After hosted authorization, place ONLY the two reviewed public values in ignored
`config/backend.local.json` on the developer machine. No values are supplied here.

```powershell
git check-ignore config/backend.local.json
flutter run --dart-define-from-file=config/backend.local.json -d <android-device-id>
```

This future integration command was not executed in preparation. No Flutter,
dependency, SDK or Android application ID changes were necessary. Mobile callback
implementation remains a separate prerequisite described in the deployment plan.
