# MVP requirements

**MSGI One — One Community. Infinite Connections.** Android-first alumni networking for
MSGI. Target submission: **November 30, 2026**. Solo student developer, faculty
mentor and AI-assisted implementation/review.

## Task 02 scope

- Local Flutter foundation with Riverpod, GoRouter and the future Supabase SDK.
- Branded Material 3 dashboard, eleven reachable screens and bottom navigation.
- Clearly labelled sample profiles/listings; no real personal information.
- Local sample search with a useful no-match state.
- Shared loading, empty and safe-error widgets.
- Route, interaction, filtering and responsive-layout tests; clean analyzer,
  successful Android debug build, documentation and initial local Git commit.

## Planned functional MVP (not implemented by Task 02)

| Area | Requirement |
| --- | --- |
| Identity | Student/alumni registration, authentication, institution-approved verification |
| Profiles | Professional, institutional and graduation information with privacy controls |
| Directory | Authorized search/filtering of verified alumni |
| Map | Consent-based location discovery without disclosing precise private locations |
| Networking | Send, accept, reject and withdraw connection requests securely |
| Mentorship | Explainable recommendations based on interests, goals and availability |
| Careers | Authorized browsing/posting of careers, internships and collaboration |

## Security and quality

RLS, least privilege, secure sessions, explicit verification states, no privileged
client keys, ignored local credentials, loading/empty/error/retry behavior,
scalable readable text, accessible tap targets, and tests for important access
rules. Never present samples as real data or live recommendations.

Task 02 excludes live auth/databases, verification approvals, map SDKs, real
connections, ranking, applications, uploads, notifications, analytics, deployment
and production signing. Prioritize secure identity and profiles next, then the
directory/networking. Confirm the final submission scope with the faculty mentor
before expanding it.
