# Task 11B.3: isolated database restore rehearsal

Date: 2026-11-14. Source code checkpoint:
`9aeab934ca558d55f69ae02b3009e470a5112765`.
The pre-existing untracked `docs/task11b2-backup-preflight.md` was preserved.

## Result and scope

**Successful logical restoration of all backed-up application, Auth, Storage and
application migration-history schemas/data into an isolated PostgreSQL target.**
This was a recovery rehearsal, not deployment. No hosted CLI/API/database calls
were made in this task. No hosted writes, Auth changes, administrator assignments,
catalog changes, resets, existing-database restores or Android actions occurred.

This does **not** establish full Supabase service/disaster recovery. Platform
role credentials/attributes, Auth/SMTP/JWT configuration, Vault secrets, Storage
file bytes and service runtime configuration are not reconstructed by these
selected logical exports. Live login/session/Storage-service operation was not
tested. Role shells needed for ownership/ACL restoration were created only in the
new isolated target; this is not administrator provisioning in the application.

## Source backup and permissions

Source project: `sbgshejyvkptmrffiwvd`.
Backup: `20261114T134947Z-3d9e4376`, under
`%LOCALAPPDATA%\MSGIOne\backups\sbgshejyvkptmrffiwvd`.
Primary data file: `data-current.sql.dpapi`.

The manifest project/identifier, file inventory, restricted ACL and all 15
encrypted payloads were checked. Windows DPAPI CurrentUser decryption succeeded
under the authorized account. Each encrypted hash, decrypted hash and plaintext
byte length matched the manifest. The immutable manifest SHA-256 remains:

`6ce4fa5779fbff0ec6bafc821ca25bddc5b2fcf52834bd7b49daaebc7d38dbfa`.

Original backup files were preserved; its historical `actual_restore_executed`
field was not rewritten. New rehearsal state/validation records hold this result.

## Destination and isolation

The initial verified target was
`msgi-recovery-20261114T173755Z-8c189e3a`.
The final extension-compatible repeatable tool was tested end to end in a fresh target:
**`msgi-recovery-20261114T174801Z-10347862`**, database **`recovery`**.
Every target identity was recorded before restoration. Earlier isolated tool-validation targets were `msgi-recovery-20261114T174408Z-f6216470` and `msgi-recovery-20261114T174638Z-f3881421`.

- Existing image: `public.ecr.aws/supabase/postgres:17.11.0.019`.
- Docker networking: `none`; no published ports or network endpoints.
- PostgreSQL `listen_addresses` empty; local Unix socket `/tmp` only.
- No bind mounts or shared/named database volumes; data and socket paths are tmpfs.
- Read-only container root filesystem, dropped capabilities, no-new-privileges.
- Two CPU cores, 1536 MiB memory limit, 768 MiB data tmpfs and 128 MiB temp tmpfs.
- SQL reached only the uniquely named container via `docker exec -i ... psql`.

Targets were stopped after verification. Their memory-backed database data was
ephemeral and is no longer retained. Container identities and encrypted local
evidence remain; no existing database or Docker volume was deleted or reset.
Existing development containers remained running.

## Restore sequence and error handling

The fresh cluster was initialized with compatible extensions and ownership-role
shells, followed by the exported roles, managed Auth/Storage schema, application
schema and application migration-history schema. The primary data export was
loaded in a transaction with **target-session-only** replica mode for COPY;
source RLS/grants/policies were never changed. Foreign keys were independently
checked afterwards. NOT NULL and unique indexes remained enforced during COPY.

`auth.schema_migrations` and `storage.migrations` are intentionally omitted by the
CLI COPY export. Their encrypted JSON supplements were restored into the newly
created, matching empty ledger tables. This must never be used to overwrite
another existing platform installation's ledgers.

All final restore steps exited zero using `ON_ERROR_STOP=1`. The first setup
attempt encountered Docker's refusal to `docker cp` into a read-only rootfs;
no SQL restore had begun. Streaming SQL directly through stdin resolved it.
There were no unexplained SQL restoration errors. The added extension check found that image `17.11.0.018` supplied Vault 0.3.1 while the source required 0.3.2; that attempt was marked failed rather than accepted. The already-installed `17.11.0.019` image provides 0.3.2 and was selected for the final fresh rehearsal. No image download or extension downgrade was performed.

Private staging and logs were restricted to the Windows user outside Git:
`%LOCALAPPDATA%\MSGIOne\recovery\<target-name>`.
Generated SQL was encrypted and verified before removing only its plaintext
staging copies. No plaintext SQL/log exports remain there. Restore error logs
are encrypted because PostgreSQL errors can contain private values.

## Validation results

| Check | Result |
| --- | --- |
| Schema/table coverage | All 52 expected tables present |
| Source versus restored row counts | All 52 matched |
| Order-independent COPY-row fingerprints | All 50 COPY datasets matched; rows/hashes not printed |
| Platform ledger supplements | Both restored; row counts matched |
| Export-declared object checks | 394 passed |
| Functions across selected schemas | 47 restored |
| Application function body hashes, identity arguments, SECURITY DEFINER and search paths | All 19 matched captured source metadata |
| RLS-enabled tables | All 40 expected; includes all 14 application tables |
| RLS policies | All 19 expected policies restored |
| User-defined triggers | All 15 expected triggers restored |
| Explicit exported constraints | All 119 found |
| Total constraints, including inline CHECKs | 205; zero unvalidated constraints |
| Foreign-key data verification after COPY | 50 checked; zero orphan violations |
| CHECK-constraint data verification | 86 checked; zero violations |
| Explicit exported indexes | All 102 found |
| Total indexes, including constraint-created indexes | 171 |
| Auth identity/user relationship | No orphan identities |
| Migration-history recovery | Exactly four original versions, through `20261113000100` |
| Representative read-only queries | Counts, schema metadata, Auth joins, FK/CHECK probes succeeded |
| Extension compatibility | All five recorded extension names, versions and schemas matched |
| Isolation | Network none, zero non-tmpfs mounts, no public ports |

Index/constraint totals exceed explicit standalone declarations because primary
and unique constraints create indexes and CHECKs are declared inline.
The checks verify data/schema recovery; they are not a replacement for the
application pgTAP/API authorization suite or hosted smoke tests.

## Repeatable procedure

Required: Windows PowerShell/.NET DPAPI with the original usable Windows account
keys; authorized local Docker engine access; the already-installed pinned image;
this repository's `tool/recovery` scripts. No software installation or hosted
credentials are required. The tool is deliberately pinned to this exact backup
and manifest, not a general restore utility.

From the repository root, run only under a separate authorized rehearsal:

```powershell
$backup = Join-Path $env:LOCALAPPDATA 'MSGIOne\backups\sbgshejyvkptmrffiwvd\20261114T134947Z-3d9e4376'
powershell -NoProfile -ExecutionPolicy Bypass -File tool/recovery/Invoke-IsolatedRestore.ps1 -BackupDirectory $backup
```

The execution-policy override applies only to this process. It does not change
Windows policy. The tool refuses unexpected source identity/hash/access controls,
generates a fresh destination, uses `--pull never`, restores with stop-on-error,
and runs validation. It never accepts an existing destination as a restore input.
Expected output: 52 matching counts, 50 matching COPY fingerprints, 394 object
checks, no failures, `passed: true`, then `RESTORED` for the newly printed target.
The original source logical exports were captured at different times; recovery
cannot turn them into an atomic cross-service snapshot.

To rerun read-only validation **before stopping that new target**, use its printed
restricted evidence directory:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tool/recovery/Test-IsolatedRestore.ps1 -RecoveryDirectory '<printed-recovery-directory>'
```

The function baseline JSON contains only signatures/security metadata and body
hashes from the four-migration source checkpoint, with no user rows or credentials.
Extension names/versions/schemas are checked against the encrypted source inventory.
Validation is specific to this backup, not the later eleven-migration schema.

After reviewing results, `docker stop --time 20 <exact-new-target-name>` stops
only that rehearsal container. **Its tmpfs database is lost on stop.** Preserve
the encrypted evidence and original backup; future rehearsals create fresh targets.
On any failure, stop, inspect only restricted encrypted logs locally, and correct
the isolated-target procedure. Never retry against an existing valuable database,
print raw error logs, repair hosted data or edit the source backup to obtain a pass.

## Independent recovery limitations

DPAPI CurrentUser ciphertext is not independently portable. A Windows reinstall
without original recoverable DPAPI/profile key material can make it unreadable.
Another account/machine cannot normally decrypt it merely by copying the files
or matching the username. Independent encrypted-copy and Windows key-recovery
processes remain **unverified**. No DPAPI secrets were exported and encryption
was not weakened. Establish an owner-approved independent encrypted recovery
copy/key process before relying on this as disaster recovery.

Storage had zero buckets/objects at capture, so no existing file bytes were lost
from this rehearsal's scope. Later objects require separate backups. Platform
service settings/credentials still require separate recovery planning and a
service-level rehearsal. No release-performance or application-login claim is
made from these database-only checks.

## Deployment recommendation and protected release

**Conditional GO for a separately approved seven-migration schema stage on the
development project; NO-GO for automatic deployment or public signup.**
The logical restore prerequisite now passes. Independent key/copy recovery and
full service-recovery gaps must be resolved or explicitly accepted by the owner.
Reconfirm the exact four-applied/seven-pending history and dry run immediately
before any approved deployment; refresh the backup if hosted data changed.
Retain `--skip-vault`, no seeds/config/roles synchronization, and forward-fix
checkpoints from the preflight report. No seven-migration deployment was performed
or tested by this recovery-only task.

Catalogs, SMTP/Auth decisions, administrator approval/verification ownership,
privacy review and hosted authorization smoke tests remain separate gates.

The competition APK was untouched; expected SHA-256 remains
`aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.
No Flutter/Android changes, builds, dependency changes or unrelated tests were
needed for this database recovery task.
