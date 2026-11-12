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
