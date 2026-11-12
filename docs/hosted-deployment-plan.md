# Hosted development deployment plan

Status: PREPARATION ONLY. No hosted create/link/deployment/configuration commands
were executed. Obtain explicit authorization before the future procedure below.
Keep development and production projects, accounts, keys and data separate.
Never copy real personal data into development or test against production.

## Remaining decisions

- Faculty-approved institution names, department mappings, authoritative source,
  approval date and catalog owner; approved skill/city catalogs too.
- Development organization, owner, region, project ref and budget.
- Initial administrator identity, independent verifier, institutional verification
  evidence, community-wide admin authority and audit/retention policy.
- Owned mobile callback origin, SMTP sender/provider, email templates, rate limits
  and token/session policy.

## Project and reviewed migrations

1. Create a dedicated DEVELOPMENT project in the approved organization. Select
   PostgreSQL 17 where supported; otherwise review compatibility first. Record
   its ref and public HTTPS origin without secrets.
2. Confirm the ref against the dashboard URL, organization and development label
   with the owner. Review any ignored `supabase/.temp/project-ref` locally and
   stop on a mismatch. Authenticate interactively with least privilege. Do not
   retrieve/print privileged credentials or put passwords in command arguments.
3. Installed CLI 3.1.0 help confirms these flags; recheck help if it changes.
   The following commands are for a separately authorized session ONLY. Replace
   APPROVED_DEV_REF after the owner check; they were not executed in this task.

```powershell
npx.cmd supabase link --project-ref APPROVED_DEV_REF --workdir D:\MSGI_nexus
npx.cmd supabase migration list --remote=APPROVED_DEV_REF --workdir D:\MSGI_nexus
npx.cmd supabase db push --dry-run --skip-vault --remote=APPROVED_DEV_REF --workdir D:\MSGI_nexus
```

4. Inspect target and plan: a fresh project must apply exactly
   `20261112000100_membership_foundation.sql`,
   `20261112000200_secure_workflows.sql`, then
   `20261112000300_fix_my_membership_ambiguity.sql`. Stop on unexpected history,
   objects, files or target mismatch. Do not reset or repair history to proceed.
   Do not add include-all, include-roles or include-seed flags.
5. After explicit approval of the concrete dry-run plan, execute:

```powershell
npx.cmd supabase db push --skip-vault --remote=APPROVED_DEV_REF --workdir D:\MSGI_nexus
```

6. Recheck migration history, 13 tables/RLS, 17 functions, owner/search paths and
   ACLs. Expose only public for application Data API access, never private; review
   graphql exposure separately. Approved catalogs require separate local
   validation and a reviewed owner operation. The current seed inserts zero rows.
   Do not execute rollback security fixtures against hosted projects.

## Authentication and secure administrator bootstrap

Enable email/password with email confirmation before access. Set password minimum
12 to match the app. Configure approved SMTP, email templates, rate limits/abuse
controls, Site URL and exact redirect allowlist in hosted Auth settings. Database
push does not deploy local TOML Auth defaults.

Approve an owned HTTPS Android App Link with domain association, or an explicitly
approved custom URI callback. Configure matching Android VIEW/BROWSABLE handling
and hosted redirect allowlist; supply the chosen redirect to signup/recovery
requests. Currently the manifest has no callback filter and password recovery
passes no explicit redirectTo. Implement these in a separate small task without
rewriting authentication UI. Verify SDK/Flutter link handling together to avoid
competing handlers. Test cold/warm starts, confirmation, expired/reused links,
password update and logout on actual Android. Recovery still requires membership
checks for community access.

Bootstrap only through a trusted database-owner operation: the designated person
creates an ordinary account, confirms email and submits onboarding. An independent
verifier approves identity and institutional evidence. In one reviewed transaction,
lock the membership, assert confirmed email/profile/pending state, set verified
status and approved verified_kind, insert private.account_roles administrator,
and append private.verification_audit with subject, attributable actor, old/new
status, kind and bootstrap approval reason. Check exact UUIDs and affected row
counts, aborting on mismatch. Record external approval and actor attribution,
including if the first bootstrap requires the subject as the database audit actor.
Do not weaken the normal review RPC's prohibition on self-review or invent an
account for auditing. No public seed, client endpoint or signup metadata may
provision authority. Verify admin APIs afterward and record revocation ownership.

## API acceptance gate

Use the publishable key and consented development accounts with separate JWTs,
never privileged keys for authorization checks. Test anonymous, incomplete,
pending, verified student/alumni, rejected, suspended and administrator callers.
Check REST table/column access, own-only profiles, denied role/self-verification
writes, private-schema denial, safe directory/map payloads and consent, connection
ownership/transitions, publishing, moderation, review and audit restrictions.
Suspend membership with an existing JWT and confirm denial on subsequent server
requests. Verify confirmation, expiry/refresh, logout and recovery separately.
Record redacted expected/actual results without tokens/passwords. Local SQL role
fixtures and Flutter route tests do not prove hosted API gateway behavior.

Hosted integration requires the decisions above and actual API/device validation.
This is not production sign-off.

References: [CLI workflow](https://supabase.com/docs/guides/local-development/cli-workflows),
[local/hosted targets](https://supabase.com/docs/guides/local-development/local-and-hosted-projects),
[Flutter deep links](https://supabase.com/docs/guides/getting-started/tutorials/with-flutter).
Command flags were additionally verified against installed CLI help.

## Task 03D update

The user reports all three migrations deployed to hosted development and matching
local history. This task does not reapply or modify hosted schema/permissions.
Android callback wiring is now implemented; see authentication-flow.md for the
exact redirect allowlist and real-device acceptance procedure. The earlier
callback implementation prerequisite above is superseded by this update, but
actual dashboard configuration and device verification remain outstanding.
