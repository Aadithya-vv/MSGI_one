# Task 08C consumer experience

Baseline: f115c0fd17d07b68681eae80a27e815f4b024731.

## Audit priorities

1. Reclaim content space: repeated demo notices and a tall hero prevented first-
   viewport discovery. Numbered identities made the community feel like test data.
2. Make discovery, mentoring and opportunities result-first: compact search,
   integrated filters, horizontally scrollable categories and bounded lazy rows.
3. Make geography the actual screen: full content-viewport offline map, floating
   controls, attribution and draggable city/member results instead of a small map
   embedded in a long form. Preserve all consent and server filtering.
4. Apply semantic colors, compact typography, spacing tokens and reusable person,
   search, filter, status and loading components without dependencies or photos.
5. Preserve demo graph/persistence and tab state; move fictional-data explanation
   to a persistent Demo information action and explicit entry disclosure.
6. Validate phone widths at 100/150/200 percent, prior behavior and new performance/
   state contracts. Inspect native screenshots, refine visible defects, rerun.

## Boundaries

No hosted operations, migrations, privileged accounts, package upgrades or Android
application-ID changes. Real authentication and RPC authorization are unchanged.
All demo organizations are explicitly fictional. Institutions remain generic sample
catalogs. No real photographs, employer endorsements or external image services.

Demo format 2 accepts format-1 snapshots. Only original placeholder copy upgrades;
custom names and post titles, relationships, privacy, mentoring, goals and role
selection survive. The existing dedicated preference namespace stays unchanged.
No real authentication storage is read or cleared by the demo upgrade/reset.

## Implementation

Shared semantic colors and spacing extend the established navy/blue/gold palette.
CompactSearch combines search, submit and filter-count affordances. QuickFilters
scroll horizontally rather than wrapping into a control wall. PersonCard organizes
identity, profession, education, skills, availability and actions. StatusPill and
FeedSkeleton provide compact metadata and honest loading states. PageBody supports
bounded sliver-list builders, preserving pagination while lazily mounting rows.

The demo uses independent StatefulShellRoute branches to retain primary-tab state.
Role switching deliberately replaces that isolated scope; it never grants real
permissions. The small Demo chip opens the fictional-data explanation. Home uses
injected mentor/career repositories; it does not invent production metrics.

The map fills its content viewport and keeps existing grouped city queries and
bundled geography. Floating controls open a filter sheet; the draggable sheet offers
an accessible city list and authorized alumni. Filter application and member
queries keep their existing generation guards and consent checks.

## Verification and visual iteration

Final results and remaining acceptance limits are recorded in verification.md.
No unrelated database suites are needed for this presentation-only task.

## Task 08C visual review iteration

Reviewed the first redesigned emulator screenshots of home, discovery, mentors and
map. The result-first structure and full-viewport map were working, but shortcut
icons were vertically uneven, secondary home buttons still delayed featured
content, mentor actions used too much space and attribution was hidden behind the
expanded city panel. Refined shortcut alignment, moved secondary actions below
highlights, added compact connection presentation/menu placement, and moved source
attribution into the fixed map header. Captured the refined journeys again.

Initial comparison images are retained under build/task08c/initial; final captures
use build/task08/screenshots. Names in the scripted acceptance now match fictional
professional identities rather than numbered placeholders. The scenarios still
exercise requests, acceptance, publication, mentoring, map/profile navigation,
perspective switching, persistence/reset and zero-network operation.

The second visual pass caught a dynamic text-size issue: the demo header consulted
an outer context and retained the full wordmark at 200 percent, squeezing the role.
It now reads the router's actual media context and uses the compact brand icon at
larger text sizes. Added a regression test for changing text scale at runtime.
Map controls are arranged horizontally so the expanded city panel does not hide
World view. These changes received a further native acceptance/screenshot pass.

Final checks: analyzer clean; all 158 Flutter tests passed. Final offline Android
14 emulator scenario passed after two screenshot-driven refinement iterations.
Sixteen screen captures cover the requested journeys, including large text.
The debug APK builds without backend defines. No known blocking UI defects remain
in tested scenarios; at 200% text, content deliberately wraps and scrolls.

Final preparation still needs physical Android 13/14 acceptance, a manual TalkBack
and real-keyboard walkthrough, signed-release profiling/build and demo rehearsal.
These results do not establish hosted readiness or public production readiness.
