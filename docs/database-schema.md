# Database schema — Task 03A

Two ordered migrations live in `supabase/migrations/`. They target PostgreSQL 15+
in Supabase and have not been applied to a hosted project. No real institutional
catalog or user data is seeded. Synthetic fixtures exist only in rollback tests.

| Table | Key / relationships | Purpose |
| --- | --- | --- |
| public.institutions | UUID PK | Multi-institution catalog; active flag |
| public.departments | UUID PK; institution FK | Department belongs to one institution |
| public.skills | UUID PK; case-insensitive unique name | Standard skill catalog |
| public.cities | UUID PK; city/country unique | City-level name and ISO-like two-letter country code only |
| public.profiles | auth.users UUID PK/FK; institution/department composite FK; optional city FK | User-editable professional data and opt-in preferences |
| public.profile_skills | profile/skill composite PK and FKs | Skill mapping |
| public.mentorship_preferences | profile PK/FK | Availability and bounded interests |
| private.memberships | profile PK/FK | Pending/verified/rejected/suspended and officially verified category |
| private.account_roles | auth.users PK/FK | Trusted administrator provisioning only |
| private.verification_audit | UUID PK; subject/actor auth.users FKs | Review transitions, reasons and timestamps |
| public.connections | UUID PK; two profile FKs; unique canonical unordered pair | Request, acceptance, rejection, cancellation |
| public.opportunities | UUID PK; author profile FK | Jobs/internships/collaborations; draft/published/closed |
| public.reports | UUID PK; reporter auth FK; exactly one target profile/opportunity FK | Private reporting and trusted moderation |

Profiles store display name, self-declared kind, institution, department, joining
and graduation years, optional designation, bounded career interests, optional
city, and explicit directory/map booleans. Email remains in auth.users. No private
evidence documents, phone, home address or precise GPS is collected by this task.

UUIDs, foreign keys, required fields, length/range checks, timestamps, bounded
arrays and update triggers protect consistency. GIN full-text indexes support
directory/listing text search; interest, skill, city, participant, author and
moderation indexes support expected queries. Directory search is limited to
display name/designation for now. Catalogs/skills/cities need approved real data.

## Transactions and lifecycle

Signup only creates Auth identity. `submit_onboarding` accepts no user ID, role
or verification fields. It derives auth.uid(), validates catalog/batch/skills,
and atomically creates or resubmits a pending profile, skill links, membership
and first audit. It cannot modify verified/rejected/suspended claims. Shared
advisory locks serialize onboarding and review for the same account.

Client updates after verification are column-limited to display name,
designation, interests, city and visibility flags. Institution, department, batch
and claimed kind require a separately reviewed correction workflow, not a direct
client update. Skill replacement is currently part of pending onboarding only.

`review_membership` requires a verified administrator and disallows own review.
It locks the membership, updates status/official category, and appends audit data
in the same transaction. Rejected accounts require trusted reopening to pending.
Approval and verified access also require a confirmed Auth email.
The first administrator must be provisioned through trusted owner/server SQL
after out-of-band verification; no client bootstrap endpoint exists.

Connection state changes are row-locked and only pending requests can transition.
One unordered pair is retained even after rejection/cancellation; repeat requests
require a future explicit product decision. Audit/relationship/report FKs can
restrict deletion. A retention, erasure and de-identification policy must be
approved before production; no destructive cleanup is implemented here.

## API functions

| RPC | Access / output |
| --- | --- |
| my_membership | Caller-only status, official category, profile-complete boolean |
| submit_onboarding | Caller-only transactional pending submission |
| directory_profiles | Verified caller; visible verified profiles; safe ID/name/category/institution/department/designation/skills projection |
| map_profiles | Verified caller; verified + directory-visible + map-opted-in targets; ID/name/city/country only |
| send_connection | Verified sender derived from session; verified visible recipient |
| transition_connection | Verified participants; recipient accepts/rejects, sender cancels |
| review_membership | Verified administrator; audited non-self review |
| verification_history | Verified administrator only |
| pending_memberships | Verified administrator; bounded queue of pending professional/institution/batch claims, no email |
| moderate_report | Verified administrator only |

There are no views or arbitrary SQL/dynamic projection RPCs. Public RPC execution
is revoked from PUBLIC and anon and granted to authenticated, with runtime checks
for each operation. Private helper functions expose only caller checks needed by
RLS; the arbitrary-target membership helper is not executable by clients.

## Task 04A schema extension (local only until approved)

Migration 20261113000100 adds company/professional_domain/biography/degree to own
profiles, an RLS owner-only profile_drafts table (14 application tables total),
and two checked RPCs (19 application functions total). Draft content is never in
directory output. Mentoring availability reuses mentorship_preferences. Direct
client grants to private membership/roles/audit remain unchanged. Existing 17
functions and RPC contracts are preserved. New discovery's fixed projection and
consent filtering are described in task04a-profiles-discovery.md.

## Task 05 additions (local only)

Migration 20261113000200_map_and_connections.sql adds paired coarse city centroid
columns and a partial map index; no existing migration is rewritten. New RPCs:
alumni_city_clusters, map_city_members, request_connection, manage_connection,
network_connections. Their bounded projections, access and transition contracts
are documented in task05-map-network.md. Existing RLS and legacy RPCs remain.
Hosted deployment has not been performed.

## Task 06 additions (local only)

Migration 20261113000300_mentor_matching.sql adds public.mentor_goals (self-only
verified reads, RPC-only writes), private.mentor_blocks and an available-mentor
partial index. New RPCs: my_mentor_goals, save_mentor_goals, set_mentor_block,
recommend_mentors. All derive identity from auth.uid() and require verified access.
See task06-mentor-matching.md for scoring, safe projections and exclusion scope.
No existing migration or hosted schema was changed.
