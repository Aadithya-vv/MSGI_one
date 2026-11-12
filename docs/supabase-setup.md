# Supabase setup — next task, not performed by Task 03A

No hosted Supabase project was created, connected or modified. No real endpoint
or credential has been supplied. No Docker, CLI or database software was installed.
Default builds show setup rather than silently connecting to a demonstration backend.

## Required order for Task 03B

1. Approve the institution verification policy, MVP publishing rules, current
   Android identifier, real institution/department/skill/city catalogs, audit and
   deletion/retention policies, and trusted administrator ownership.
2. Obtain explicit authorization for an isolated local testing environment. If
   Supabase CLI/Docker are unavailable, arrange them deliberately; do not use
   production as a substitute. This task detected neither CLI, Docker nor psql
   on PATH. Do not interpret that as a successful database test run.
3. Initialize the local Supabase CLI configuration without overwriting existing
   migrations (`supabase init`), start the isolated local stack, and apply the
   two migrations in timestamp order. Use a disposable test database only.
4. Run `supabase test db`. The pgTAP file seeds synthetic .invalid identities in
   a rollback transaction and checks actual roles/RLS/RPCs. Fix all failures;
   inspect grants/function ownership/search paths and Data API exposure. No
   local or hosted database reset is authorized by Task 03A.
5. Only after those checks and separate Task 03B authorization, create/use an
   isolated hosted DEVELOPMENT project, review exposed schemas (public only),
   and apply reviewed migrations. Keep production separate.
6. Seed actual approved catalogs through trusted server/owner operations. Create
   an ordinary account, confirm its email and submit onboarding. After independent
   verification, use an owner/server transaction to set its verified membership,
   provision `private.account_roles`, and append an auditable bootstrap reason.
   The app and signup metadata must never provision the first administrator.
7. Configure Auth email confirmation, password minimum 12, SMTP, site URL, exact
   redirect allowlist, rate limits/CAPTCHA and token policy. Approve an Android
   app-link/callback origin and manifest handling for confirmation/recovery.
   Test cold-start and already-running recovery/confirmation before claiming them.
8. Supply ONLY the actual project HTTPS origin and current public publishable
   key through build configuration fields `SUPABASE_URL` and
   `SUPABASE_PUBLISHABLE_KEY`. Legacy JWT-format and privileged keys are rejected.
   Runtime rejection does not remove values already compiled into an artifact;
   never pass a secret to the build at all.
   Never pass credentials in chat or commit local configuration.
9. Put those two real public values in an ignored `config/backend.local.json`
   file on the developer machine. Verify Git ignores it, then run:

```powershell
flutter run --dart-define-from-file=config/backend.local.json -d <android-device-id>
```

No fake JSON values or working credentials are included in the repository.
Client configuration is extractable and is not an authorization boundary.

10. Test separate incomplete, pending, verified student/alumni, rejected,
    suspended and admin accounts. Confirm sign-out/restoration, failed refresh,
    changed membership under an existing JWT, own-only profile access, denied
    table/column writes, safe directory/map payloads, connection ownership,
    authorship and report moderation against the actual API.
11. Replace sample feature data explicitly in a subsequent reviewed change.
    Complete device-at-rest, backup, recovery, deletion/retention and accessibility
    review before production. Keep all privileged operations server-side.

Until database tests execute and hosted/device flows are tested, this is an
implementation foundation ready for controlled integration, not a verified live
authentication system or a production security sign-off.
