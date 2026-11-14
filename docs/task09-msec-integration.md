# Task 09: MSEC demo integration and final acceptance preparation

Baseline: ce651da3358dd1fc226eb0551f03c7b3e839eb52.

## Institutional reference data

The user-supplied list defines exactly nine undergraduate and four postgraduate
programmes for Meenakshi Sundararajan Engineering College (MSEC), and one academic
department, Science and Humanities. No intake counts, additional programmes,
department mappings, institutional endorsement or official codes are inferred.
Internal msec-* identifiers are application identifiers, not hosted UUIDs.

AcademicProgramme, AcademicDepartment and InstitutionAcademicCatalog are separate
models. The generic multi-institution structure remains available for future
reviewed catalogs; no MSSM/MCW/NEST information is fabricated. Only the isolated
demo overrides academicCatalogsProvider. Production defaults to no programme
catalog because its reviewed database contract has no programme relationship.
A programme filter sent directly to the real repository fails before an RPC.

Official hosted catalogs, supabase/seed.sql and migrations are unchanged. This
change does not establish hosted onboarding support for degree programmes.

## Demo behavior

MSEC is the active institution for all fictional profiles. Students/alumni carry
programme IDs, names and degree labels; staff uses the separate Science and
Humanities department without a student programme or administrator capability.
All 13 programmes appear across the fictional alumni fixtures. Editing a demo
profile supports programme selection, and discovery filters the same IDs.
Institution changes clear programme/department selection. Names and disclosures
explicitly distinguish real supplied catalog names from fictional affiliations.

Version-three demo snapshots upgrade earlier academic references while preserving
names, biographies, relationships, posts, goals, privacy and mentoring choices.
The preference namespace remains isolated from real authentication storage.
Empty department affiliations are never treated as a shared department for demo
opportunity visibility; degree programmes do not become authorization departments.
No alumni department mappings were supplied, so none are invented.

## Mentor and navigation refinements

Mentor profile navigation and menu actions share one row, with connection actions
below. Actual repository relationship state selects Connect, incoming Accept/
Decline, outgoing Cancel or accepted Remove. Relevance remains deterministic
points, not AI confidence. Academic details remain available in the full profile.

Member links now push details, preserving the originating mentor/map/network/
discovery/home route. Back returns to that route; direct entry has an explicit
fallback. Mentor/opportunity pages have visible parent navigation. Opportunity
create replaces its editor with details; editing returns a save result to one
existing detail page, which reloads. Parent feeds refresh on detail return.
Primary demo branches and the selected role remain intact. UI navigation does not
replace backend authorization, and production authentication guards are unchanged.

## Verification

See verification.md for executed counts and native results. Tests cover exact
catalog integrity, student selection, alumni consistency, staff restrictions,
programme filtering, connection states, previous snapshots, deep-link/system Back,
create/edit history and isolation. Native tests use no hosted configuration and
consume no email quota. Physical hardware, TalkBack/real IME walkthrough and
signed-release acceptance remain separate final steps.

Profile edits also increment a demo-only revision signal. Retained query screens
refresh their existing filters, and profile/highlight caches are invalidated,
without rebuilding the role/tab scope or issuing hosted writes. A regression
covers editing an alumni programme while a previous programme filter is retained.
