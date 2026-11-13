# Task 06: explainable mentor recommendations

## Algorithm v1

This is deterministic database scoring, not a trained AI model or a prediction of
mentorship success. Each comparable personal component lies in [0,1]:

- Skills (40%): distinct overlap / distinct union of the requester's selected
  existing and learning skills. A mentor's unrelated skills are not penalized.
- Domain (30%): exact case-insensitive trimmed match of the mentor's public
  professional domain to any selected target domain (alternatives).
- Availability (20%): explicit mentorship_preferences.available=true. This is an
  eligibility gate, not a claim about capacity, response time or a guaranteed slot.
- Interests (10%): distinct case-insensitive career-interest overlap divided by
  the requester's distinct interests. No sensitive attributes are inferred.

Missing either side of a personal comparison omits that component from the
weighted denominator instead of treating it as an explicit mismatch. Observed
non-matches remain zero. Round 100 * weighted sum / observed weight. Cap at 65
for one comparable personal component, 85 for two, 100 for three. When there is
no positive personal overlap, score zero regardless of availability. Expose
comparable evidence count and call the result relevance points, never a match
probability. Exact full-evidence overlap yields 100; availability alone yields 0.
Objectives are stored privately for planning and are explicitly not scored.
No synonym, fuzzy semantic, embedding or trained-model similarity is claimed.

Return only supported matched skill names, matched public domain and shared
professional interests. Do not read another person's mentor_goals. Unmatched
career interests, private goals/objectives, contacts and location are not returned.

Default ordering: score descending, UUID ascending. Optional skill/domain sorts
prioritize their normalized component then score, with the same UUID tie break.
A six-decimal rank value plus UUID cursor preserves ties across numeric JSON
round trips. Each server response is bounded to 21 (20 + lookahead), max 51.
Changing filters/goals/order refreshes from the beginning. Concurrent profile or
preference changes can reorder the live dataset; refresh to reconcile. No exact
total or entire alumni directory is downloaded. Server scoring considers the
eligible set; very large catalogs should receive a query-plan/load review before
rollout. Existing key indexes, new opted-in mentor partial index and bidirectional
block indexes support eligibility lookups; this is not a benchmark at global scale.

## Eligibility and protected operations

New forward-only migration: 20261113000300_mentor_matching.sql (sixth migration).
Applied only to the isolated local project, never hosted in this task. Existing
five migrations and RLS/grants remain unchanged.

recommend_mentors requires a verified confirmed requester (student or alumni).
Candidates must be a different, confirmed verified alumnus, directory-visible,
mentoring opted-in and in active institutions/departments. Suspended/rejected or
unconfirmed candidates are excluded. Match the existing community-wide discovery
permission model: cross-institution discovery is allowed for verified members;
no new institution-only restriction or authorization bypass is introduced.

mentor_goals: profile-owned private preferences, self-only verified SELECT under
RLS, no client INSERT/UPDATE/DELETE. my_mentor_goals returns the caller's saved
values or defaults from their own profile; skill labels come from public catalogs.
save_mentor_goals derives identity from auth.uid(), whitelists five JSON keys,
bounds lists/strings, validates catalog skill IDs and de-duplicates selections.
It cannot change public education, membership, mentoring availability or roles.
Saved goals resume after restart; unsaved edits are memory-only. Load failure
cannot overwrite saved goals with blank form values. Save failure retains edits.

private.mentor_blocks has RLS, no client table grants and indexes in both
directions. set_mentor_block derives the blocker from auth.uid(); self blocks and
hidden/ineligible mentor targets are denied. Either direction excludes a pair
from recommendations. These are mentorship-scoped exclusions, not an existing
application-wide communications block; they do not mutate or weaken connection
RPCs, directory privacy or membership. UI Hide has a transient Undo action. The
owner-scoped RPC can remove an existing exclusion without exposing the peer's
current private details. No list of who blocked a user is exposed.

All four new RPCs are SECURITY DEFINER with search_path='', qualified application
references, no dynamic SQL, revoked public/anonymous execution and explicit
authenticated grants. Public RPC guards and private tables remain the security
boundary. Existing ConnectionControls and request/manage/network RPCs provide
real relationship status and actions; rejected requests cannot be reopened.

## Flutter experience

Riverpod repository under features/mentorship, existing GoRouter /mentors route,
navy/blue/gold shared theme. Recommendation cards provide evidence, relevance,
mentoring availability, public profile navigation and existing connection actions.
Server domain filter, relevance/skill/domain ordering, new-connections filter,
keyset pagination, loading/empty/offline/retry and accessible wrapping layouts.
Private goals use existing paginated CatalogPicker for existing/learning skills.
No new dependencies. Home's unrelated featured mentor remains explicitly SAMPLE;
the live mentor route has no sample badge or invented production recommendations.

## Local reproduction

Use the existing isolated stack (API 55321 / DB 55322 / Mailpit 55324), with the
ignored config/backend.auth-test.local.json. Keep hosted config separate. Never
reset a database or run synthetic fixtures on hosted infrastructure.

```powershell
$env:npm_config_offline='true'
$env:npm_config_yes='false'
npx.cmd supabase migration up --workdir "$env:TEMP\msgi_one_clean_9a7b7923"
npx.cmd supabase test db --workdir "$env:TEMP\msgi_one_clean_9a7b7923"
node tool/test_local_mentors.cjs "$env:TEMP\msgi-task06-device-account.json"
node tool/test_local_mentors_emulator.cjs "$env:TEMP\msgi-task06-device-account.json"
```

API script strictly permits the fixed isolated URL/container, three synthetic
@example.test accounts, local Mailpit confirmation and synthetic catalogs. It
uses owner SQL only for explicit verified/suspended membership fixtures, never
administrator roles. It stores the optional synthetic emulator fixture privately
in Temp without tokens. Emulator runner transfers it over stdin to app-private
storage, runs the SDK integration test and removes the fixture on success. It
samples Flutter logs for password/token/overflow/exception patterns. Failure logs
remain local and ignored; no passwords/tokens are printed. Flutter uninstalls its
test APK; rebuild the normal main.dart APK afterward for manual use.

Hosted prerequisites: separately review and approve pending migrations five and
six against the intended development reference; approved institutional/skill
catalogs, consenting complete verified student/alumni accounts and alumni explicit
mentoring opt-in. No administrator provisioning or hosted deployment occurred.
Physical-device acceptance remains pending; an emulator is sufficient locally.

The native integration scenario uses Flutter's test input channel for synthetic
text entry. The installed SDK documents that mixing injected input with the real
Android IME can overwrite editing state. This simulates only keyboard transport;
real local Auth, preferences, catalog HTTP calls, recommendations and connection
RPCs are exercised. Manual physical-keyboard/IME acceptance is not claimed.

## Acceptance summary

186 database assertions, 27 real local API checks, 102 Flutter unit/widget tests,
one emulator integration scenario, clean analyzer and normal local debug APK.
The emulator scenario validates goals round-trip and mentor/profile/connection
navigation against actual local services; no manual phone testing is claimed.
