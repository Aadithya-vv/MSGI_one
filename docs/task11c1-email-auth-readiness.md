# Task 11C.1 — email and authentication readiness

Reviewed 2026-11-15, Asia/Calcutta. Starting HEAD:
`bd6ba98f3c71eb69dba456af107a72579e464f07`.
**NO-GO for public signup. GO for local preparation and a separately approved,
controlled SMTP pilot.** This audit did not change hosted Auth/SMTP/DNS, TOTP,
catalogs, users, grants, administrators, migrations, signing or Android settings.
The two pre-existing untracked reports were preserved. No email provider account
or purchase was made and no real email was sent.

## Observed backend and Auth state

Fresh authenticated read-only CLI project metadata confirms
`sbgshejyvkptmrffiwvd`, region ap-northeast-2, direct hostname
`db.sbgshejyvkptmrffiwvd.supabase.co`. Its CLI label remains production;
the owner designated this exact project development-only. All eleven migration
versions match local files, with zero pending. Fresh read-only catalog queries
verify exact manifest tuples: 1 MSEC institution, 1 Science and Humanities
department, 13 programmes (9 undergraduate/4 postgraduate), 36 skills. No
catalog deployment was repeated. See the Task 11B.5F deployment report.

Evidence methods: installed CLI `config diff --remote=<exact-ref>
--output-format=json` (documented read-only), project/migration list and
`db query --read-only`; public Auth `GET /auth/v1/settings`. Raw configuration
responses stayed in memory. Only allowlisted policy fields were recorded in
ignored build receipts; no SMTP password, PAT, token or user row was printed.
The configuration diff is a managed projection, not a complete Auth export.
An absent diff for a declared field is evidence of projected agreement, not an
independent runtime test. Unsupported/unmanaged fields remain unverified.

| Setting | Hosted observation | Local preparation | Proposed action, not applied |
| --- | --- | --- | --- |
| Email provider | Public settings enabled | Enabled | Preserve |
| New signup | Public `disable_signup=false` | Enabled | Controlled invitation schedule; not launch approval |
| Email confirmation | Public `mailer_autoconfirm=false` | Required | Preserve required confirmation |
| Minimum password | Explicit remote diff: 6 | 12 | Separately approve server minimum 12; existing passwords are not automatically upgraded |
| Password composition | Remote projection null; local-only empty string | No composition requirement | Do not invent a remote policy; review breached-password feature/plan separately |
| Email OTP length | Explicit remote: 8 | 6 | Preserve hosted 8; no reason to reduce |
| Email OTP expiry | No declared-field diff: 3600 seconds | 3600 | Preserve; one-use behavior tested locally |
| Minimum email interval | No declared-field diff: 60 seconds | 60s | Preserve server throttle; client resend also throttled |
| Email project quota | No declared-field diff: 2/hour | 2/hour | Replace with approved pilot budget after SMTP quota approval |
| Sign-in/signup quota | No declared-field diff: 30/5 minutes/IP | 30 | Preserve initially; monitor shared-campus NAT effects |
| Token refresh/verification quotas | No declared-field diff: 150/30 per 5 minutes | 150/30 | Preserve; confirm dashboard semantics before adjustment |
| Secure email change | No declared-field diff: double confirmation true | True | Preserve both inboxes |
| Secure password change | No declared-field diff: false | False | Separate reauthentication review; do not blindly change recovery behavior |
| Site URL | Explicit remote: `http://localhost:3000` | `http://127.0.0.1:3000` | Neither is a production fallback; approve institution-controlled HTTPS landing page |
| Redirect allowlist | No declared-field diff for exact custom callback | `com.msgi.one.dev://auth-callback/` | Preserve exact entry; inspect final dashboard list before rollout |
| TOTP enroll/verify | Explicit remote: true/true | false/false | **Preserve hosted true/true. Never push whole local config** |
| SMTP active host/sender | Not established by this managed diff/public endpoint | Custom SMTP commented out | Owner dashboard confirmation required; no hidden credentials fetched |
| CAPTCHA | Not established by this audit | Config commented out; no Flutter challenge integration | Treat abuse protection as unverified/rollout blocker |

Historical recovery returned HTTP 429 at the two-email hourly limit. This review
did not trigger hosted signup/recovery to reproduce it or consume quota.
Supabase's built-in mail is restricted to project-team addresses, limited to two
messages/hour and not intended for public delivery. Custom SMTP starts with a
low Auth sending limit which must be reviewed separately from the provider quota.
[Official SMTP guidance](https://supabase.com/docs/guides/auth/auth-smtp).
Per-project, per-IP and per-user windows are separate; a cooldown in the app is
not abuse enforcement. [Official Auth limits](https://supabase.com/docs/guides/auth/rate-limits).

## Provider comparison and recommendation

Official sources checked 2026-11-15. USD unless stated; tax, exchange rates,
Supabase plan, domain cost and optional services excluded. Quota approval,
acceptable-use review and deliverability are not guaranteed by a price table.

| Provider | Testing and recurring cost evidence | SMTP, domain and operating considerations |
| --- | --- | --- |
| Resend | Free: 3,000/month and 100/day. Pro: $20/month for 50,000, $0.90/1,000 overage; no plan daily cap | SMTP, SPF/DKIM and DMARC guidance, domain verification, webhooks/logs. Straightforward pilot UX. Paid/free plan capacity does not establish account-level burst throughput. |
| Amazon SES | Outbound pay-as-you-go $0.10/1,000 plus message data/optional services. Do not budget on free credits. Sandbox: verified recipients only, 200/24h and 1/sec; production quotas are account/region-specific | SMTP credentials, verified identity, DKIM and optional aligned custom MAIL FROM/SPF, DMARC, reputation metrics/SNS/CloudWatch. Lowest marginal cost, greater operational responsibility. |
| Postmark | Free Developer 100/month. Basic displayed $15/month at 10,000; $1.80/1,000 extra | Transactional SMTP, domain DKIM/Return-Path alignment, DMARC, detailed delivery/bounce logs and webhooks. Useful institutional alternative when support/operational simplicity outweigh marginal price. Approval required for live sending. |
| Brevo | Free 300/day; official pricing help lists Starter from $9/month (volume/currency and add-ons vary) | SMTP relay, authenticated sender/domain, DKIM/DMARC, transactional event logs. Confirm exact transactional package/branding and paid quotas before buying; daily free cap is not a burst SLA. |
| ZeptoMail / Zoho CPaaS | Current official page redirects to CPaaS: first 10,000-email credit free, credits valid 6 months. Older official search snapshot says $2.50/credit, but live localized price is not exposed in retrieved page: **paid amount unverified; obtain current quote** | Transactional SMTP, verified DKIM/CNAME and DMARC guidance. Regional account/endpoints and ownership need review. Do not publish an old SPF include blindly; current verification requirements changed. |

Sources: [Resend prices](https://resend.com/pricing),
[Resend SMTP](https://resend.com/docs/send-with-smtp),
[Resend domains](https://resend.com/docs/dashboard/domains/introduction),
[SES prices](https://aws.amazon.com/ses/pricing/),
[SES sandbox](https://docs.aws.amazon.com/ses/latest/dg/request-production-access.html),
[SES DMARC](https://docs.aws.amazon.com/ses/latest/dg/send-email-authentication-dmarc.html),
[Postmark prices](https://postmarkapp.com/pricing),
[Postmark SMTP](https://postmarkapp.com/developer/user-guide/send-email-with-smtp),
[Brevo pricing help](https://help.brevo.com/hc/en-us/articles/208589409-About-Brevo-s-pricing-plans),
[Brevo SMTP](https://developers.brevo.com/docs/smtp-integration),
[Zoho live pricing](https://www.zoho.com/cpaas/pricing.html),
[Zoho SMTP](https://www.zoho.com/cpaas/help/smtp-home.html),
[Zoho domain verification](https://www.zoho.com/zeptomail/help/domains.html).

**Pilot recommendation: Resend Free**, institution-owned, invitation batches well
below 100/day and 3,000/month. Upgrade only after approved usage requires it;
Pro is $20/month at the displayed 50,000 tier. Given the November 30 deadline,
avoid a provider migration or custom email hook during the controlled pilot.
**Long-term institutional recommendation: SES** if college IT owns AWS and can
operate reputation/alerts/quotas; otherwise Postmark is the practical managed
alternative. Choose on staffing and handover readiness, not price alone. Any of
these providers can be institution-owned; billing/administration must explicitly
belong to the college and not rely on a student's personal login.

## Capacity examples

Model assumptions, not measured demand or throughput: onboarding window has one
confirmation/account, 10% one resend, 5% one recovery, 2% one email change requiring
two emails. Round each event count upward. Optional admin invites are zero here;
add one per approved invitation plus any follow-up events. Existing-account steady
month example: 1% resend, 5% recovery, 2% double-confirmed changes = 0.10N emails.

| Registered accounts N | Confirmations | Resends | Recoveries | Change emails | Onboarding total | Steady month example | SES onboarding base estimate |
| ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 25 | 25 | 3 | 2 | 2 | 32 | about 3 | $0.0032 |
| 250 | 250 | 25 | 13 | 10 | 298 | 25 | $0.0298 |
| 1,000 | 1,000 | 100 | 50 | 40 | 1,190 | 100 | $0.119 |
| 10,000 | 10,000 | 1,000 | 500 | 400 | 11,900 | 1,000 | $1.19 |

SES figures are arithmetic at $0.10/1,000, excluding data/minimum billing
granularity/other services; they do not imply sandbox approval. Resend Free
needs at least 1/3/12/119 sending days respectively at 100/day, and 11,900 is
above its monthly allowance. Brevo Free needs at least 1/1/4/40 days at 300/day.
These are theoretical lower bounds, not scheduled targets. A 25-person pilot
could use 32 emails in a short burst and still exceed Supabase's current 2/hour
or a newly enabled SMTP default limit. Reserve recovery capacity; batch
invitations with headroom and back off on 429 instead of automatic resend loops.
Registered users are not concurrent users; no concurrency/capacity claim is made.

## Domain, DNS and transferable ownership

Illustration only: `MSGI One <accounts@auth.college.example>` and a monitored
`support@college.example`. No permission to use a real MSEC domain is assumed.
Use an approved institutional subdomain for transactional email, separate from
marketing and development. DNS owner, registrar recovery and delegated changes
must be documented. Existing college MX and SPF must not be overwritten.

Publish the provider-generated DKIM selectors and requested return-path records.
SPF authenticates envelope MAIL FROM; DKIM/DMARC alignment must match visible
From. One SPF policy per hostname; merge only approved includes and check lookup
budget. DMARC policy begins with approved monitoring (`p=none`, reporting to an
approved monitored address), then quarantine/reject after reviewing alignment;
do not invent a DNS value or tighten a parent institution domain unilaterally.
Provider-managed return paths can pass SPF without visible-From alignment;
aligned DKIM remains essential. Require verification and test headers in actual
Gmail/Outlook mail before launch. SMTP transport encryption alone is insufficient.

College owns provider organization, domain, Supabase organization, billing and
support/recovery contacts. At least two named authorized maintainers with MFA,
least privilege, a shared institutional role mailbox and independently secured
recovery access. Store SMTP sending credentials only in approved secret management
and hosted Auth, never Flutter/build defines/source. Use restricted send-only
credentials where supported. Rotate on handover/incident and on the college's
approved schedule; test replacement before revoking the old credential. Keep an
encrypted approved recovery copy and audit access. Do not export TOTP seeds.

## Flutter, Android and account-access audit

Existing repository uses explicit callback for signup, resend and password reset,
safe generic failures, 429 feedback, 20-second timeout and confirmed-session-only
restoration. Membership verification is separate from email confirmation.
Controller tracks SDK recovery events, protects logout boundaries and clears
invalid/expired link state. SDK initialization has `debug:false`; callback handler
does not print URLs/errors. Source inspection found no application logging of
passwords or tokens in these paths. This is not proof that every OS, provider or
future log is safe; diagnostic callbacks and URL fragments must always be redacted.

Android ID/namespace remains `com.msgi.nexus.msgi_nexus`; callback is exactly
`com.msgi.one.dev://auth-callback/`, singleTop exported browsable activity, explicit
host/path and Flutter default deep linking disabled for app_links handling.
Main manifest denies cleartext and backup. Callback constants, release/debug
identity and platform files were not changed. Custom schemes are not domain-
verified App Links: another app could claim the scheme. A future separately
approved HTTPS App Link needs institution-controlled domain, assetlinks.json with
release signing fingerprint and end-to-end PKCE/SDK compatibility review. Do not
change the scheme just for email styling. Do not promise a first-device PKCE link
works across devices without testing that flow.

Historical Samsung local confirmation/recovery succeeded; hosted login/session/
logout were user-reported. **No new emulator/physical-device acceptance was run in
11C.1.** Local HTTP redirects prove generated callback/session behavior, not Android
intent delivery. New SMTP/template acceptance must explicitly test debug and signed
release callbacks without replacing the preserved competition APK. No email-change
screen or MFA challenge UI exists in the inspected client; backend capabilities
and enabled hosted TOTP must not be advertised as complete client features.
Do not disable TOTP to compensate. Account enumeration is reduced by neutral
recovery/resend messages, but timing/delivery/API behavior was not audited as a
formal enumeration assessment. Never display whether an arbitrary account exists.

## Draft templates and local results

Prepared HTML/text drafts in `supabase/email-drafts/` for signup confirmation,
recovery and email change, with matching proposed subjects in its README. Navy
#09285B, gold #F5BF30, accessible link text, responsive table, no external assets,
tracking, personal metadata or institutional-endorsement claim. Only documented
`{{ .ConfirmationURL }}` is dynamic; no handcrafted tokens/URL concatenation.
[Supabase template reference](https://supabase.com/docs/guides/auth/auth-email-templates).
One-use/expiry wording intentionally avoids promising a duration that may change.
Email-change text supports the existing two-inbox policy. Text drafts are not
automatically supported as a separate hosted MIME field; inspect actual MIME.

`node tool/test_local_email_auth.cjs`: **18 checks passed**, only isolated API
55321/Mailpit 55324 and named clean database. Synthetic `@example.test` accounts:
signup without session, resend, confirmation callback/login, invalid link without
session, recovery callback/password change/login, repeated and expired recovery,
expired confirmation, authenticated email change, no session after first inbox,
second-inbox callback and login using changed address. Timestamp adjustments were
restricted to newly generated synthetic accounts in the isolated database. No
existing account reset, deletion, hosted request or catalog insertion occurred.
Fixture accounts/mail remain local; no credentials were saved or printed.

`node --test tool/email_drafts.test.cjs`: **3 checks passed**, covering permitted
variables/action URL, no executable/tracking content and basic structural labels.
These are static safety checks, not Go-template rendering or screen-reader tests.
Draft templates were not installed even locally. Local flows used existing stock
templates, confirming backend behavior and supported link shape, not new-draft
MIME/rendering. Full draft rendering in disposable Auth/Mailpit and inbox/client
visual checks remain explicit predeployment work. Local legacy Auth limits differ
from proposed production limits; successful local flow does not validate hosted
deliverability, quotas, CAPTCHA or MFA UX.

The required full Flutter regression run initially found a stale Task 11A test
that counted literal SQL VALUES syntax and the old standalone approval guard.
The hardened catalog now uses JSON recordsets inside the guarded atomic bundle.
Only that test was updated: it decodes the actual programme recordset, checks
13 records/9 UG/4 PG, matches each existing programme application key/name, and
requires the current bundle guard. No catalog SQL or application code changed.
`dart format lib test` and `flutter analyze` passed; final full-suite results are
recorded in the checkpoint validation below.

## Abuse, monitoring and outages

Keep email verification and server authorization. Before public signup, review a
supported CAPTCHA provider and Flutter token integration; server enforcement is
required, not merely a widget. Use per-user and per-IP limits, generic responses,
bounded resends and cooldowns. Shared college NAT can affect IP limits; do not
globally loosen them without evidence. Keep an invitation/verification owner and
review backlog process. Do not use disposable fixture accounts as real alumni.

Collect aggregate accepted/delivered/deferred/bounced/complained counts, Auth 429
and 5xx rates, quota/billing headroom and delivery latency, without full bodies,
tokens or recipient addresses in general logs. Store only access-controlled
minimal provider correlation data, with approved retention/deletion. Signed
webhooks must be verified before processing, deduplicated and access-controlled.
Suppress hard bounces and complaints; avoid automatic retry to suppressed
recipients. Illustrative internal early-warning thresholds: bounce >2%, any
complaint, sustained failure >5% or quota >70%; these are conservative operating
proposals, not provider limits. Review provider thresholds before choosing values.

If provider fails, pause invitation/signup batches, preserve existing login and
sessions, show safe retry guidance and escalate through named support. Do not
disable confirmation or send repeated resets. Provider failover is a separately
approved credential/DNS/configuration change with a consented smoke test, not an
automatic switch to an unauthenticated sender. Email scanners may consume one-use
links; test real clients and avoid click tracking/link rewriting. Reserve budget
and quota for recovery rather than filling it with announcements.

## Exact Task 11C.2 approval checklist (not executed)

1. Recheck exact development project/ref, config diff and catalog baseline; preserve
   enabled hosted TOTP and eight-digit OTP. Do not run `config push` on the whole
   local file: it would reduce TOTP and alter unrelated service settings.
2. Obtain college authorization for provider, billing ceiling, sender domain,
   DNS edits, visible sender, monitored support mailbox, owners and credential
   recovery. Approve final subjects/HTML/privacy content and consented recipients.
3. Owner creates college-owned provider account, completes verification and
   confirms sending quotas. DNS administrator reviews each provider-generated
   record and DMARC alignment, including existing SPF/MX implications.
4. Render drafts in disposable Auth/Mailpit, validate actual MIME/link variables,
   expiration and double email change. Test screen-reader/text-only/mobile/dark
   mode and security-scanner behavior. Do not claim these checks passed today.
5. Prepare a targeted Auth change manifest only: retain email provider and
   `mailer_autoconfirm=false`; minimum password 6→12; preserve OTP expiry 3600,
   OTP length 8, TOTP true/true, secure double email confirmation and current
   session policy. Resolve password-composition/breached-password policy explicitly.
6. For Resend pilot propose `smtp_host=smtp.resend.com`, port 465 (implicit TLS),
   `smtp_user=resend`, sender name `MSGI One`, approved sender address and a scoped
   private credential entered through owner dashboard/approved secret handoff.
   Never put the credential in this manifest. Final host/port support must be
   confirmed in the Supabase dashboard; use no insecure transport fallback.
7. Proposed pilot email quota: 30/hour with per-user minimum 60s, provided actual
   provider/account quotas allow it. Keep batches ≤20 invitations/hour and ≤50/day
   initially to reserve recovery headroom. This is a proposal for approval, not
   sufficient for 1,000 simultaneous signups. Keep existing IP quotas initially.
8. Approve an HTTPS Site URL fallback; preserve exact Android redirect, no broad
   wildcard. Add no new production identity without separate review. Configure
   CAPTCHA only after supported client integration and explicit Auth approval.
9. Present exact redacted before/after values and obtain separate authorization
   before saving live SMTP/Auth/DNS/templates. Do not alter administrator roles.
10. After approval, run one consented confirmation/resend/recovery/email-change
    acceptance sequence with quota headroom; confirm SPF/DKIM/DMARC headers,
    delivery/bounce monitoring, release callbacks, neutral failures and sessions.
    Record performed versus pending device tests. No stress test or mass invites.
11. If failure occurs, pause batches and inspect sanitized diagnostics. Restore
    approved previous configuration only under an explicit recovery approval;
    never disable verification/TOTP or weaken RLS. Roll credentials if compromised.

## Handover and remaining go/no-go gates

College must own SMTP account/domain/DNS, Supabase administration, approved
templates, quotas/billing, monitoring/abuse response, support and escalation,
secret rotation, recovery access and institutional verification decisions.
Record two maintainers, contact routes, retention, runbooks and change approvals;
test handover without the student developer's personal accounts. SMTP alone does
not resolve administrator bootstrap, privacy notice/deletion/export/retention,
review ownership, verified-member acceptance or independent backup recovery.

Blockers: authorized domain/DNS/provider/billing owner unavailable; current SMTP
sender and credential status unverified; localhost fallback; six-character server
password policy; no verified CAPTCHA/MFA client UX; unrendered draft MIME; hosted
delivery/callback tests and institutional/privacy/admin acceptance still pending.
Finish a controlled consented pilot before November 30 rather than claiming a
public rollout to thousands. Stop before all live configuration changes.

## Checkpoint validation

- Formatter: 93 Dart files checked; only the updated test was reformatted.
- Analyzer: no issues.
- Flutter regression suite: **193 passed**, after correcting the stale catalog test.
- New isolated local Auth/Mailpit suite: **18 passed**.
- New email-draft static security checks: **3 passed**.
- Fresh hosted read-only identity/history/catalog and public Auth checks passed.
- `git diff --check` passed. No dependency/lockfile content changes.
- Signed competition APK SHA-256 unchanged:
  `aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.
- No Android build/install/device test, live SMTP delivery, new-template rendering,
  MFA-client acceptance or hosted signup/recovery request was performed.

Committed scope: this report; three HTML and three text drafts plus their README;
local Auth test runner; static template tests; the existing catalog test correction.
The unrelated untracked Task 11B.2 and Task 11B.5 catalog-review reports are excluded.
