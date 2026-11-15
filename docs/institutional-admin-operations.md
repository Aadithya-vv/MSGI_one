# Institutional administration and college handover

Task 11D, 2026-11-15. Implemented/tested locally only. **No hosted administrator,
deployment, real-user invitation, SMTP activation or accepted college policy is
implied by this guide.** The institution must name accountable owners and approve
the decisions below before operation. No real institutional records are invented.

## Trust and permissions

| Concept | Source | Meaning |
| --- | --- | --- |
| Declared Student/Alumni/Staff | User's own profile | A claim, not a permission |
| Confirmed email | Supabase Auth | Inbox control, not college affiliation |
| Incomplete/pending/verified/rejected/suspended | Protected membership record | Current community authorization |
| Administrator | Protected institution-bound account role plus live verified membership | Review authority within the approved institution |

Staff selection, email suffix, editable Auth metadata, programme selection and
an old JWT never grant review authority. Verified ordinary Staff is not an admin.
An administrative role is bound to an institution when a trusted owner assigns
it. Moving a profile's institutional claim does not move that role. Suspended,
banned, deleted or unconfirmed administrators fail live server authorization.
No public administrator directory or client role-grant RPC exists.

Reviewers can read only necessary scoped academic/professional claims. They do
not receive passwords, Auth tokens, email addresses, documents or raw Auth rows.
The report queue excludes reporter identity. Internal notes/history are private;
ordinary members receive only safe reason categories and their own request state.
Previously viewed data cannot be retroactively withdrawn from an authorized
person's memory. Do not export queues or keep private screenshots; refresh on
permission changes and before decisions. Server authorization is rechecked for
every RPC, independently of Flutter state and session token claims.

## Administrator onboarding and initial bootstrap

The college must designate an independent authorizer, technical operator,
verification-policy owner, support/escalation contact and at least two trained
maintainers. Decide acceptable verification evidence and administrator eligibility;
do not appoint an official because their self-selected type is Staff.

1. Separately approve the exact hosted project, migration and reviewed operation.
   Database/SMTP provisioning are independent approvals. Confirm backup/recovery
   access and that no real-user mail will be triggered unexpectedly.
2. Candidate must be an existing consented, confirmed, non-banned account with
   complete institutional onboarding and reviewed active catalog references.
3. Independently approve identity, institutional claim and role purpose. No client
   field can substitute for this approval. Do not put evidence/document contents
   into the audit reason.
4. A trusted database owner uses `supabase/operations/bootstrap_initial_admin.sql`
   only after migration 12. Review same-session transaction-local approval values
   `msgi.bootstrap_approved`, `msgi.bootstrap_user`, `msgi.bootstrap_kind`,
   `msgi.bootstrap_approver`, `msgi.bootstrap_reason`. Never paste passwords into
   SQL, terminal argv or chat; use the previously reviewed secure owner connection.
5. The operation locks the bootstrap/subject keys, requires pending membership,
   rejects an existing initial administrator, verifies membership explicitly and
   inserts the protected institution-bound role and audit records atomically.
   Exact approved rerun is a no-op, not permission to retry uncertain execution.
6. Verify the role, institution binding, membership and private audit read-only;
   test administrator/non-admin isolation with independently consented accounts.
   Never publish candidate UUIDs or approval notes in public materials.

The legacy bootstrap convention records its subject as audit actor and names the
independent human approver in the private reason. It is not an authenticated
reviewer session. Retain independent owner change records identifying the actual
operator; do not misrepresent this convention as proof of institutional approval.

## Daily membership review

Open Institutional administration only after the server context authorizes access.
Overview shows pending claims, open requests and open reports. Memberships are
filtered by status and declared type, with 30-row server pages. Read the individual
programme/department/affiliation/year/professional details as **declared** facts.
No invented mapping links Science and Humanities to degree programmes.

For Student claims, review name, programme and joining/expected graduation year;
for Alumni review programme, graduation and relevant professional claims; for
Staff review designation and department/affiliation. Programme choice alone proves
nothing. Until the college approves document processing, use approved offline
records/evidence channels and store only a category and minimal decision note.
The app provides no document upload/storage and does not prescribe accepted IDs.

| Decision | Allowed previous state | Result |
| --- | --- | --- |
| Approve | Pending | Verified, explicitly selected verified type |
| Reject | Pending | Rejected, no verified type |
| Suspend | Pending or verified | Suspended, community/admin access closed |
| Reinstate | Suspended | Verified only after independent review and selected type |
| Correction | Rejected or verified | Pending, no verified type; own claim edits reopened |

The verified type is an independent reviewer determination, not copied from the
declared type. If underlying academic claims are wrong, require correction before
final verification rather than silently editing another member's record.
Reason categories: record checked, details mismatch, evidence unavailable, policy
violation, appeal review and duplicate account. Add a concise non-sensitive private
note and explicitly confirm evidence review. Self-review is prohibited.

Each mutation uses the displayed revision and a stable request UUID. An identical
retry produces no duplicate decision/audit. A changed payload with the same UUID
fails; concurrent reviewers cannot overwrite a newer revision. On a stale or
uncertain response close, refresh, inspect history and decide deliberately. Do
not repeatedly click or change a decision to bypass stale-state errors.

## Corrections and appeals

Verified members can request academic correction from their own profile.
Rejected/suspended members see a safe category and can request review from their
status screen. At most one open request exists, with three requests per thirty
days. Submission grants no privilege, does not resubmit onboarding, and cannot
erase a rejection/suspension or audit history.

Authorized reviewers inspect the request badge in the relevant status filter.
For rejected/verified claims, an authorized correction returns the account to
pending. Its owner can then use existing own-profile validation; changes to the
academic claim are recorded with protected before/after values and the actual
member actor. Reapproval is a separate deliberate review. Verified claims remain
immutable through ordinary profile editing until correction is opened. Historical
institution changes do not transfer administrator authority.

For suspended accounts, appeal does not reopen editing or restore access.
An authorized reviewer decides whether reinstatement is justified; if subsequent
academic corrections are needed, open a separate pending correction. A request
is closed by the review decision. Rejection and reapplication are distinct from
an appeal; the app never generates unlimited new applications automatically.

No support address is invented. The default guidance points to an approved
institutional channel and says no contact is configured. An approved public
`INSTITUTIONAL_SUPPORT_LABEL` can be supplied at build time after content review;
it contains public support guidance, never credentials. The college must approve
the actual mailbox/office/contact, response time and appeal escalation process.

## Reports and moderation

Report reasons support harassment, impersonation, inappropriate content, other,
fraud, spam and privacy. Existing reporting paths and table/RPC authorization are
retained. The private admin queue provides target, details, status, last moderator
and count of reports against that target; it does not expose reporter identity.
Existing report details can contain personal content: minimize access and do not
copy them into public communications. No automated finding of guilt is made.

Review under approved institutional policy. Choose resolved or dismissed with a
private reason and confirmation. For a reported opportunity, an explicit
**Resolve and archive opportunity** action atomically closes the report and
soft-archives/closes the opportunity, preserving records. Ordinary resolution
does not suspend an account or alter unrelated content. A warning can be recorded
as an approved policy decision in the audit note, but **no warning email or
notification is sent by this implementation**. Communicate only through approved
channels, with separate authorization where needed.

Suspend a target from the scoped membership list only after independent policy
review. Reinstatement is explicit and does not automatically unarchive an
opportunity or erase reports. Content restoration, evidentiary/legal cases and
Auth bans/token revocation are separately controlled owner operations. A member
suspension blocks fresh protected RPCs even with an old JWT. It is not a claim
that the Supabase Auth session itself has been globally revoked.

Assignment is modest: the committed decision records its reviewer, and stale
revision protection arbitrates concurrent reviews. There is no long-lived case
assignment/notification service; coordinate ownership through an approved private
process rather than assuming a queue item is reserved by opening it.

## Role replacement and emergency access

No app screen can promote an account. `supabase/operations/manage_administrator.sql`
is an owner-only DO operation, not a public function. It requires explicit
approval, existing confirmed operator, distinct subject, reason and grant/revoke
action. Grant requires already verified membership. Do not confuse a UI Staff
profile with a trusted reviewer. The role is scoped to the candidate's reviewed
institution and existing mismatched bindings are rejected for separate review.
Role decisions are audited. It protects the last active institution administrator.

For handover, independently verify a replacement, grant through the approved owner
operation, verify their access with a separate session, then separately approve
revoking the outgoing role. Do not share personal passwords/TOTP seeds. Keep two
approved active maintainers where policy permits. Periodically review inactive
or suspended role holders and revoke authority through the audited owner path.

If all administrators are unavailable, institutional IT uses documented Supabase
organization/database-owner recovery and independent authorization. Investigate
first; use the same audited controls. There is no hidden recovery account,
email-suffix promotion, hardcoded password, automatic first-admin registration or
client bypass. MFA should be required operationally, but this task does not add
an AAL2 client challenge flow or change hosted TOTP. Review that gap before launch.

## Audit, privacy, backup and escalation

Protected verification history remains. New `private.administration_audit` records
reviewer, subject/report identifier, action/category, private note, previous/new
state, request key/hash and server time. Academic correction records include only
relevant academic claims, not biography, Auth secrets or documents. Bootstrap and
owner role operations also record privileged changes. Appeals have protected
request timestamps/statuses. Ordinary users cannot select/insert/update/delete
these private records. Trusted database owners inherently retain maintenance
authority; this is not a cryptographically immutable external audit service.

Audit retention/export/deletion, subject access requests and case confidentiality
need approved institutional policy. No retention duration or unrestricted Auth
delete cascade is promised. Database, Auth, Storage and provider configuration
recovery require coordinated college ownership and testing. Existing DPAPI backup
is account-bound; independent-key and full-service recovery gaps remain documented
in Task 11B. Never reset a valuable database to resolve an operating issue.

| Failure | Safe response |
| --- | --- |
| Access denied | Verify current confirmed membership, role institution, account ban/deletion; do not weaken RLS |
| Stale revision | Refresh queue/history; no blind overwrite or automatic retry |
| Missing programme/affiliation | Stop approval, use correction/approved catalog process |
| Appeal rate limit | Use approved support/escalation; no unlimited account recreation |
| Suspected compromise | Contain membership/role through independent owner approval, preserve evidence; coordinate Auth revocation separately |
| No initial admin | Follow approved owner bootstrap; never client-side promotion |
| Database/network error | Keep restricted access, inspect redacted diagnostics; no reset or fabricated success |
| SMTP unavailable | Pause invites; no disabled confirmation or repeated recovery flood |

Institution must approve incident contacts, verification staffing, evidence rules,
appeal deadlines, moderation standards, escalation and privacy/retention. Conduct
periodic role/scope checks, audit sampling, backup restores, secret/access rotation,
training and offboarding. Transfer Supabase/org billing/domain/SMTP/signing/backup
custody and independent recovery to college-controlled accounts. A successful
technical demo does not constitute institutional acceptance of these policies.

## Review capacity and known operating limits

Illustrative workload: 5 minutes per straightforward claim, 4 productive hours
per reviewer/day → 48 claims/reviewer/day. Two reviewers at that rate handle
about 96/day: 1,000 claims take approximately 10.4 working days and 10,000 take
104.2, before escalations, absence or appeals. A 10% complex-case fraction at
15 minutes adds 1 minute to the average, reducing capacity to 40/day/reviewer.
These are staffing assumptions, not measured throughput or automated verification.

Thirty-row server pages avoid full directory downloads. Pagination uses bounded
offsets and deterministic created-at/ID order; concurrent submissions/decisions
can shift pages. Refresh/restart at page one while clearing a batch. Offsets are
capped at 10,000; a larger unprocessed queue needs reviewed keyset pagination or
an operational partitioning strategy. No representative-scale benchmark is claimed.
There is no fuzzy duplicate-account adjudication, automatic official-record match,
bulk approval, push notification, SLA dashboard, institutional SSO or background
case assignment. Counts and related-report queries need volume/query-plan review
before large batches. Audit growth and retention need budget/monitoring decisions.
Do not advertise automatic alumni verification or a thousands-user service SLA.
