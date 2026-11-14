# Task 11B.4: guarded hosted schema deployment

**Final status: SUCCESS.** Exactly the seven approved schema migrations were
applied and verified. No further deployment, catalog operation, Auth change,
administrator provisioning or invitation is authorized by this result.

## Authorization, target and source

The owner's Task 11B.4 instructions explicitly authorized these seven migrations
to `sbgshejyvkptmrffiwvd` and accepted the documented independent DPAPI-key and
full-service recovery limitations for this development project.

Source HEAD: `981c7dff4710ddcea9673ce1b8fcb2deb047acb5`.
Initial working tree contained only the previously untracked
`docs/task11b2-backup-preflight.md`; that file was preserved and is not included
in this documentation checkpoint. AGENTS.md and migration files were not changed.

Confirmed target: **sbgshejyvkptmrffiwvd**, via the local CLI link, explicitly
pinned migration commands and returned target metadata. Display name remains
**Aadithya-vv's Project**, CLI environment label **production**. The owner has
designated this exact reference development-only; no inference was made from the
display name. The linked database host is
`aws-0-ap-northeast-2.pooler.supabase.com`; its reference-qualified identity was
checked without printing the connection URL or credentials. Read-only SQL
confirmed PostgreSQL 17.11 and database `postgres`. The optional server project-ref
setting was unavailable, so it was not claimed as independent identity evidence.

## Migration identity and deployment order

Earlier reports recorded versions but not complete file SHA-256 values. Stronger
identity was established against Git blobs at all three reviewed checkpoints:

- Task 11A: `1db24e170c200d23f63acb7f72fd0864ba70bc16`.
- Hosted audit: `9aeab934ca558d55f69ae02b3009e470a5112765`.
- Restore checkpoint/current source: `981c7dff4710ddcea9673ce1b8fcb2deb047acb5`.

All eleven local files, including the four historical migrations, matched every
checkpoint. The hashes below are SHA-256 of the Git/LF representation; Windows
CRLF was normalized for that comparison. Working-file byte hashes were also
recorded locally. No substantive or historical migration edits were made.

| Deployment order | Approved migration | Verified SHA-256 (Git/LF) |
| --- | --- | --- |
| 1 | `20261113000200_map_and_connections.sql` | `e1bcd15b97c29af3f8e64920186d5e0f87e7443d64c5ec010f52823a5d5dd89f` |
| 2 | `20261113000300_mentor_matching.sql` | `fa53b797c56aa516d549b524db31a51be4dc05a6651d8a9497a62b17d5110319` |
| 3 | `20261114000100_career_bridge.sql` | `9ff462c6a5cb2b0c610ad08db0d4fc5389c0e62de1a8577f4c3f06433710a4cc` |
| 4 | `20261114000200_fix_career_filter_ambiguity.sql` | `7db3afb751625657654dcd98c32d92ae7c1a4484485364f8ebcd5f0e64ed121a` |
| 5 | `20261114000300_staff_account_kind.sql` | `18f64096a5498cd882553df83cb7ffa73eada93a4f44c6dc927b959f1b872f5d` |
| 6 | `20261114000400_real_academic_onboarding.sql` | `abbd1a1202827f42103ef9eff1c4f0aa14965a9a59a007ab31a4f0f94b32628f` |
| 7 | `20261114000500_review_academic_claims.sql` | `04218ca6a74254ad5b03e04636d9ccb7099880e3b40bd8c633e0215772351868` |

## Backup and final safety gates

Source backup: `%LOCALAPPDATA%\MSGIOne\backups\sbgshejyvkptmrffiwvd\20261114T134947Z-3d9e4376`.
Manifest SHA-256:
`6ce4fa5779fbff0ec6bafc821ca25bddc5b2fcf52834bd7b49daaebc7d38dbfa`.
All 15 encrypted payload hashes were rechecked successfully without decrypting
or modifying the backup. Its project/identifier and pre-deployment timing match.

Successful isolated recovery evidence:
`msgi-recovery-20261114T174801Z-10347862`, with **52-table coverage, 50 matching
COPY fingerprints and 394 schema checks**. The stored validation result passed.
See [the restore report](task11b3-restore-rehearsal.md). Independent DPAPI-key/copy
recovery and full Supabase service recovery remain unverified and explicitly
accepted for this deployment. Logical restoration is not full disaster recovery.

Fresh pre-deployment checks confirmed:

- Exactly four applied versions, exactly seven pending, no remote-only divergence.
- All 19 existing application function bodies/security settings matched the
  captured reviewed baseline; all 14 existing application tables had RLS.
- All existing application tables were empty; no new table, column or index
  collisions were found against the pending additions.
- No active DDL, waiting locks or advisory locks were observed in the database;
  the read-only local process check found no concurrent Supabase deployment.
  These are snapshot checks, not a guarantee against an external race.
- The final dry run returned the exact seven filenames in order,
  `dryRun: true`, `seeds: []`, `roles: []`, to the pinned reference.
- Installed CLI help confirmed that seeds/roles require explicit inclusion and
  Vault synchronization is excluded with `--skip-vault`.

The reviewed SQL adds structures/constraints and replaces authorized RPCs. It
does not seed catalogs, rewrite profile claims or provision administrators. The
enum addition precedes its consumers; files retain their reviewed transaction
boundaries. No attempt was made to wrap all seven into one transaction.

## Execution

Started UTC: **2026-11-14T18:00:13.7152354Z**.
Finished UTC: **2026-11-14T18:00:35.6744010Z**.

Executed once, after all gates passed:

```powershell
npx.cmd --no-install supabase db push --remote=sbgshejyvkptmrffiwvd --skip-vault --yes
```

`--yes` acknowledges the explicitly approved operation; it does not expand its
scope. No include-seed/include-roles/include-all flags, configuration push, reset,
manual history repair or ad hoc corrective SQL were used.

Exit code **0**. The CLI returned `dryRun: false`, the exact seven migrations,
`seeds: []`, `roles: []`, and the expected target. No additional migration was
applied, and no retry or recovery write was needed.

## Read-only post-deployment verification

Hosted migration list and SQL history agree on these **eleven applied versions**:

```text
20261112000100
20261112000200
20261112000300
20261113000100
20261113000200
20261113000300
20261114000100
20261114000200
20261114000300
20261114000400
20261114000500
```

A further pinned `db push --dry-run --skip-vault` reported up to date, no pending
migrations and no seed/role work. All verification SQL reported read-only mode.

| Verification | Observed result |
| --- | --- |
| Application tables and RLS | 18 tables; RLS enabled on all 18 |
| New tables | `programmes`, `mentor_goals`, `private.mentor_blocks`, `opportunity_skills` present |
| Functions | All 37 latest bodies match the reviewed migration definitions |
| Public RPCs | 28; authenticated execution retained; PUBLIC/anon execution denied |
| All application functions | None executable by PUBLIC or anon |
| SECURITY DEFINER configuration | All 34 such functions retain empty search paths |
| Existing public contracts | Identity arguments and result types preserved |
| Policies | 23; all 19 original policy definitions preserved |
| Constraints/indexes | 103/48; original definitions and expected new named additions present |
| Academic/career/map structure | Expected programme/affiliation/catalog-key, centroid and career-scope columns present |
| Account kind | `student`, `alumni`, `staff` |
| Existing data preservation | All 51 pre-existing non-history tables matched counts and aggregate fingerprints over original columns |
| Catalog/admin/fixture state | All 18 application tables remain empty; no synthetic data or administrator assignment |

The 51-table comparison includes original application/private, Auth and Storage
tables, including profiles, membership/audit/role records, institutional catalogs
and Auth MFA data. Only counts and non-identifying aggregate fingerprints were
processed; no private records are included here. Migration history was compared
separately because its seven new records are intentional. New columns were
excluded from old-row fingerprints using the captured original column lists.

`career_safe_external_url` remains the single intentionally **NOT VALID**
constraint declared by the reviewed migration. This is not an execution failure
and does not certify legacy URLs; the opportunities table remains empty. No
unapproved constraint validation or data repair was performed.

Auth, SMTP, password policy and TOTP configuration were **not intentionally
changed**: no Auth/configuration operation was issued and the migration scope
does not alter those settings. Auth table aggregates remained intact. Management
settings were not independently re-fetched/diffed in this task; unchanged database
data is not proof of unchanged external service configuration.

These are hosted metadata/data-preservation checks, not hosted signup or API
authorization acceptance. No accounts, tokens, email requests or fixture writes
were introduced. Local pgTAP/API evidence remains in the earlier readiness report;
those mutating suites were not run against hosted data.

## Warnings, artifacts and next gates

No migration errors or SQL warning/notice/error markers were observed in captured
execution output. Preflight runner handling was adjusted for normal CLI stderr
and its query-response envelope; the pinned target was then confirmed through
supported CLI target output, without relaxing identity or scope requirements.

The signed competition APK was not rebuilt or modified. Rechecked SHA-256:
`aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.
No signing key, Android configuration, Samsung installation, dependency or
Flutter implementation was changed. Only this safe report is intended for commit;
ignored local evidence is not included. No push was performed.

**Next separately gated stage:** review and approve exact MSEC reference data and
a genuine starter skill catalog, then inspect post-migration catalog conflicts
before any owner catalog operation. Cities, verification authority, consented
administrator bootstrap, SMTP/Auth decisions, privacy/retention/moderation,
independent recovery planning and hosted API/Android smoke tests remain separate
approval/acceptance gates. This schema deployment does not authorize public signup.
