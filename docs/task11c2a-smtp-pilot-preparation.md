# Task 11C.2A — controlled SMTP pilot preparation

Date: 2026-11-15 (Asia/Calcutta). Starting HEAD
`3a60e23fbbfe527753a7a1005ce316049ac095ac`.
**Preparation only. NO-GO for SMTP activation or public signup.**
No hosted SMTP/Auth/DNS/user/catalog/migration/administrator change or test email
was made. No provider account/purchase, Android identity change, device install,
signing-key access or competition APK rebuild. Existing untracked Task 11B.2 and
Task 11B.5 reports are excluded from this checkpoint.

## Fresh read-only baseline

Authenticated project list, migration list, read-only catalog audit, managed
configuration diff and public Auth settings were rechecked. Exact project
`sbgshejyvkptmrffiwvd`, ap-northeast-2; the owner-designated development project
still carries the CLI's production label. Eleven migration versions match local
history; no pending migration. Exact approved tuples remain 1 MSEC institution,
1 Science and Humanities department, 13 programmes (9 UG/4 PG), 36 skills.

Public settings: email enabled, signup currently enabled, auto-confirm disabled.
Explicit remote config differences: password minimum 6, OTP length 8, TOTP enroll
and verify true, Site URL `http://localhost:3000`. Managed projection shows no
declared-field difference for required confirmation, exact Android callback,
3600-second email OTP expiry, 60-second per-user email interval and 2/hour email
quota. SMTP active sender/host/credential and CAPTCHA remain **unverified** by
these supported projections; they must be inspected in the owner dashboard before
activation. No hidden SMTP credential or full configuration was saved/printed.

Flutter already requests explicit redirects for signup/resend/recovery, accepts
only confirmed sessions, handles 429/expired links with neutral errors, and keeps
institutional membership separate. Android manifest and shared constant retain
`com.msgi.one.dev://auth-callback/`; package/namespace remains
`com.msgi.nexus.msgi_nexus`. This is a custom URI scheme, not verified App Links.
Code inspection and local HTTP redirect tests do not constitute a new Android
intent acceptance test. Retain enabled hosted TOTP; client MFA UX is incomplete.

## Provider-neutral SMTP contract

| Item | Required operator evidence |
| --- | --- |
| Host/port | Provider-documented regional SMTP hostname; approve implicit TLS 465 or supported mandatory STARTTLS 587; never use plaintext fallback |
| Authentication | Dedicated restricted sending credential, least privilege, no account password reuse; host/client compatibility verified |
| Certificate security | Trusted-chain and hostname validation by the managed SMTP client; no verification bypass |
| Sender | Approved owned domain/subdomain, approved sender mailbox and monitored support channel; display name clearly Development |
| DNS | Provider verification records, DKIM, SPF/return-path alignment and DMARC; DNS administrator approves changes and existing MX/SPF coexistence |
| Sending limits | Provider/account per-second/daily/monthly limits and Supabase project/IP/user quotas; recovery headroom and scheduled batches |
| Bounce/complaints | Provider suppression list, verified signed webhooks if used, monitored dashboard, no resend to hard-bounced/complaining recipients |
| Monitoring | Accepted/delivered/deferred/bounced/complained counts, 429/5xx, latency, quota/billing; redacted support correlation, approved retention |
| Secrets | Owner enters credential only in approved secret store/hosted settings; never Flutter, JSON payload files, command arguments, screenshots or logs |
| Portability | Keep SMTP/template settings separate from Flutter; later SES migration changes reviewed server configuration/DNS only, not client auth identity |

Resend is the proposed pilot choice: free 3,000/month with 100/day; preserve
headroom and do not infer a burst SLA from those limits. Official documentation
checked 2026-11-15: [pricing](https://resend.com/pricing),
[SMTP settings](https://resend.com/docs/send-with-smtp),
[verified domains](https://resend.com/docs/dashboard/domains/introduction).
SES or another SMTP provider can replace it after college review; follow its own
identity, regional credentials, sandbox/production quotas and delivery controls.
No Resend SDK or provider key is needed in Flutter.

## Domain and consenting-recipient gate

No eligible personally controlled testing domain, approved sender, consented
recipient list or provider verification evidence was supplied in project context.
**DNS/domain verification is blocked.** Do not infer ownership from an email
address, repository, college name or another app. Do not use an unverified sender
or Resend's shared testing sender as a general recipient service.

A temporary personal testing domain is acceptable only with explicit owner
approval and documented administrative control. Example (not a configured domain):
`accounts@auth.pilot.example`, display `MSGI One Development`; use a monitored
support mailbox and an approved HTTPS fallback under the same controlled setup.
No permission for MSEC's actual domain, endorsement or academic approvals is
implied. Label all pilot messages/screens as development and keep fixture/demo
profiles distinct from actual affiliation claims.

Private roster: initially at most five consenting adult developers/testers,
recorded outside Git in access-controlled operator records with consent date,
email, owner, purpose and expiry. No real alumni invitation lists. Exact email
normalization must match the server's semantics; no wildcard-domain, plus-address
or case assumptions. Do not commit the roster or create those accounts here.

**Restricted signup requires backend enforcement.** Custom SMTP sends Auth emails
for the whole project; merely showing the app to five people does not restrict
the public signup API. Proposed initial containment: `enable_signup=false` until
a separately reviewed server-side exact-email allowlist is approved/tested.
For real signup acceptance, review a Before User Created hook or equivalent
supported server control; fail closed on unknown recipients and hook errors.
This may require separate code/schema/config approval and is not implemented or
activated here. [Official hook contract](https://supabase.com/docs/guides/auth/auth-hooks/before-user-created-hook).

That hook alone does not constrain recovery/resend for existing non-roster users.
Before changing this project's SMTP, require a private owner review that existing
email-capable accounts are in scope, or a separately reviewed recipient-restricting
mail-delivery control. No user records were fetched for this preparation task.
If the project cannot meet that condition, use a separately approved isolated
hosted pilot project; do not disable recovery globally or repurpose this project
without approval. Provider recipient restrictions must be demonstrated, not assumed.
No allowlist entry grants verified membership or administrator access.

## DNS checklist, not DNS values to copy

1. Confirm domain/subdomain ownership, renewal, DNS administrator and consent to
   temporary personal-domain use. Approve eventual college-controlled sender.
2. Obtain exact provider-generated records privately in the owner dashboard;
   review scope/TTL, existing SPF/MX and parent-domain DMARC. No invented selectors.
3. Publish DKIM and provider-required verification/return-path records only after
   approval. Maintain one SPF policy per hostname, merge legitimate includes and
   check lookup budget. Never overwrite college MX or unrelated records.
4. Verify aligned DKIM and/or aligned MAIL FROM/SPF for the visible From address.
   Approve monitored DMARC reports; start monitoring before enforcing quarantine/
   reject. Do not tighten a parent domain by accident.
5. Require provider verified status and independent DNS/header checks; disable
   click/open tracking for Auth links. Domain verification is not inbox delivery
   proof. Record pending propagation rather than sending repeated confirmation.

## Separate Auth change manifest

See [proposal JSON](../supabase/email-drafts/pilot-auth-change-manifest.json).
It is deliberately **not executable**: unresolved sender and HTTPS URL are null,
and no credential or recipient is present. Paths use repository TOML names;
they are not an API request body. Review actual management/dashboard field mapping
before activation. Never run whole-file `supabase config push`.

| Scope | Proposed change | Approval condition |
| --- | --- | --- |
| Password | Hosted minimum 6 → 12 | Targeted Auth approval; does not upgrade old passwords |
| SMTP | Enable approved provider; Resend host smtp.resend.com, port 465, username resend | Managed client supports intended implicit TLS; verify owner account quota and credential |
| Sender | MSGI One Development and verified approved mailbox | Domain/sender ownership and no college endorsement |
| Secret | Private operator entry only | Restricted credential, safe recovery and rotation plan |
| Site URL | Replace localhost with approved HTTPS landing URL | Exact URL supplied/reviewed; no wildcard/placeholder deployment |
| Email quota | Proposed 2 → 30/hour | Actual provider quota confirmed; 10 pilot emails/day initially; reserve recovery headroom |
| Signup | Initially enabled → disabled | Separate owner approval; reopen only after recipient and signup restriction gates pass |
| Templates | Reviewed three HTML drafts, [DEV] subjects | Local render results plus owner content approval; no invitations template change |

Preserve required email confirmation, secure two-inbox email change, eight-digit
OTP, 3600-second expiry, 60-second interval, TOTP enroll/verify true/true, current
session/refresh policy, exact Android callback and other existing redirect entries
unless each is separately reviewed. The JSON lists the required callback, not
permission to replace the entire remote list. Preserve current IP/token quotas.
Do not copy local TOTP false/false or local OTP length 6 into hosted settings.
Password composition, current-password/reauthentication and breached-password
features need their own review; they are not silently bundled with SMTP activation.

CAPTCHA feasibility: Supabase supports hCaptcha/Turnstile, but this client has no
challenge/token integration. Enabling it now could break working signup/recovery.
For a closed allowlisted pilot use approved server containment, quotas and manual
monitoring; public rollout requires a separately implemented/tested abuse strategy.
Do not disable confirmation, TOTP or backend authorization as an alternative.

## Credential handoff and college ownership

Prefer owner-managed dashboard entry: authorized operator signs into provider and
Supabase with MFA, creates only a dedicated send credential, places it directly
in hosted SMTP password and approved secret manager after activation approval.
No credential in Codex prompts/chat, JSON manifest, clipboard history, terminal
argv, screen recording or screenshots. Revoke any accidentally exposed key.
Do not reuse the PostgreSQL password or database deployment handoff for SMTP.

If automation is later approved, first review a fixed-purpose temporary masked
input client with secret-free argv, child-only environment/in-memory handoff,
redacted errors and explicit process cleanup. Do not persist a personal key as a
convenience. No such SMTP credential was requested or accessed in this task.

Temporary personal domain/provider ownership must have an expiry and named
institutional successor. College handover requires an institution-owned provider
organization, sender domain/DNS, billing, monitored role mailbox, at least two
authorized maintainers, MFA/recovery escrow, runbook and delivery/abuse contacts.
Replace the personal pilot sender with approved institutional identity; create a
new college credential, verify it, revoke the old one and remove personal recovery
dependencies. Do not merely share the student's password or TOTP seed. Rehearse
provider-neutral SMTP migration with fresh consented acceptance and DNS review.

## Controlled Task 11C.2B activation checklist

This checklist is a future proposal, not activation authorization.

1. Owner approves the exact project and private roster, testing domain, sender,
   display name, support contact, HTTPS fallback, provider/plan/quota/billing owner
   and temporary personal-domain handover/expiry. Review existing-user mail scope.
2. Approve each DNS record and verify domain/authentication; do not touch unrelated
   institutional records. Prepare bounce/complaint monitoring and suppressions.
3. Approve/test backend recipient/signup restriction and fail-closed behavior;
   keep signup closed until ready. Hook/schema changes need their own review.
4. Snapshot redacted current Auth settings. Present final field-by-field values,
   resolved template hashes, SMTP TLS mode and targeted change request. Exclude
   TOTP, unrelated providers, session policy, migrations and permissions.
5. Obtain explicit approval for this resolved activation scope. Authorized owner
   privately enters SMTP credential. Never include it in the approval manifest.
6. Apply only approved SMTP/Auth/template/DNS changes through supported controls.
   Confirm no settings drift and preserve eight-digit OTP and TOTP true/true.
7. Send one consented sequence, initially ≤10 emails/day and ≤5/hour with ≥60s
   between same-account requests; actual server/provider caps remain authoritative.
   Stop on 429, bounce, unexpected recipient, TLS failure, wrong target or config
   drift. No automatic resend loops and no public invitations.
8. Record the acceptance matrix below. An email arriving alone is not callback,
   membership or secure-recovery acceptance. No new release replaces the preserved
   competition artifact until separately authorized.
9. Pause signup batches on incidents. Preserve sessions/login and required email
   verification. Any provider rollback, setting restoration or secret rotation
   needs explicit scoped approval; never reduce TOTP/RLS or bypass confirmation.
10. Stop and report results before expanding pilot population or real onboarding.

## Acceptance matrix for the authorized operator

| Test | Required evidence | Preparation status |
| --- | --- | --- |
| Real signup | Roster account only; no session before confirmation; non-roster API signup rejected | Hosted pending; no mail sent |
| Delivery | Provider accepted/delivered plus consenting inbox, sender identity and SPF/DKIM/DMARC headers | Pending |
| Android confirmation | Real link opens MSGI One and SDK-validated session; current signed identity retained | Hosted/new-template pending |
| Login | Confirmed account signs in; wrong password gets neutral error | Existing code; local regression |
| Recovery | New mail opens reset screen, valid session updates password; old password fails | Hosted pending; local regression |
| Resend | One request after cooldown, neutral response; newest link only | Hosted pending; local regression |
| Invalid/expired/repeated | No session/privilege grant; useful safe error; existing session behavior reviewed | Local tests; hosted/device pending |
| Pending verification | Email-confirmed account still pending; directory/RPC denied; no metadata privilege grant | Existing tested guards; hosted consented test pending |
| Offline demo | No cloud account/PII enters demo, all roles work offline | Existing automated demo isolation; new device check pending |
| Rate/failure | Test with mocks/local service, not a hosted flood; bounded retry and no token/password logs | Relevant automated regressions; live quota monitoring pending |
| Handover | Second authorized operator can operate without student's personal credential | Pending |

Audit logs must redact full Auth URLs, codes, tokens, password bodies and recipient
lists. Monitor aggregate quota/bounce/complaint/429 trends and support response.
Never forward raw MIME to external screenshot, AI or debugging services.

## Validation results and remaining limits

Local validation completed with the following evidence:

- `dart format lib test`: 93 files, no changes. `flutter analyze`: no issues.
  Full Flutter suite: **193 passed**, including Auth, pending access and demo
  isolation regressions. No application/platform/dependency changes were needed.
- `node --test tool/email_drafts.test.cjs`: **4 passed**. Each draft is explicitly
  Development pilot in HTML/text; only supported ConfirmationURL is dynamic.
  The blocked manifest preserves confirmation/TOTP and cannot resolve a sender
  or HTTPS fallback without owner input.
- **36** actual GoTrue v2.197.0 rendering/Mailpit checks passed for the three custom HTML
  drafts, not stock-template substitution. Assertions require the generated
  development subjects/content and no unresolved variables or active/tracking
  content. Links were redeemed against that same disposable Auth instance.
  Coverage includes signup/resend, confirmation, recovery/password update,
  rejection of the old password, expired/repeated/invalid recovery and two-inbox
  email change. No institutional membership grant was involved in this renderer.
- The runner creates a fresh internal Docker network, unique containers and
  tmpfs PostgreSQL/Mailpit data. Read-only mounts contain only the public drafts
  and fixed-route helper. **No ports are published**, and no network egress is
  allowed. HTTP is carried inside that network via Docker exec/stdin; generated
  passwords/tokens never enter argv, output, persistent files or Docker logs.
  Only preview HTML with action URLs replaced by example.invalid is retained.
  Local SMTP is deliberately unencrypted inside this disposable network; this
  does not validate live provider TLS. Isolated trust authentication and schema
  initialization apply only to this newly created, nonpersistent database.
- Early harness attempts failed on Mailpit reachability, new-database connection
  rules/schema/search path, premature HTTP stdin closure and a no-exec temporary
  template helper. They were corrected only in the throwaway test setup. No
  failed attempt was treated as successful rendering. Existing stacks were not
  reset/reconfigured. Temporary containers/networks are stopped after each run.
- Headless Edge used a fresh profile and loopback-only DevTools. Six sanitized
  previews (three templates at normal and enlarged text) passed **actual 360px**
  viewport checks with no horizontal overflow. Action heights were about 49.6px
  normally and 75.2–126.4px at enlarged text. The first CLI-only attempt actually
  produced 492px despite its requested size and was not counted as 360px evidence.
  Inspected confirmation, enlarged recovery and email-change screenshots show
  readable wrapping, explicit development labels and clear actions. This is
  browser rendering, not a real mail client or assistive-technology acceptance.
- Signed competition APK checksum remains unchanged:
  `aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.
  Final inspection found no remaining disposable rendering containers. Git
  whitespace validation passed. No existing database, signing material, hosted
  Auth setting, recipient, SMTP secret or provider account was modified.

Repeat local rendering: `node tool/test_email_template_rendering.cjs` using the
already installed Docker images; it never pulls images. Then on this Windows
machine run `node tool/preview_email_drafts.cjs` for sanitized browser screenshots
and true-viewport metrics. The latter expects installed Edge at its standard
Program Files (x86) location. Results/previews remain ignored under
`build/email-previews/`; no mail or credential artifacts are committed.

Do not enable these drafts automatically in existing local or hosted Auth. A
real-device pilot still needs separate approval and a resolved sender/recipient
scope. No new hosted message or Android acceptance was performed here.

No claim of Gmail/Outlook, screen-reader or real Android acceptance is made by a
browser/static renderer. Plain text drafts are fallback copy; verify actual MIME
support instead of assuming Supabase accepts a separate text-body setting.

Activation blockers remain: no approved controlled domain/DNS verification, sender,
provider account/credential, private consenting roster, server-side mail/signup
containment, safe HTTPS fallback or operator ownership evidence. SMTP status is
not fully observable through the safe managed projection. Public rollout also
needs institution/privacy/verification ownership and completed MFA/abuse review.
**GO for this preparation checkpoint; NO-GO for activation until these gates and
separate owner approval are satisfied.**
