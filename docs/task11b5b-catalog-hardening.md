# Task 11B.5B: atomic MSEC reference-catalog hardening

Historical transport note: the prefix-concatenating write runner and one-hash
execution command below are superseded by the local Task 11B.5C-FIX correction in
[the deployment gate report](task11b5c-hosted-catalog-deployment.md#task-11b5c-fix-validated-local-correction).
The approved catalog file/manifest/hashes remain unchanged; future execution
requires separate approval of the dedicated-session plan as well as the payload.

Date: 2026-11-15 (Asia/Calcutta). Starting HEAD:
`5e653d0ca5a14c025d753b3b67c05c847dcf0010`.
**LOCAL IMPLEMENTATION VERIFIED; HOSTED INSERTION NOT APPROVED OR EXECUTED.**

This supersedes the two-transaction/upsert execution instructions in the historical
Task 11B.5A review, not its approved-for-review record vocabulary. The pre-existing
untracked backup-preflight and catalog-review documents were preserved.

## Exact record manifest

Authoritative complete tuples and skill categories:
[msec_reference_manifest.json](../supabase/catalogs/msec_reference_manifest.json).
Its status remains `REQUIRES_SEPARATE_HOSTED_APPROVAL`. All UUIDs/application keys
are internal identities, not invented official college codes.

Institution: UUID `a1100000-0000-4000-8000-000000000001`, key `msec`, name
**Meenakshi Sundararajan Engineering College (MSEC)**, active `true`.

Department: UUID `a1120000-0000-4000-8000-000000000001`, name **Science and
Humanities**, parent institution above, active `true`. It is not a degree programme.

All programmes have that same parent and active `true`. UUIDs use prefix
`a1110000-0000-4000-8000-` plus the exact suffix shown:

| UUID suffix | Application key | Exact name | Level |
| --- | --- | --- | --- |
| `000000000001` | `msec-ug-ai-ds` | B.Tech. Artificial Intelligence & Data Science | undergraduate |
| `000000000002` | `msec-ug-ai-ml` | B.Tech. Artificial Intelligence & Machine Learning | undergraduate |
| `000000000003` | `msec-ug-civil` | B.E. Civil Engineering | undergraduate |
| `000000000004` | `msec-ug-cse` | B.E. Computer Science and Engineering | undergraduate |
| `000000000005` | `msec-ug-cse-cybersecurity` | B.E. Computer Science & Engineering (Cybersecurity) | undergraduate |
| `000000000006` | `msec-ug-eee` | B.E. Electrical and Electronics Engineering | undergraduate |
| `000000000007` | `msec-ug-ece` | B.E. Electronics and Communication Engineering | undergraduate |
| `000000000008` | `msec-ug-it` | B.Tech. Information Technology | undergraduate |
| `000000000009` | `msec-ug-mechanical` | B.E. Mechanical Engineering | undergraduate |
| `000000000010` | `msec-pg-cs` | M.E. Computer Science | postgraduate |
| `000000000011` | `msec-pg-construction` | M.E. Construction Engineering and Management | postgraduate |
| `000000000012` | `msec-pg-embedded` | M.E. Embedded Systems and Technologies | postgraduate |
| `000000000013` | `msec-pg-energy` | M.E. Energy Engineering | postgraduate |

| Documentation-only skill category | Exact labels |
| --- | --- |
| Programming | C; C++; Python; Java |
| Software development | Git; SQL; Flutter; Software Testing |
| Data and AI | Machine Learning; Data Analysis; Statistics; Data Visualization |
| Networks and systems | Computer Networks; Cybersecurity; Linux; Cloud Computing |
| Electronics and embedded | Embedded Systems; Microcontrollers; Digital Electronics; PCB Design |
| Electrical and energy | Circuit Analysis; Control Systems; Power Systems; Renewable Energy |
| Civil and construction | Structural Analysis; Surveying; Construction Planning; Building Information Modeling |
| Mechanical and manufacturing | Computer-Aided Design; Engineering Drawing; Manufacturing Processes; Thermodynamics |
| Professional practice | Communication; Teamwork; Problem Solving; Project Management |

Skill UUIDs/created-at values remain database-generated for new rows; an existing
exact-name skill retains its original UUID and timestamp. Categories are not
inserted and no schema category field is added. No personal/academic history,
profile, membership, administrator, city or other institution is created.

## Atomicity and strict conflict behavior

[msec_reference_atomic.sql](../supabase/catalogs/msec_reference_atomic.sql) is the
single authoritative SQL entrypoint. It incorporates both generated fragments,
with one transaction, one COMMIT, a five-second lock timeout and 30-second statement
timeout. The four reference tables are locked in SHARE ROW EXCLUSIVE mode before
tuple checks/inserts. Concurrent writers must wait or cause a clean timeout;
each tuple is rechecked inside the write transaction, not trusted from preflight.

For every existing institution, department and programme, the payload checks the
entire approved identity, parent, application key where applicable, exact name,
level where applicable and active state. Every existing skill must have an exact
canonical name from the approved set. Differing UUID/key mappings, name/level/
parent/active values, case variants and whitespace aliases abort. Matching rows
are never updated, including created-at values or UUIDs. Missing rows are inserted
without `ON CONFLICT`, UPDATE or DELETE. Final exact-set checks supplement counts.

This is deliberately a strict **one-time empty-or-approved-subset bootstrap**:
any unrelated row in these four catalogs also aborts, without modifying/deleting
it. It is not a general multi-institution import. Future catalog expansion needs
a separate reviewed operation; the application's multi-institution schema remains
unchanged. Cities and other tables are untouched.

The former `msec.sql` and `starter_skills_proposed.sql` are now reusable guarded
fragments with no independent transaction/COMMIT. Running them directly is
unsupported and refused unless the bundle's session intent flag is present.
These flags do not establish identity or replace database permissions.

Any failure before the single COMMIT rolls back all inserts. A lost response
after execution can leave outcome unknown: inspect hosted state read-only and
seek review before retrying. No automatic rollback-by-deletion/reset is provided.

## Guarded project targeting and credentials

[deploy_msec_reference.cjs](../tool/deploy_msec_reference.cjs) defaults to read-only.
Before any write it checks:

1. Fixed reference `sbgshejyvkptmrffiwvd`, local link and exact eleven-version history.
2. Authenticated CLI `projects list` metadata: matching ID/ref, linked status,
   region `ap-northeast-2` and database host `db.sbgshejyvkptmrffiwvd.supabase.co`.
3. Cached pooler destination: exact reviewed host
   `aws-0-ap-northeast-2.pooler.supabase.com`, reference-qualified database identity,
   PostgreSQL protocol, database `postgres`, allowed ports/TLS options, no URL password.
4. No alternate URL/host/profile/workdir arguments or routing environment/dotenv
   overrides. Existing supported CLI credential storage/access-token workflow is
   used; no service-role key, password or connection string is printed/committed.
5. All manifest/fragment/bundle hashes and deterministic regeneration agree.
6. Read-only actual schema/history/conflict preflight succeeds with the four RLS
   tables. Existing records must be absent or exact approved tuples.
7. Execution requires both `--execute` and `--approve-sha256=<exact-bundle-hash>`.
   Combining execution with `--check` is rejected. Passing approval alone cannot write.

Every database request uses supported CLI `--remote=sbgshejyvkptmrffiwvd` routing;
no arbitrary connection string is passed. Actual destination consistency is
established through the authenticated control plane, validated link/cache and
supported pinned CLI routing, not a caller-supplied project label or SQL GUC.
This assumes a trusted CLI, credential store, workstation and reviewed repository;
it is not protection against an attacker controlling those components. SQL alone
cannot reliably attest Supabase project identity and makes no such claim.

For Windows argument-length safety the runner stages its verified in-memory SQL
snapshot in a uniquely named read-only file under ignored build/, invokes the CLI
with that exact file and removes only that generated file afterwards. These are
public reference values, not secrets/user records. CLI errors are suppressed
rather than printing raw responses. A post-write read-only request verifies exact
tuples/counts instead of assuming a particular multi-statement response shape.
No failed write/post-check is automatically retried.

## Original and hardened hashes

Hashes use SHA-256, UTF-8, LF-normalized bytes; Windows CRLF is normalized before
verification and execution. The runner checks
[msec_reference_hashes.json](../supabase/catalogs/msec_reference_hashes.json).

| Artifact | Original reviewed hash | Hardened hash |
| --- | --- | --- |
| `msec.sql` | `28810c3d401d29b504477bf1e5463085ef2cddff7d587b9671f9938d2e72ed3f` | `63e716f3c364b6a378b271c18eda605a7ecea5cd61e6917d24efdcdebfac4566` |
| `starter_skills_proposed.sql` | `0438c1d1a14e2669ea7da32f255bea305eeeb1a41a9cffd8ef87926d4dd70a0d` | `516a3c49ac53ca28065125f25056ffe0b38725f43ca7af077414f3bce4300843` |
| Exact JSON manifest | New artifact | `17ebf65812b8a38c658a4c5426c9f9853a441b249e61f69d21c701f7c986d2e5` |
| **Atomic deployment payload** | New artifact | **`153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428`** |

Rendering locally (`node tool/render_msec_reference.cjs`) updates the proposal and
hash lock; it grants no approval. Any changed payload needs a new reviewed hash
and explicit owner approval, never reuse of an earlier approval token/hash.

## Executed validation evidence

Final local command: `node tool/test_msec_reference.cjs`.
**57 checks passed: 40 runner/static/control-flow checks and 17 actual database
checks across 15 newly created databases.**

Final disposable cluster: **`msgi-catalog-test-1794681783337-7ae36047`**;
execution evidence is recorded in ignored `build/task11b5b-local-results.json`. Its image is
`public.ecr.aws/supabase/postgres:17.11.0.019`, network `none`, no published ports
or shared volumes, tmpfs-only database storage. The runner copies only schema
from the existing isolated stack, never its account/data rows. Only the new
cluster is stopped afterwards; no existing database is reset or deleted.

Covered outcomes:

- Empty catalogs produce exactly 1 institution, 1 department, 13 complete programme
  tuples (9 UG/4 PG) and 36 skills; rerun preserves timestamps, UUIDs, xmin and ctid.
- Institution name and stable-key/UUID conflicts, programme name/level/UUID-key
  conflicts and inactive records abort with unchanged before/after snapshots.
- Matching skill keeps its UUID; case/whitespace aliases abort. Unrelated institution
  or skill records are preserved while the entire deployment is refused.
- A late failure injected immediately before COMMIT leaves all four tables empty.
  A skill conflict after institutional inserts also rolls back those earlier inserts.
- Wrong project/link/host, altered SQL, connection overrides and missing/wrong hash
  approval refuse before writes. Read-only mode never invokes a write; mock-only
  approved execution invokes one write, then independently verifies read-only.
  A bad post-check stops without retry. No mock test invokes the real hosted write path.
- Payload static checks reject privilege/user/Auth mutation statements. No RLS or
  grants changes are in the payload; local schema is cloned without privileged
  credentials. This suite does not claim hosted application-authorization acceptance.

Actual hosted command executed: `node tool/deploy_msec_reference.cjs --check` only.
It verified the authenticated project/database host and reported **0 institutions,
0 departments, 0 programmes, 0 skills**, eleven applied versions and no conflict.
No hosted SQL write, seed, Auth/SMTP/TOTP change, administrator operation or email
was performed. No emulator/Samsung action, Flutter change/build or migration change
was required. Existing backups and competition APK were preserved.

## Deployment preflight and remaining approval

Expected successful hosted totals: **1 institution + 1 department + 13 programmes
+ 36 skills = 51 reference records**, with zero changes on an identical rerun.

Before deployment, obtain separate approval for this exact 51-record manifest and
atomic payload hash. Confirm the institutional names/levels and catalog stewardship
with the responsible owner/faculty; this technical task invents no institutional
approval. Confirm the shared starter-skill vocabulary separately from curriculum.
Recheck eleven migrations, current catalog state, payload hashes, authenticated
project/destination and backup/recovery checkpoint currency. Independent DPAPI
key/copy and full-service recovery remain unverified, as previously documented.

Read-only preflight:

```powershell
node tool/deploy_msec_reference.cjs --check
```

After a **new explicit approval**, the reviewed future procedure would be:

```powershell
node tool/deploy_msec_reference.cjs --execute --approve-sha256=153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428
```

That command was **not run against hosted Supabase**. Do not bypass the runner by
setting GUCs and executing fragments manually. On any failure stop, inspect exact
state read-only and obtain separate recovery/forward-fix approval; no resets,
deletions, role grants or unreviewed SQL corrections. Public signup, real accounts,
verification ownership, SMTP/Auth decisions, administrator bootstrap, privacy and
hosted API/Android acceptance remain separately gated.
