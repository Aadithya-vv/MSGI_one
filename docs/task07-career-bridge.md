# Task 07: Career Bridge

## Features and authorization

Jobs, internships and project collaboration use the existing opportunity_kind
values. Referral availability is a flag on jobs/internships, not an invented new
kind or a guaranteed referral. Listings, public safe details, author profile links,
create/edit, explicit private drafts, closing and archival use real repositories.

Publishing preserves private.can_publish(): verified alumni or verified authorized
administrators only. Students may browse permitted published posts and report
them. New accounts, suspended users and client metadata cannot grant publishing.
The new capability RPC adds active institution/department requirements. Authors
alone mutate their own posts; administrator status does not impersonate an author.
No administrator roles were provisioned or changed.

Community posts are visible to verified members. Institution/department audiences
are derived from the author's protected profile, never supplied as arbitrary
institution IDs. Scoped posts require matching viewer institution/department.
Published content is an explicit publishing action independent of directory
consent; hidden author names and profile links are suppressed. Only directory-
visible verified alumni have a public alumni profile link. No email, biography,
private goals or contact details are returned with listings.

A new restrictive SELECT policy strengthens, rather than replaces, existing RLS.
Drafts and closed posts remain author-only, matching the original policy. Archives
are also author-only and discoverable under My posts. Inactive or suspended
authors' published posts are hidden. Required-skill rows follow the same visibility.

## Storage and RPCs

Forward-only migrations, applied ONLY on isolated database 55322:

1. 20261114000100_career_bridge.sql: opportunity domain, organization, remote,
   referral, audience and archive fields; constrained scope FKs; indexed required
   skill join table, recent/scope indexes; stricter URL check and restrictive RLS.
2. 20261114000200_fix_career_filter_ambiguity.sql: explicit block-qualified filter
   variables in discovery. Local tests caught the kind variable/column ambiguity;
   the applied seventh migration was preserved and corrected forward-only.

RPCs: career_can_publish, career_opportunities, save_career_opportunity,
transition_career_opportunity, report_career_opportunity. All sensitive operations
require current protected membership, use SECURITY DEFINER/search_path='', derive
identity from auth.uid(), and revoke public/anonymous execution. There is no
client-author field, dynamic SQL, hosted deployment or RLS bypass through Flutter.

Create uses a single random v4 UUID generated per form. Pairing its unique ID
with an advisory lock makes duplicate create retries return the original post,
without overwriting changed content. Edit requires the exact saved updated_at;
stale writes raise SQLSTATE 40001 and retain the editor's unsaved input. Save
payloads whitelist fields, bound strings/catalog skill lists and validate URLs.
Author skills are resolved with one bounded public-catalog query for editing.

Draft saving is explicit, requires a valid title/description and persists securely
under author-only RLS. Incomplete unsaved input is memory-only. Publishing a draft
uses the same ID/version. Archives are read-only in this module; closure stops
application actions and preserves the record. UI uses archival instead of hard
deletion, retaining reports and skills. Existing legacy delete grants are unchanged;
reported rows remain protected from deletion by the original reports FK.

Reports reuse public.reports and its existing administrator-only moderate_report
operation. The wrapper accepts only a visible published other-author target,
derives reporter identity, validates reason/details, and reuses an existing open
report for retries. It never grants moderation permissions. No new moderation
queue UI is introduced; resolution uses the existing protected backend model.

## Discovery, relevance and links

Server filters: text search, category, domain, required catalog skill, location,
remote, referral, audience category, status and own posts. No entire directory or
opportunity collection is fetched. Pages are 20 + lookahead, maximum RPC limit 51.
Ordering is recency or deterministic skill coverage (own public profile skills
intersect listed requirements / required count), then creation timestamp and UUID
both descending. Empty requirements yield zero relevance and fall back to recency.
The tuple cursor (rank, created_at, id) preserves ties; filters reset pagination.
This is skill overlap, not an AI model or hiring eligibility assessment. Concurrent
edits/status changes can change live results; refresh to reconcile. Indexes support
visibility/skill/recency lookups; no large-scale load benchmark is claimed.

SQL and Dart validate HTTPS, ASCII DNS syntax, length and control characters;
userinfo, explicit ports, IP literals, local/internal/test/invalid suffixes and
encoded CRLF are denied. Opening revalidates the URL and asks confirmation showing
the hostname, then uses the external browser/application. This is not DNS vetting,
phishing detection or employer endorsement. The stronger CHECK is NOT VALID for
legacy rows, avoiding unreviewed data rewrites. Invalid legacy URLs are suppressed
in discovery; owners must clear/replace them before updating a legacy post.

## Local reproduction

Use only the existing isolated stack (API 55321, DB 55322, Mailpit 55324). Original
local database 54322 is separate. Official seed.sql remains unchanged. Fixtures
are explicitly synthetic catalogs/accounts/opportunities, never hosted records.

```powershell
$env:npm_config_offline='true'
$env:npm_config_yes='false'
npx.cmd supabase migration up --workdir "$env:TEMP\msgi_one_clean_9a7b7923"
npx.cmd supabase test db --workdir "$env:TEMP\msgi_one_clean_9a7b7923"
node tool/test_local_careers.cjs "$env:TEMP\msgi-task07-device-account.json"
node tool/test_local_careers_emulator.cjs "$env:TEMP\msgi-task07-device-account.json"
```

API fixture creation strictly checks local URL and fixed isolated Docker target.
Three synthetic accounts confirm through local Mailpit; owner SQL sets test
membership states only, never administrator roles. The optional private Temp
fixture has no tokens. Emulator test transfers it via stdin to app-private storage,
uses real Auth/PostgREST and simulated Flutter text input (avoiding the documented
real-IME injection race), samples logs, and removes its credential fixture on
success. No password or token is printed. Flutter removes its test APK afterward;
rebuild the ordinary main.dart debug APK for manual development.

No new dependencies or Android configuration changes. The existing sample home
cards remain explicitly preview content; live Career Bridge contains no samples.
Hosted readiness requires reviewing all pending migrations against actual hosted
history, approved catalogs, verified consenting publisher/reader accounts and
controlled acceptance. Hosted history was not queried in this local-only task.
Manual external-browser completion, real hardware and hosted acceptance remain
separate validation steps. Applications and collaboration contact use external
links and existing professional profiles/connections, not an in-app ATS.

## Recorded acceptance

117 Flutter tests, 237 database assertions, 46 local API checks and one native
emulator scenario passed, with clean analyzer and normal debug APK. All are local
results. See verification.md for precise coverage and unverified manual/hosted
flows. No hosted migration was deployed and no administrator role was changed.
