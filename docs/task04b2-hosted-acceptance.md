# Task 04B.2 - hosted preparation and administrator review

Project reference: sbgshejyvkptmrffiwvd. Owner explicitly designates this project
for MSGI One development/testing only. CLI still calls its main environment
production and project Aadithya-vv's Project; the explicit reference is the target.
All four migration versions were verified deployed via read-only migration list.

## Catalogs are ON HOLD

The owner deferred institutions/departments until faculty approval, and cities
until an approved list exists. No official values are invented or inserted.
The official seed.sql remains unchanged. development.proposed.json contains EMPTY
institutions/departments/cities and a PROPOSED 20-skill starter catalog. Skills are
an application proposal, not official institutional facts and not approved for
hosted insertion yet. All four hosted catalog counts were read as zero.

Render a review-only SQL file without connecting to a database:

```powershell
node tool/prepare_hosted_catalogs.cjs supabase/catalogs/development.proposed.json <review-output.sql>
```

The renderer validates target, lengths, case duplicates, institution mappings and
country codes; quotes SQL data safely and uses a content-derived DO delimiter.
Rendered SQL refuses a non-APPROVED manifest even if someone sets the execution
opt-in. Approved institution/city manifests need documented source and approver.
After values are reviewed, regenerate and inspect the exact SQL and its file hash.
Only separately authorized owner execution may set msgi.catalog_approved=yes.
Conflicts preserve IDs, names and active flags. Inactive/missing parents abort
rather than silently skip departments or reactivate records. No schema change,
user/account creation, update or administrator provisioning is part of import.

Suggested skills awaiting review: Dart, Flutter, SQL, PostgreSQL, Git, Python,
Java, JavaScript, TypeScript, Web Development, Data Analysis, Machine Learning,
Cloud Computing, Cybersecurity, UI/UX Design, Computer-Aided Design, Project
Management, Communication, Teamwork and Problem Solving. These can be approved
separately from the held institutional/city lists. Institution/department/skills
are needed for onboarding; city is optional when map visibility stays disabled.

## Initial administrator: PREPARED, NOT EXECUTED

The owner's exact proposed account UUID was checked read-only in the hosted
project: account exists, email is confirmed, profile/membership do not yet exist,
and no administrator role is present. No email address or credentials were read
or printed. The account-specific disabled review copy is in the developer's Temp
folder: msgi-initial-admin-review.sql. It contains the exact supplied UUID and
reason, approval=no, and unresolved kind/authorizer fields. It is NOT approval-
ready executable SQL until those prerequisites are independently established.
No real account identifiers or permission parameters are committed in templates.

Canonical operation: supabase/operations/bootstrap_initial_admin.sql. It is an
owner-only atomic DO statement, NOT a migration, seed, client method or public RPC.
It would perform exactly:

1. Require explicit approval, candidate UUID, reviewed student/alumni kind,
   independent authorizer and bounded private audit reason.
2. Lock initial-bootstrap and candidate advisory keys and the confirmed,
   non-deleted/non-banned Auth user, membership and profile records.
3. Require complete pending onboarding, active matching institutional catalogs,
   selected skills and a claim matching the independently approved kind.
4. Refuse a different existing administrator; exact audited reruns are no-ops.
5. Set that ONE membership to verified with the approved kind, insert its private
   administrator role, and append the bootstrap audit. The first subject is the
   DB audit actor; the external independent authorizer is recorded explicitly.
6. Abort atomically on mismatch. It never creates an Auth account, trusts signup
   metadata, changes grants/RLS or bypasses the normal RPC self-review prohibition.

The current candidate cannot be provisioned through this operation because no
profile/membership or approved institutional catalogs exist. Do not fabricate
claims or synthetic hosted institutions to clear the guard. A staff reviewer
model independent of student/alumni membership would require a separately
reviewed design/schema task; this task does not introduce that bypass.

Future execution requires review of the COMPLETE account-specific SQL and explicit
owner approval, using the owner SQL editor or CLI db query with the exact remote
reference and file. No execution command is run by this preparation task.

## Administrator application workflow

Verified community membership alone is insufficient. /admin/reviews reads only
pending_memberships; the existing server RPC requires a verified administrator.
Profile shows the entry only after a successful queue permission check; denied
or unavailable checks do not expose tools. Direct-route attempts still require
server authorization. The bounded queue returns at most 100 pending profiles;
process/reload to see further accounts. Institutional IDs remain visible to the
reviewer for comparison with authoritative records; no Auth email is returned.

Decisions require explicit verified kind for approval, a private 1-1000 character
audit reason and evidence-review acknowledgment. review_membership is the only
mutation RPC; self-review is blocked in UI/domain and on the server. Errors are
safe and retryable. Existing pending, verified, rejected and suspended route rules
are unchanged. The screen reviews pending submissions; broader verified-account
administration remains a separate workflow. No client can bootstrap itself.

## Acceptance boundary

Hosted student/alumni onboarding, reviewer approval, profile editing, filtering,
pagination and authenticated privacy acceptance are blocked by the held catalogs
and unprovisioned reviewer. They are NOT claimed as hosted passes. Independent
local API/SQL and Flutter fixture tests cover those authorization paths without
hosted emails/data. Emulator hosted-build checks are signed-out navigation only.
No public registration rollout, hosted seed, privilege change or schema deployment
is authorized/performed here. AGENTS.md's pre-existing user edit is preserved.

Administrator authority is project-wide under the existing RPCs. The audit phrase
Development access only is descriptive, not a per-role sandbox/expiry mechanism;
isolation depends on the owner's development-only project boundary. No automatic
role expiry or institution-scoped reviewer restriction is introduced here.
