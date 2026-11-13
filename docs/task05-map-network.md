# Task 05: map and professional connections

## Privacy and backend contracts

Migration `20261113000200_map_and_connections.sql` is forward-only and applied only
on the disposable isolated local stack. Hosted deployment requires separate review
and approval. Existing migrations, table RLS and grants remain unchanged.

City catalog centroids are optional, paired, bounded and rounded to one decimal
place. They are reference-city coordinates, never device/home coordinates. No
location permission or tracking is introduced. Both directory visibility and map
consent are required, together with verified membership, confirmed authentication,
alumni profile type and active institution/department. Filtering occurs before
aggregation and pagination. Withdrawing consent removes the member from counts
and member panels on their next load. Counts intentionally describe consenting
members; small groups are not anonymized.

Authenticated verified callers use `alumni_city_clusters` (100 + lookahead) and
`map_city_members` (20 + lookahead). UUID cursors bound each response. City/domain
filters run server-side. Client grouping combines nearby city centroids by zoom;
maximum-zoom overlapping markers offer a city chooser. Public member panels use
an explicit safe projection, without contact details or individual coordinates.

`request_connection` derives the sender from auth.uid(), serializes each pair,
returns existing pending/accepted relationships and rejects self/ineligible peers.
A declined request cannot be reopened; cancelled/removed relationships can be
explicitly requested again. `manage_connection` checks participant, direction and
current state before idempotent transitions. Accepted removal records cancelled,
preserving history. `network_connections` exposes only the caller's relationships
and hides a peer's name/company after visibility or eligibility withdrawal. A
verified student may participate in connections without gaining an alumni detail
page. All five RPCs use SECURITY DEFINER with an empty search_path, qualified
references, revoked public/anonymous access and explicit authenticated grants.

## Geographic data, dependencies and optional tiles

The default map is offline: flutter_map 8.3.2 (BSD-3-Clause), latlong2 0.9.1
(Apache-2.0) and bundled public-domain Natural Earth 110m land polygons. Existing
url_launcher 6.3.3 is promoted to a direct dependency for attribution links.
There are no public demonstration/OSM tile requests in the default build.

Source and license: assets/maps/README.md. An optional MapTiler raster layer is
available only when BOTH `MAPTILER_PUBLIC_KEY` and
`MAPTILER_LOGO_EXEMPT_PLAN_APPROVED=true` are supplied at build time. Use only a
reviewed paid/contract plan explicitly permitting omission of its logo. Free-plan
logo requirements are not implemented, so free accounts must not enable this
flag. The app includes clickable MapTiler and OpenStreetMap attribution. Restrict
the public key as supported; review quotas, pricing, attribution, caching and
current provider terms before enabling. No paid service is necessary for local
use, and no subscription/payment feature is added to MSGI One. Network tile
failure falls back to bundled geography. The optional provider has not been
validated with a production key.

References:
- https://pub.dev/packages/flutter_map/license
- https://www.naturalearthdata.com/about/terms-of-use/
- https://docs.maptiler.com/cloud/api/maps/
- https://docs.maptiler.com/guides/map-design/attribution/add-attribution/
- https://www.maptiler.com/terms/cloud/

## Local validation and fixtures

No hosted synthetic data, administrative provisioning or existing-database reset.
The isolated stack uses API 55321, database 55322, Mailpit 55324; original database
54322 is separate. The separate opt-in synthetic catalog fixture is preserved;
official seed.sql remains an approval template. New API fixtures use clearly
synthetic accounts/cities and persist only in the isolated database.

Run from the repository root with that stack already running:

```powershell
$env:npm_config_offline='true'
$env:npm_config_yes='false'
npx.cmd supabase test db --workdir "$env:TEMP\msgi_one_clean_9a7b7923"
node tool/test_local_network.cjs
flutter run -d emulator-5554 --dart-define=LOCAL_AUTH_TESTING=true --dart-define-from-file=config/backend.auth-test.local.json
```

The API tool strictly checks the local URL and fixed isolated Docker container.
It signs up synthetic accounts, confirms through local Mailpit and uses local
owner SQL solely for verification fixtures (not administrator roles). It tests
actual authenticated HTTP APIs, not client mocks. Never adapt it to hosted use.
An optional private temporary output argument supplies a synthetic account to
`tool/test_local_network_emulator.cjs`; never commit that file. The emulator runner transfers it over stdin to app-private storage, runs the SDK
`integration_test/map_network_test.dart` on emulator-5554, and removes both copies
on success (the Flutter test runner also uninstalls its test APK). Passwords/tokens are never command arguments or printed diagnostics. Neither script loads
hosted configuration. SDK-provided integration_test is a development-only
dependency; no runtime testing code or fake repository is included in the app. Local public configuration remains ignored.

Hosted readiness still requires approved catalogs with reviewed city centroids,
separate approval/deployment of migration five, and properly verified consenting
accounts. Official institutional catalogs and hosted administrator provisioning
remain on hold. Physical-device and hosted map/network acceptance remain pending.

The emulator runner expects a previously built local debug APK. Create a private
fixture with `node tool/test_local_network.cjs <private-temp-json-path>`, then run
`node tool/test_local_network_emulator.cjs <private-temp-json-path>`. The runner
reinstalls the debuggable APK before staging, since Flutter removes test APKs.
Build the normal lib/main.dart APK again after integration testing for manual use.

## Recorded acceptance

Flutter unit/widget tests: 91 passed. Isolated pgTAP: 146 passed. Local HTTP API
checks: 34 passed. One Flutter-native emulator integration scenario passed against
real local services, covering map/profile/network navigation and accept, remove,
send and cancel. SQL/API checks additionally cover decline, duplicate requests,
unauthorized transitions and suspended identities. Physical-device, hosted and
optional online MapTiler acceptance remain unexecuted.
