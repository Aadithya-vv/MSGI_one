# Task 11B.5C recovery: deployment incident investigation

Follow-up: [Task 11B.5D](task11b5d-secure-connection-review.md) implements host
networking and an official-source pinned CA. Hosted verify-full now reaches the
password challenge; direct authenticated SQL remains pending because the process
credential is unavailable. The incident observations/hashes below are historical.
No retry has been made and no deployment is authorized by the follow-up.

Date: 2026-11-15 (Asia/Calcutta). Source baseline:
`752d8096755d78ebf219516108a53e51dc090ba3`, with the reviewed CLI-response fix
already in the working tree. **No deployment retry or hosted write was performed.**

## Hosted state: Case B, all four catalogs empty

Authenticated project metadata, local link and explicitly pinned read-only CLI
queries confirmed **sbgshejyvkptmrffiwvd** and its database host. The existing
runner's read-only preflight passed, followed by an independent catalog audit:

| Catalog | Observed rows |
| --- | --- |
| Institutions | **0** |
| Departments | **0** |
| Academic programmes | **0** |
| Skills | **0** |
| Total reference records | **0** |

No approved tuples or partial/conflicting reference rows are currently present.
Exactly eleven migrations remain applied through `20261114000500`, matching the
local sequence; no pending/remote-only version was found. Catalog RLS is enabled.

Safe count/fingerprint comparisons for **48 unrelated data tables** all matched
the Task 11B.4 historical baseline, including Auth, profiles, memberships, roles
and audit data. The comparison uses original column projections and only returns
aggregate hashes/counts, not records. Its baseline predates the unknown attempt;
it is not a transaction log or an exact immediately-before-attempt snapshot.

**Commit finding:** no catalog commit is reflected in current state. Under the
approved one-transaction payload, a successful retained commit would contain all
51 records. No evidence of later removal was found. Empty tables alone cannot
prove whether the original client failed before BEGIN or rolled back after BEGIN.
Do not claim a historical ROLLBACK acknowledgement that was never retained.

## Original diagnostic limitations

The reported error was emitted only after the helper's nonempty-password check
and Docker spawn. Therefore the original message is not the helper's
missing-credential validation error. The **current** agent process lacks
`SUPABASE_DB_PASSWORD`; that does not prove what the owner's original terminal
inherited. No unrelated credential stores were read and no password was requested
in chat, stored in Git or used in these connection probes.

The original helper discarded subprocess status/error/stderr and threw a generic
message. Its `--rm` container and cleanup discard container logs; no dedicated
client remains and no matching termination event was retained in Docker's
available event history. No original per-attempt diagnostics file was written.
Thus the exact historical exit code/error and last transaction stage cannot be
recovered from current local evidence. No shell history or raw credential-bearing
logs were searched or printed. New diagnostic test artifacts are not represented
as evidence from the original attempt.

## Reproduced direct-session failure

| Safe read-only probe | Observed result |
| --- | --- |
| Windows DNS for exact direct hostname | IPv6 addresses only |
| Windows TCP to direct port 5432 | Connected |
| Docker default `bridge` IPv6 flag | Disabled |
| Same reviewed psql image on bridge, empty password, verify-full/system | Exit **2**, **network is unreachable**, before TLS/authentication/SQL |
| Candidate Docker host networking, same endpoint/client, empty password, verify-full/system | Network reached; exit **2**, **certificate verify failed** |
| Windows Node SSLRequest/TLS, default verification | `SELF_SIGNED_CERT_IN_CHAIN`; no login or SQL |

The reviewed production path uses Docker bridge. It cannot route this IPv6-only
destination in the observed environment. This is a **definite current connection
blocker and the strongest explanation for the original failure**, but the lost
original stderr prevents proving it was the exact historical error.

The host-network probe was diagnostic only: no change to the runner, Docker
daemon, Windows networking or destination was made. It proves that merely
changing network mode would expose a second TLS trust blocker rather than
provide a deployment-ready resolution. Host-network use was not authorized as a
write fallback and no approval-setting/payload statements were sent through it.

All libpq probes retained `PGSSLMODE=verify-full` and `PGSSLROOTCERT=system`.
Passwords were explicitly empty and the only possible SQL was a read-only
transaction; observed failures occurred before authentication/SQL. Windows Node
sent only PostgreSQL SSLRequest and certificate-validated TLS, with no startup
login/password or SQL. No `rejectUnauthorized:false`, sslmode=require downgrade,
TLS disabling, trusted-root import or certificate exception was used.

Earlier probe attempts found openssl/timeout utilities unavailable in the image;
those failures were diagnostic-tool availability failures, not evidence about
the original psql run. A default .NET TcpClient probe failed and was not used as
TCP evidence; the successful Windows Node TCP and actual psql errors are the
relevant findings. This keeps exploratory failures separate from the conclusion.

[Supabase's SSL guidance](https://supabase.com/docs/guides/platform/ssl-enforcement)
requires its database CA certificate for verify-full. System roots alone are not
an established trust configuration here. The supported SSL metadata GET returned
an error and no certificate; no approved project CA was found in relevant local
config/catalog paths. No untrusted certificate was accepted or copied from a
failed server handshake as a trust anchor.

## Outcome classification

| Possibility | Assessment |
| --- | --- |
| Connection failure before SQL | Reproduced on the exact reviewed bridge path; likely original cause |
| Transaction error/rollback | Possible historically; no original stage evidence retained |
| Successful catalog commit with lost acknowledgement | Inconsistent with current empty catalogs unless an unobserved subsequent removal occurred; none evidenced |
| Present database state unknown | **No**: independent read-only queries established all four catalogs empty |
| Exact historical client stage unknown | **Yes**: original subprocess diagnostics were discarded |
| Current deployment success | **No**: none of the 51 approved records is present |

## Local correction: preserve safe incident evidence

A definite runner defect was corrected locally without altering its connection
network, TLS mode, endpoint, five session controls or approved SQL:

- New `tool/msec_session_diagnostics.cjs` classifies only known failure categories:
  client start/Docker, DNS, routing, refused port, timeout, TLS, missing password,
  rejected authentication, SQL statement and unclassified failure.
- The helper records status/signal/whitelisted native code and whether psql output
  acknowledged BEGIN/COMMIT. No acknowledgement is treated as uncertain, never
  permission to retry. COMMIT acknowledgement after a later session failure is
  explicitly distinguished and still requires independent record verification.
- Evidence is written under ignored build/ with a unique client ID. Only enum,
  boolean and numeric fields are persisted. No raw stdout/stderr, secret, user
  data, SQL, environment or connection string is stored or printed. Injected
  secret fields are rejected in persistence tests.
- Sanitized errors include failure category and status. Thrown spawn errors are
  also sanitized; cleanup exceptions cannot replace them with a raw secret-bearing
  message. Cleanup still targets only the newly named client. There is no retry.

The correction improves diagnosis, **not IPv6 connectivity or CA trust**. The
production runner deliberately remains on the previously reviewed bridge/system
trust configuration until an amended connection plan has been approved.

## Validation and identities

**103 checks passed:** 11 parser tests, 16 new diagnostic/redaction tests and all
76 catalog/session safety checks. Actual SQL was confined to a newly created
network-disabled tmpfs cluster `msgi-catalog-test-1794688168782-c56c851f` with 24
new test databases, then stopped. Existing valuable databases were not reset.

Coverage includes atomic inserts/rollback, idempotency, exact tuples, missing/
wrong approval, wrong project/hash, direct-session lifecycle, commit/lost-ack
classification, TLS/auth/network errors, secret suppression, cleanup and no retry.
Hosted write transport was mocked in tests; only read-only probes reached hosted.

| Identity | SHA-256 |
| --- | --- |
| Approved payload, unchanged | `153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428` |
| SQL/session execution descriptor, unchanged | `b44a29ca2f28188b67388ef557cc0ad1e8646849ddd653334828531d1c5eea83` |
| Main runner file, unchanged from corrected review | `fbe21267ac43a7d3e7562c18712df3fa5eb41f5a6a1aa19030a0f20a1a272cfe` |
| Session helper after diagnostic fix | `8dae0930646c44bc7d95035c797fd0ae9524922fe316143608ea3ab087bc8687` |
| New diagnostics helper | `eaf2ceea2d70da9ce885fd0493dd51e8d389282be980b08bca2f7821c981ff14` |
| Updated production dependency set | `ec50ecee324bbec2a2140376ddb3fc7e843c9d1c64eb869150622f2c8fea567a` |

Raw source hashes are byte hashes. The dependency-set hash is UTF-8 JSON.stringify
of the ordered file-to-hash map: deploy runner, CLI JSON helper, session helper,
diagnostics helper, renderer. The main file hash alone no longer identifies the
whole reviewed implementation. The descriptor hash is unchanged because SQL
operations/transport are unchanged; this does not waive review of diagnostic code.
Any future network/CA change needs an explicit new descriptor and hash, not reuse
of b44a29 merely because record names are the same.

## Safe resolution and remaining owner decision

**NO-GO for another write attempt. No catalog data repair is necessary now.**
Prepare an amended direct connection plan with both:

1. An explicitly reviewed IPv6-capable client/network path. Host networking reached
   the endpoint in a credential-free probe, but no production change was made.
2. The official project/Supabase database CA obtained through a trusted source,
   fingerprint-pinned and supplied read-only to libpq, while preserving verify-full
   and hostname checks. No global trust-store/SSL-enforcement change is needed.

An executable amended hash cannot be finalized until the official trust material
is available and independently verified. A public CA certificate is not a private
key/password; no private key is needed. The minimal later password handoff is an
ephemeral private process environment/secure launcher for one connection, not a
chat message, repository config or persistent plaintext environment setting.

**Single next owner decision:** approve the amended network-and-project-CA trust
plan/material for validation. Only after full read-only TLS/authentication and
fresh backup/project/empty-catalog checks pass should a separate fresh one-attempt
deployment authorization be requested. The original spent authorization does
not permit any retry, including an idempotency rerun or a changed transport.

No hosted data, Auth/SMTP/TOTP/admin/RLS/migration setting or record was changed.
No payload, signing material, competition APK or Samsung installation was changed.
The signed APK checksum remains
`aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.
Backups were not decrypted or modified. Prior unrelated untracked reports remain.
