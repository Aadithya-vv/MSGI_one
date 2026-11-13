# Task 04A local development and review

The implementation adds live onboarding/profile/directory repositories. It does
not populate approved catalogs, deploy hosted schema, approve real members or
provision administrators. Hosted auth still works; new profile functionality
requires separate review and deployment of the fourth migration first.

## Operations

- CatalogRepository: authenticated, paginated search of active institutions and
  departments, skills and cities. Department search is institution-scoped.
- Existing my_membership and membership-aware guards remain authoritative for UI.
- save_member_profile(p_input jsonb): bounded validated input; atomic own profile,
  skills, mentoring preference and pending transition through existing onboarding.
- profile_drafts: RLS-scoped own partial progress. Use Save progress privately;
  unsaved edits are not persisted. Saves and errors leave inputs available to retry.
- Own profiles: authenticated self-select and related catalog/skills/mentoring data.
- discover_alumni: name/institution/department/year/profession-company-domain/skill/
  consented-city filters, bounded UUID cursor pagination and safe detail lookup.
  Publicly discoverable means visible to VERIFIED community members, not internet
  visitors. Only alumni with directory consent are returned.

## Isolated verification (no reset)

Use the existing disposable project directory whose API is 55321 and database is
55322, not the main local stack on 54322. Copy the reviewed migration/test files
into its supabase subdirectory without copying hosted link metadata. Commands:

```powershell
npx.cmd supabase migration up --workdir <isolated-project-root>
npx.cmd supabase test db --workdir <isolated-project-root>
node tool/test_local_profiles.cjs
```

The API script refuses any endpoint except http://127.0.0.1:55321 and targets only
supabase_db_msgi_one_clean_9a7b7923 for synthetic owner fixtures. Requires Node,
Docker, the isolated Auth/REST/gateway/Mailpit stack and ignored
config/backend.auth-test.local.json containing ONLY its local public configuration.
It generates two synthetic @example.test accounts and random passwords in memory,
confirms through local Mailpit, and prints only named PASS results. It separately
runs supabase/dev/synthetic_catalogs.sql twice with explicit local opt-in; the
official supabase/seed.sql stays empty and unchanged. It creates NO administrator.
Synthetic accounts/mail remain in that disposable environment for inspection.
SQL security tests instead roll back all their fixtures. Neither workflow resets
or deletes existing user data. Never pass hosted configuration to this script.

```powershell
flutter build apk --debug --dart-define=LOCAL_AUTH_TESTING=true --dart-define-from-file=config/backend.auth-test.local.json
```

No phone is required. Physical phone acceptance remains a separate step if no
Android target is available. Local-only networking and hosted restoration are
explained in local-auth-testing.md. Do not replace the hosted config with local
keys or enable LOCAL_AUTH_TESTING for hosted/release use.

## Hosted prerequisites

Review the new migration's schemas, grants, functions and privacy projection before
separately authorizing deployment. Approve faculty-owned institution/department/
skill/city catalogs, verification evidence and admin ownership. No hosted catalog
or synthetic data is inserted by Task 04A. Without approved catalogs, onboarding
correctly shows an empty state; without approved members, directory is empty.
This task does not claim hosted onboarding or real alumni discovery is verified.
