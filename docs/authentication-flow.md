# Authentication flow

1. No valid build configuration: show development setup; no client is initialized.
2. Valid reviewed configuration: initialize Supabase, restore its persisted session
   and subscribe to auth events. Initialization/network actions have timeouts and
   safe messages. Never render a protected route while checking access.
3. Signed out: startup/welcome, validated login/signup and recovery request.
   Signup sends email/password only, no trusted membership/role metadata.
4. Email confirmation establishes a session when the backend is correctly set up.
   A session with no profile goes to structured onboarding.
5. Onboarding collects display name, claimed student/alumni category, institution,
   matching department, joining/graduation years, optional designation, career
   interests, skills, optional catalog city/country, and independent directory/map
   consent (both off by default). Map requires city and directory visibility.
6. A single onboarding RPC creates pending membership. It cannot self-verify.
7. Pending accounts see refresh/logout. A trusted verified administrator reviews
   membership; approval yields verified student/alumni, otherwise rejected or
   suspended handling. Review reasons/audits are not exposed to ordinary users.
8. Verified members enter existing screens; feature data remains labelled samples.
   Profile includes status refresh and logout. No live directory is claimed yet.

Password recovery has a generic email response and a dedicated password update
route for recovery events. Approved mobile callbacks and cold-start recovery
must be configured/tested in Task 03B; fixture tests do not prove email delivery
or SDK deep-link behavior. Password update never bypasses institutional review.

`AuthRepository` is a domain boundary, `SupabaseAuthRepository` the adapter,
`AuthController` the Riverpod state machine and `access_redirect.dart` the pure
route policy. Router refresh listens to state changes without recreating the
router for every event. Initial destinations survive loading only through
internal route paths, not arbitrary external redirects.

Membership is refreshed manually, on foreground resume and every sixty seconds.
Failures revoke cached UI access. Generation counters discard stale membership
and restoration results after newer session events. Failed logout keeps routes
closed and ignores old token events until a retry succeeds. Auth stream errors
are handled; raw backend exceptions are not surfaced to the UI.

Tests inject repositories under test/ only. There is no production demo bypass.
All eleven original screens remain covered with appropriate signed-out or
verified fixtures. The former anonymous sample-dashboard shortcut is removed.

## Task 03D - Android authentication callback integration

Signup confirmation and recovery now request the exact development callback
`com.msgi.one.dev://auth-callback/`. Add that exact URI (including trailing slash)
to Authentication > URL Configuration > Redirect URLs in the DEVELOPMENT project.
Keep email/password enabled, email confirmation enabled, and minimum password 12;
review SMTP and templates. No dashboard changes were performed by this task.
Use templates that preserve the requested redirect, not a hardcoded localhost URL.

The Android VIEW/DEFAULT/BROWSABLE filter matches that scheme, host and path.
Flutter deep linking is disabled for this activity so Supabase's existing
app_links integration owns auth callbacks instead of GoRouter. Application ID
remains `com.msgi.nexus.msgi_nexus`. A custom scheme can be claimed by another
installed app; the SDK's PKCE flow is retained. An owned verified HTTPS App Link
is a later hardening option. No callback URL alone authorizes community access.

Initialization, email/password login, persisted-session restoration, logout,
error handling and protected navigation reuse the existing implementation.
Membership still comes from my_membership(), never signup metadata. Confirmation
may establish identity; incomplete users go to onboarding and pending users stay
outside the community until independently approved. Recovery events open password
update, then reload membership. No client grants verification or administrator.

Manual Android acceptance (not yet verified): with the approved public build
configuration, register ONE consented developer/student account, follow its
confirmation email on cold and warm starts, confirm incomplete-profile handling,
submit approved catalog selections, observe pending state, test logout/login and
restart/restoration. Request recovery once and verify password update, expired
and reused links, and continued membership restrictions. Do not approve yourself
or bypass confirmation; administrator approval belongs to a separately authorized
trusted operation. Do not paste passwords, tokens or email links into logs/chat.

References: [Supabase native callbacks](https://supabase.com/docs/guides/auth/native-mobile-deep-linking?platform=flutter),
[Flutter plugin deep-link handling](https://docs.flutter.dev/ui/navigation/deep-linking).
