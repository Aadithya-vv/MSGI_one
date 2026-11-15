# Administration deployment: fresh backup procedure

This procedure is prepared, not authorization to capture a fresh hosted backup
or deploy. Task 11F exercised it with synthetic data only. Keep the existing
encrypted backup; do not replace it. The November 14 backup is not current enough.

## Tools and isolation

Use the already installed Docker, pinned Supabase PostgreSQL 17.11 image, Node
and Windows PowerShell/DPAPI under the authorized Windows account. Use the exact
project `sbgshejyvkptmrffiwvd`, direct database hostname, port 5432, database and
role postgres, trusted pinned Supabase CA and libpq `verify-full`. Reuse the
reviewed host-network IPv6 client restrictions, no insecure fallback or pooled
write route. Never put a password in arguments, connection URLs, SQL or files.

The capture operator must have separately approved read access to the database's
sensitive logical contents. Establish a low-activity window. A trusted temporary
masked handoff supplies the password to the child environment only. Docker/OS
administrators must be trusted: they can inspect process/container memory.

## Capture and seal (future approved operation)

1. Verify the new executor plan and every source/dependency/CA hash. Authenticate
   directly with certificate and hostname verification. Collect
   `snapshotSQL()` from `tool/admin_executor_state.cjs` read-only, plus the complete
   database table/schema inventory required for the recovery scope. Retain only
   aggregate evidence in a user-only restricted backup directory, encrypted.
2. A dedicated client uses **pg_dump**, never psql redirection to a plaintext file:

   ```text
   pg_dump --host=db.sbgshejyvkptmrffiwvd.supabase.co --port=5432
     --username=postgres --dbname=postgres --no-password
     --format=custom --serializable-deferrable
   ```

   Those are ordered argv values, not a connection string. Apply the reviewed
   Docker host network, pinned image, read-only CA mount, `PGSSLMODE=verify-full`,
   `PGSSLROOTCERT=/run/msgi-ca.crt`, timeout and private child PGPASSWORD handoff.
   Capture binary stdout in bounded process memory; never print it. Stop on any
   nonzero exit, timeout, missing managed-schema permissions or unknown warning.
   Do not silently exclude essential tables or retry with weaker TLS.
3. Pass the Buffer to `admin_backup.seal(newDirectory, dump, metadata)`. It creates
   a new current-user-only directory, writes `database.dump.dpapi` and encrypted
   `manifest.dpapi` with exclusive creation, plaintext/cipher SHA-256, original
   capture time, project identity, scope and source aggregate baseline.
   Metadata scope for a separately approved real capture is
   `hosted-predeployment`; it must never be assigned to synthetic artifacts.
   Zero the caller's dump Buffer after sealing. No plaintext dump is persisted.
4. Verify capture consistency using another read-only source snapshot. Any
   changed baseline requires investigation and a separately approved fresh
   capture, not relabeling the old archive. pg_dump itself uses one consistent
   snapshot; successful isolated comparison below establishes captured contents.

No hosted capture entrypoint was enabled or invoked in Task 11F. The command
above is an operator procedure; the migration executor cannot capture a backup
or execute arbitrary supplied SQL. A future automated capture adapter must also
be reviewed before accepting private credentials.

## Disposable restoration and evidence

1. Create a new UUID container with the pinned image, `--network none`, no ports,
   no shared volumes, read-only root and isolated tmpfs. Record its destination
   before restoring. Use a new empty PostgreSQL database. Never reset a valuable
   local database. Never point pg_restore at hosted.
2. Obtain required source role names/ownership/extension prerequisites through
   reviewed read-only metadata, without role passwords. Encrypt this metadata.
   A database pg_dump does not contain cluster roles: a new cluster needs reviewed
   NOLOGIN role stubs and supported extensions. Do not replay source LOGIN,
   SUPERUSER or password attributes blindly. Record omitted capabilities.
3. Check ciphertext and approved manifest SHA-256 before DPAPI decryption. Verify
   plaintext SHA-256 and PGDMP signature in memory. Feed bytes directly to:

   ```text
   docker exec -i <new-isolated-container> pg_restore -h /tmp -U postgres
     -d <new-empty-database> --exit-on-error --single-transaction
   ```

   The placeholder must resolve only to the newly created local destination.
   Capture/sanitize errors in memory; no raw rows or archive output in logs.
4. Compare all tables within the approved recovery scope, counts/fingerprints,
   migration history, functions, ownership, constraints, indexes, effective grants,
   RLS/policies and triggers. Test representative reads. Document actual scope and
   any semantic representation differences explicitly. Unknown differences block
   readiness; do not weaken or disable RLS to make recovery pass.
5. Only after successful comparison, call `admin_backup.attest` with the original
   manifest hash and recovery evidence tied to the exact dump SHA and source
   state. It appends encrypted `ready-manifest.dpapi`; original capture files are
   not overwritten. An operator must review the recovery evidence before approving
   this new receipt hash. A `verified` field alone is not independent evidence.
6. The executor accepts only the explicitly approved ready-manifest SHA, exact
   source state, verified restore evidence and an age of at most four hours. It
   verifies cipher hashes, decryptability and plaintext integrity again. Synthetic
   scope, a stale capture or a changed baseline fails closed.

The tested synthetic archive restores the full synthetic database in a fresh
database; roles already existed within that new disposable cluster. That does
not prove independent cluster-role reconstruction or restoration of the current
hosted managed schemas. Those remain real-capture recovery gates.

## Limits and failure handling

DPAPI CurrentUser is tied to the Windows account/profile. Reinstallation, another
account or another machine recovery is not established. No independent portable
encrypted copy/recovery-key custody is implemented; do not export DPAPI secrets
or weaken encryption. College custody needs a separately approved solution.

A database logical archive does not include SMTP credentials, Auth provider
settings, project JWT configuration, all platform service configuration or
Storage file bytes. Database role global state also needs separate review.
No claim of full Supabase service disaster recovery is made.

Any capture/restore error or unexplained mismatch stops readiness. Preserve the
original encrypted files; no automatic hosted restore, cleanup, repair or retry.
An uncertain migration outcome is investigated read-only first. Restoration to
hosted, a forward fix and a second deployment attempt each need separate approval.
