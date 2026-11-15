# Institutional administration deployment review

These are local review artifacts, not hosted deployment authorization. No hosted
write executor is supplied. Do not pass this batch to the catalog runner.

- `admin_execution_plan.json` binds the target, dependencies, migration, batch,
  generator, inventory query, immutable runtime image and future transport rules.
- `admin_execution_batch.sql` is a **disclosed derived batch**, not an unchanged
  migration: its 49 top-level statements comprise the source's 45 statements,
  three transaction-local timeout/string settings and one migration-history
  insertion before the original COMMIT. Schema and history therefore commit
  together. Original migration SQL is stored as dollar-quoted history data.
- `admin_implementation_hashes.json` inventories reviewed source bytes. Raw hashes
  identify exact files; LF hashes normalize CRLF only.
- `admin_rehearsal_summary.json` contains synthetic local evidence only.

The execution-plan digest covers `plan` only: recursively sort object keys
lexicographically, retain array order, serialize compact JSON in UTF-8 without a
BOM or final newline, then SHA-256. The containing envelope is excluded.
SQL batch bytes are protected from checkout newline conversion by `.gitattributes`.

Local commands, from the repository root:

```powershell
node tool/admin_deployment_plan.cjs
node --test tool/admin_deployment_plan.test.cjs
node tool/rehearse_admin_deployment.cjs
node tool/generate_admin_review_hashes.cjs
```

The rehearsal requires the ignored aggregate hosted inventory at
`build/task11e-hosted-inventory.json`, Docker, the pinned pre-existing image and
the existing isolated local stack's Auth schema. It imports no actual user rows.
All mutations target newly named, network-disabled tmpfs containers, with no
published ports or shared database volumes. Failure-case databases are copies
inside that new container only. Never substitute a valuable database destination.

A future executor still needs implementation, code/hash review, a private
temporary credential handoff, fresh backup and owner authorization. It must
enforce the plan's exact host/project, verified CA/hostname, immutable image,
timeouts and environment restrictions, and send the exact batch Buffer through
stdin without shell rewriting. No prior catalog approval applies here.

Run one approved transaction only. A missing COMMIT acknowledgement is an
uncertain outcome, never permission to retry or repair history. Investigate
read-only. Successful acknowledgement also requires independent post-state,
grant and preservation checks. There is no demonstrated down migration; any
forward fix or restoration requires separate approval.

## Task 11F follow-up

The Task 11E files above remain historical review evidence. The new
`admin_executor_plan.json` and `admin_executor_batch.sql` add the implemented
executor identity, fresh backup gate, one-attempt journal, advisory/table locks
and in-transaction baseline check. They require a **new** review/authorization.
`tool/admin_migration_executor.cjs` defaults to authenticated read-only checking;
its execution mode requires a separately approved plan/baseline/backup manifest.
No approval file or real hosted backup is supplied by this task. Do not execute.

Local validation:

```powershell
node --test tool/admin_migration_executor.test.cjs tool/admin_backup.test.cjs
node tool/rehearse_admin_deployment.cjs --task11f
```

The latter adds a synthetic full logical dump/DPAPI/restore rehearsal in the new
network-disabled cluster, then runs existing pgTAP and 5,000-row queue checks.
See `docs/admin-predeployment-backup-procedure.md` for recovery scope and limits.
