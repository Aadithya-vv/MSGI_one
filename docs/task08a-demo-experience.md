# Task 08A: isolated competition demo

The app entry offers Explore Demo and the real account experience. Supabase
initializes only on real entry or a validated authentication callback. A build
without backend defines can run the full demo; real access still needs configuration.

## Architecture and isolation

features/demo supplies a deterministic shared store and repository adapters for
catalogs, profiles, map, connections, mentors and careers. A parentless Riverpod
container explicitly has no Supabase client or Auth repository. Presentation
identity never creates an Auth session, verified membership or administrator role.
The production repositories, route guards and backend permissions are preserved.

Only msgi_one.competition_demo.v1 stores versioned demo snapshots. Reset replaces
that snapshot without clearing real authentication storage. Invalid saved state
falls back to fixtures; unavailable persistence produces a memory-only notice.
Perspective changes rebuild the scope while keeping shared state consistent.

The real SDK and scope are disposed before demo entry, without signing out the
real user. Returning restores the real session. Validated callback URIs remain
memory-only and are serialized into the real SDK; failures close access. Explicit
auth callbacks leave the demo. No passwords, tokens or callback URLs are logged.

## Packaged community

- 24 fictional alumni, 8 students and 4 staff/faculty profiles.
- Two generic sample institutions, sample departments, 12 skills and 6 domains.
- Six international cities, 14 mentor opt-ins and 6 initial relationships.
- 12 simulated opportunities: 11 published and one private draft.
- Hidden profiles and map opt-outs exercise privacy-aware behavior.

Staff is a community perspective, not an administrator. No fake verified badges
or institutional/employer endorsements. External application links are disabled;
map geography is bundled and network tiles disabled. Official seed.sql, SQL
migrations, hosted data and administrator permissions are unchanged.

app_links 7.2.2 and shared_preferences 2.5.6 were already locked dependencies;
only their dependency classification changed to direct. No version upgrade.

## Running and validation

Build without backend defines: flutter build apk --debug.
Offline emulator acceptance: node tool/test_demo_emulator.cjs.
Real local gateway check: node tool/test_gateway_auth_emulator.cjs <private-fixture>.
The latter requires the isolated local stack, ignored local auth configuration
and a disposable synthetic account produced by tool/test_local_careers.cjs.
Never use hosted credentials for these tests.

The offline driver temporarily disables emulator Wi-Fi/data and restores their
previous settings. It rejects HTTP client creation and captures eight screenshots.
The real gateway test uses actual local Auth and Mailpit, with scripted callback
transport: this verifies SDK recovery handling, not an operating-system email tap.
Hosted email and physical-device acceptance remain separate. See verification.md
for results and demo-presentation-guide.md for the presentation script.
