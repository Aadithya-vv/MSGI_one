# Security model

Authentication identifies the caller. Membership and roles authorize actions.
Never authorize from raw_user_meta_data, a self-declared student/alumni category,
or a Flutter route. A valid JWT alone is insufficient for verified-community data.
Verified checks also require a confirmed Auth email; institutional approval cannot
grant access to an unconfirmed account. Review refuses such approval, and current
membership/directory/map checks fail closed for inconsistent confirmation state.

| Caller | Allowed |
| --- | --- |
| Anonymous | No application tables, membership, directory or map RPCs |
| Authenticated incomplete | Read active onboarding catalogs; submit own pending profile |
| Pending | Read own profile/skills/membership; permitted professional edits and pending resubmission; no directory/map/network/opportunity access |
| Verified student | Community reads, own consent/profile/mentorship, connection requests/transitions, own reports |
| Verified alumni | Student privileges plus publishing/managing own opportunities |
| Rejected/suspended | Own status/profile read for account review; no professional edits or community actions |
| Verified administrator | Explicit trusted role plus verified membership; approve other accounts, view verification audit, moderate reports |
| Trusted server/owner | Catalog administration, first-admin provisioning, exceptional maintenance; never a mobile key |

The migration definitions enable RLS on all thirteen tables. Private authorization/audit tables have
no client table grants or permissive client policies. Direct profile SELECT is
self-only. UPDATE grants exclude identity/institution/batch/privilege columns.
Connections have no direct client mutation grant. Opportunity author identity is
insert-checked and not an editable column. Reports are self-readable/submittable
by verified users, with admin read/moderation boundaries. Existing published
opportunities are not automatically hidden solely because their author is later
suspended; admin content moderation remains necessary.

Directory/map SECURITY DEFINER RPCs intentionally bypass self-only profile RLS
only after checking the caller and filtering targets. Explicit return columns
exclude email, contact details, private review state/reasons and role records.
Map requires both visibility flags and returns only city/country, never GPS.
Functions pin an empty search_path and qualify application objects. There are no
default-definer views. EXECUTE is explicitly revoked from PUBLIC and anon, not
just anon. Review new RPCs/grants with every migration; default Supabase grants
are not assumed safe. Do not expose the private schema in Data API configuration.

Suspension checks use live database membership, not stale JWT metadata. Flutter
refreshes status every sixty seconds and on resume/manual retry, closes routes
while loading or on error, and ignores stale async results after identity changes.
An in-flight SQL statement still follows PostgreSQL transaction snapshot rules;
UI timing is not a database security guarantee. Separate Auth bans/token
revocation and membership suspension must be coordinated operationally.

The client accepts a public publishable key only. It rejects legacy JWT-format
keys and secret/service-role keys. App configuration is extractable; HTTPS and
RLS protect data, not obscured client configuration. Never log tokens/passwords,
raw server errors or build configuration values. Runtime validation cannot erase
a secret incorrectly passed to the compiler; never supply one, and treat any
such artifact as exposed and rotate the secret before further use. Never log
private configuration. Password reset responses avoid
confirming whether an email exists. Hosted SMTP, confirmation, password rules,
rate limits/CAPTCHA and recovery links must be configured and tested separately.

Android backup is disabled and cleartext traffic is disallowed. SDK default
app-private session persistence remains; encrypted device storage, rooted-device
risk and production token/backup handling need a dedicated security review.

## Evidence and remaining release gates

`supabase/tests/database/authorization.test.sql` uses pgTAP, actual role switches,
JWT-claim fixtures, grants, RLS and RPCs in a rollback transaction. It tests
self-verification/admin escalation, unverified/private access, profile ownership,
connection forgery/self/duplicates/transitions, map consent, publishing, suspension,
admin review and anonymous denial. Flutter tests prove app behavior only.

SQL tests and migrations are UNEXECUTED without a local Supabase/PostgreSQL stack.
Static review is not successful policy verification. Run and fix the full suite
on an isolated stack before hosted integration. Then test actual Data API column
exposure, email confirmation/recovery, expiration, logout and suspension with
separate accounts. No hosted project or production credentials were used here.

Audit access/retention, trusted-admin provisioning (including admin account
suspension), verified-claim corrections and external URL/content moderation need
institutional approval. Database owner/service credentials inherently bypass
client policies and must remain in trusted operations only.

References: [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security),
[function security](https://supabase.com/docs/guides/database/functions).

Community RPC quotas, abuse throttling and a trusted moderation workflow for
external links/self-disclosed professional text also need review before exposing
real data. Bounded SQL fields prevent whitespace padding from bypassing length
limits, but field limits are not a complete abuse-prevention system.

Administrators can inspect bounded review queues containing only the
professional/institutional claims needed for review. They are not member or
anonymous directories. Task 11D's **local-only, not-yet-hosted** operations
migration binds each protected administrator role to an approved institution and
scopes new and legacy review/history/moderation projections accordingly. A later
profile institution change does not transfer role authority. Hosted adoption of
this intentional restriction needs separate owner review and deployment approval.

Task 11D also adds revision-checked/idempotent decisions, protected before/after
audits, bounded appeals and an authorized correction path that removes verified
access before owned academic edits. Requests never grant access automatically.
Ordinary users see only their safe reason category/request state; reporter
identities and private notes remain restricted. Owner-only bootstrap/role
lifecycle scripts are not public RPCs. Auth ban/deletion and live role/membership
checks reject privileged requests even with older JWTs. See the institutional
operations/deployment-readiness guides for exact scope and limitations.
