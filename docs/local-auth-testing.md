# Isolated local Android authentication testing

Never use hosted configuration or reset a database for this procedure.
Task 03D follow-up reused the existing disposable project msgi_one_clean_9a7b7923
under the user's temporary directory, with its own database volume/network.
API 55321, database 55322 and Mailpit 55324 are separate from the original stack.
The isolated copy enables email confirmation and allowlists exactly
`com.msgi.one.dev://auth-callback/`; hosted settings were not modified.

The original local stack has email confirmation disabled and must not be used
as evidence for confirmed-email behavior. No existing local users were reset.

## Local-only build and phone access

Use a separate ignored config/backend.auth-test.local.json with only the isolated
API origin http://127.0.0.1:55321 and its local publishable key. Never copy the
hosted config into it. Extract local public fields privately from CLI status;
raw status/start output may contain privileged local keys and must not be logged.

```powershell
adb -s RZ8RA1DN4YA reverse tcp:55321 tcp:55321
adb -s RZ8RA1DN4YA reverse tcp:55324 tcp:55324
flutter run -d RZ8RA1DN4YA --dart-define=LOCAL_AUTH_TESTING=true --dart-define-from-file=config/backend.auth-test.local.json
```

LOCAL_AUTH_TESTING permits HTTP only for 127.0.0.1, only in Dart debug mode.
The Android debug source set allows cleartext only to 127.0.0.1. Main/release
manifest retains cleartext prohibition; release/profile Dart builds require HTTPS
regardless of this flag. No LAN HTTP origin, privileged key or legacy JWT key is
accepted. Supabase diagnostic printing is explicitly disabled to avoid logging
callback URLs/server exception details. Do not add request-body/token logging.

On the phone, create one synthetic local @example.test account, with a password
entered only in the app. Chrome http://127.0.0.1:55324 opens Mailpit. Follow the
confirmation email once, then check incomplete/catalog handling. Log out and
request recovery once. Follow the Mailpit recovery link and confirm the app opens
Choose a new password; update it, then verify login with the new password.
Email contents intentionally contain verification links: they are mailbox data,
not safe diagnostic output. Never paste links/tokens/passwords into logs or docs.

For automated API checks, use an independent synthetic local account and random
passwords held privately. Confirmation, password-update authorization, consumed
and invalid tokens can be tested without a phone. Expiry can be simulated by
aging ONLY that fixture's isolated auth.users.recovery_sent_at beyond OTP expiry;
never alter hosted users, TTLs, RLS or production data. This tests server expiry,
not real elapsed-time mobile behavior. API success does not prove Android UI.

After local testing, rebuild/reinstall with config/backend.local.json and WITHOUT
LOCAL_AUTH_TESTING to return to hosted development. Keep both configurations
ignored. Remove the two ADB reverse mappings when no longer needed. Do not remove
existing Docker volumes. Local synthetic accounts/mail remain isolated test data.
