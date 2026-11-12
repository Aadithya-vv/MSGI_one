# Architecture

MSGI One is an Android-first Flutter application. Task 02 is an offline,
public UI preview, not an authenticated application.

`main.dart` mounts Riverpod's `ProviderScope`; `app.dart` composes Material 3 and
the provider-owned GoRouter. `core/routing` owns paths, route construction and
future access guards. The router is disposed with its provider. Startup has an
explicit Get started action, avoiding artificial startup delays.

Welcome/login/signup sit outside `OneShell`. The shell supplies branding, a
permanent SAMPLE PREVIEW label, and Home, Discover, Map, Network, Profile bottom
destinations. Dashboard cards reach mentorship and opportunities within the same
shell. Destination changes use `go`; per-tab history/state persistence is deferred.

| Module | Ownership |
| --- | --- |
| `core/config` | Public constants, no credentials |
| `core/routing` | Paths, router lifecycle, future auth/verification redirects |
| `core/theme` | Light theme, navy/blue/gold colors, typography and spacing |
| `core/widgets` | Page container, shell, branding, cards, loading/empty UI |
| `core/errors` | Safe error messages and optional recovery |
| `features/auth` | Startup, welcome, nonfunctional credential previews |
| `features/home` | Dashboard composition and feature entry points |
| `features/discovery` | Sample alumni domain model, provider filtering, search UI |
| `features/alumni_map` | Clearly illustrative globe placeholder |
| `features/connections` | Network empty state, no mutations |
| `features/profile` | Profile overview, no assumed user identity |
| `features/mentorship` | Sample mentor model, provider data and presentation |
| `features/opportunities` | Sample opportunity model, provider data and presentation |

Domain models have no widget imports. Data providers own immutable sample lists;
presentation consumes providers. Discovery search filtering lives in a Riverpod
family while its transient input remains local UI state. Home composes public
cards/data owned by mentorship and opportunities. Placeholder features do not
need empty repositories or use-case layers.

## Design and accessibility

Navy `#09285B`, blue `#1557A0`, gold `#F5BF30`, background `#F5F7FC`, white surfaces.
Gold is paired with navy text. System typography and built-in icons avoid asset
downloads. Pages scroll and cap width at 960 logical pixels. Cards wrap into one,
two or four columns by available width. Primary actions target at least 48 logical
pixels. Text scaling is preserved; no artificial scale clamp is applied.

Tests exercise all routes at 320, 390 and 840 logical pixels and 100%/200% text
scaling. Widget/layout checks do not substitute for device visual testing or a
screen-reader accessibility audit. Shared loading/empty/error UI is ready for
future asynchronous features.

## Future Supabase integration

The SDK is installed but never initialized or called. No endpoint, key, backend
account, schema or session is fabricated. The next integration must:

1. Approve identity/verification requirements; design migrations, RLS and
   least-privilege grants before protected data access.
2. Validate a build-supplied project URL and public publishable key, initialize
   Supabase once before startup, and expose the client through a provider.
   Client build configuration is extractable and cannot protect secrets.
   Add Android internet permission and approved authentication deep-link/callback
   configuration during integration, after approving the final application ID.
3. Introduce feature-owned repositories; replace sample providers explicitly.
4. Add session and verification providers and centralized GoRouter redirects for
   loading, signed-out, pending-verification and verified states.
5. Enforce authorization independently using Supabase RLS. Never embed a
   service-role key or administrative operations in the mobile client.
6. Test denied/allowed access, session changes, failures and recovery.

Location sharing must be opt-in and revocable. Public preview routes grant no
authenticated access and must not become an authorization shortcut.
