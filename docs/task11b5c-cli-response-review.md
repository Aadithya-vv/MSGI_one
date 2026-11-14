# Task 11B.5C: read-only CLI response investigation

Historical identity note: subsequent incident recovery added sanitized session
diagnostics. The main runner/payload/session descriptor identities remain the
same, but session-helper/dependency hashes below are historical. See
[the incident report](task11b5c-deployment-incident.md) for current code identities
and unresolved IPv6/CA blockers; no deployment is currently approved.

Date: 2026-11-15 (Asia/Calcutta). Starting HEAD:
`752d8096755d78ebf219516108a53e51dc090ba3`.
**Deployment not executed. Runner change requires renewed execution-plan review.**

## Exact reproduced cause

Installed Supabase CLI: **3.1.0**, invoked through the existing
`npx.cmd --no-install supabase` workflow. The runner's first CLI request is
`projects list --workdir <workspace>`. It did not select an output format.
Its parser searched stdout for `{`/`[` and assumed a JSON envelope. In a normal
human terminal, `projects list` succeeds with a table, not JSON, so parsing raises
`Expected supported CLI JSON response` before migration/catalog checks run.

The failure was reproduced by forcing supported `--agent=no`. Automatic agent
detection in this tool environment instead returns JSON by default, explaining
why earlier automated checks passed while the same runner failed in a terminal.
This is an output-contract bug, not evidence of an incorrect project or password.

All probes were supported read-only CLI commands. Only response types, field
names, status codes and safe match booleans were recorded; no raw response,
password, token, private row or connection string was logged.

| Command, human mode forced | Default output | `--output=json` | `--output-format=json` |
| --- | --- | --- | --- |
| `projects list` | Human table; fails original parser first | Bare project array | Object with `projects` array |
| `migration list --remote=<approved-ref>` | Human text | Still human text | Object with `migrations` and authoritative `target` metadata |
| `db query --remote=<approved-ref> --read-only <probe>` | Human table | Bare row array | Bare row array in this mode |

The agent-mode query response can instead be an object with `rows`, `boundary`
and `warning`. These are two observed supported query formats. `--output=json`
is therefore not an interchangeable fix: migration list still fails and the
project response no longer matches the runner's expected envelope.

## Safest correction implemented locally

New `tool/supabase_cli_json.cjs` explicitly adds **`--output-format=json`** to
each supported CLI read-only request. It parses exactly one JSON value, allowing
only an initial BOM and whitespace. It does not scrape tables, search stderr,
discard arbitrary prefixes or accept trailing untrusted text.

Command-specific contracts:

- Projects: require the `projects` array envelope. Existing authenticated
  project/database metadata checks still run afterwards.
- Migrations: require `migrations` and `target.project_ref`. No target is invented
  or removed during parsing; existing exact eleven-version/reference checks remain.
- Query: preserve an object with `rows`, or normalize an observed bare row array
  to `{rows: array}`. Existing SQL read-only/database/version/RLS/conflict/count
  checks remain. This normalization does not invent project identity evidence.

Failures identify the command, for example
`Expected supported CLI JSON response from projects list; raw output suppressed`.
Raw stdout/stderr and parse fragments are never included in error messages.
Conflicting output options and unsupported command families fail closed.

The runner's SQL-file staging was adjusted to account for the appended output
flag. No approved SQL is regenerated, concatenated or changed. No project, hash,
credential, direct TLS, approval, atomicity or no-retry check was removed. Backup
verification remains a mandatory independent deployment preflight requirement;
this diagnostic did not decrypt or modify the backup.

## Identities and mandatory renewed review

The approved atomic payload remains:
`153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428`.

The dedicated-session execution-plan identity remains:
`b44a29ca2f28188b67388ef557cc0ad1e8646849ddd653334828531d1c5eea83`.

Neither the payload, session helper, catalog manifest/hash files nor the five
session-control statements changed. The runner implementation **did** change;
the previous approval is not treated as approval to deploy through it.

New CLI response-contract SHA-256:
`9530698dc297c73f07caff55a3b63fc36d76444124de03ca20b5005f6acd40be`.
This is SHA-256 of UTF-8 `JSON.stringify(CONTRACT)` exported by the new helper,
not a replacement SQL or session-plan hash. Its descriptor binds the explicit
format flag, strict parsing policy, three response structures and review requirement.

Execution now additionally requires
`--approve-cli-response-sha256=9530698dc297c73f07caff55a3b63fc36d76444124de03ca20b5005f6acd40be`.
It still requires the original payload and execution-plan approvals. Without
renewed review and this additional approval, the old deployment command refuses
before CLI/SQL execution. Read-only `--check` needs no deployment approval.

No deployment command is run or authorized by this investigation. Future approval
must explicitly review the corrected runner/response contract, preserve the
original plan/payload identities, and require all fresh credential, destination,
TLS, backup, migration, concurrency and empty-catalog gates.

## Tests and execution evidence

- `node --test tool/supabase_cli_json.test.cjs`: **11 passed**. Covers explicit
  flags, all supported envelopes, bare query arrays, BOM, human-table rejection,
  missing migration target, malformed/scalar/prefixed/trailing output, suppressed
  sensitive test markers and stable contract hash.
- `node tool/test_msec_reference.cjs`: **76 passed**, including every existing
  catalog/session check and the new renewed-review refusal. Actual SQL remained
  in a newly created network-disabled disposable local cluster; hosted execution
  was mocked. Existing local databases were not reset.
- Corrected command executed **read-only**:
  `node tool/deploy_msec_reference.cjs --check --project-ref=sbgshejyvkptmrffiwvd`.
  Passed authenticated project/destination checks, eleven applied migration
  history and catalog preflight. Observed all four catalog counts **0**.
- Forced-human-mode probes verified supported machine-format output and parsing
  for projects, migration history and a query reporting transaction read-only mode.
  These confirm the terminal scenario, not just automatic agent detection.

There were no hosted writes, migrations, session-approval controls, direct write
connections, Auth/SMTP/administrator/RLS changes or record insertions. Direct
TLS/password/backup freshness are not claimed newly verified by a CLI parsing
test. No Samsung/app installation or competition APK action was performed.

Intentional local changes: runner, new JSON helper/tests, existing safety-suite
approval fixture, decisions note and this report. The already modified deployment
gate report and pre-existing untracked reports were preserved. No commit or push
was performed. Stop before deployment and obtain renewed execution-plan review.

## Corrected runner execution review: PASS

Review date: 2026-11-15 (Asia/Calcutta). Baseline revision:
`752d8096755d78ebf219516108a53e51dc090ba3`.
This review changed documentation only. The existing corrected implementation
was inspected and tested without deploying or authorizing deployment.

### Precise old-versus-new comparison

| Concern | Reviewed original runner | Corrected runner |
| --- | --- | --- |
| CLI output | Relied on automatic agent detection | Explicit `--output-format=json` for supported CLI calls |
| JSON parsing | Searched for the first bracket/brace | Strict single JSON value; leading BOM/whitespace only |
| Projects/migration responses | Assumed envelopes without explicit format | Validates the envelopes; migration target metadata retained |
| Query rows | Expected rows envelope | Accepts supported envelope or bare row array; normalizes only the latter |
| Errors | Generic parse failure | Command-specific error; raw stdout/stderr suppressed |
| SQL staging for CLI reads | Last argument was SQL | Accounts for appended output flag; same read-only SQL bytes |
| Execution approval | Payload and dedicated-session plan hashes | Both preserved, plus stricter CLI response-contract review gate |
| Returned diagnostics | Original identity fields | Adds response-contract identity; no sensitive data |
| Actual database write | Dedicated direct TLS session helper | **Unchanged helper, destination, TLS settings and credential workflow** |
| Session controls | Five fixed ordered operations | **Unchanged values/order/lifecycle** |
| Catalog transaction | Original file's BEGIN/COMMIT | **Unchanged exact file bytes and atomicity** |

The correction is not literally only a parser edit: it also adds a restrictive
approval gate and identity diagnostic. These do not widen write authority or
change the write transport. CLI formatting/parsing affects only the read-only
project/history/preflight and read-only post-verification calls; the dedicated
TLS write helper does not use this parser or CLI transport.

The unchanged five controls assert a clean session, SET approval, verify it,
RESET after the separate payload operation, then verify reset. The exact payload
is stdin to `psql -f -`, with no prefix/suffix concatenation. Its BEGIN/COMMIT owns
the catalog transaction. Success/error closure, direct host, TLS verify-full,
system trusted roots, no-retry behavior and raw-byte guard remain unchanged.
No project/hash/credential/backup/TLS gate was removed. Backup verification remains
a required external deployment preflight, not a side effect of `--check`.

### Complete source identities

All source hashes below are SHA-256 of the **complete raw file bytes**, without
line-ending normalization. A later byte change requires remeasurement/review.

| Artifact | SHA-256 |
| --- | --- |
| Original complete runner Git blob at baseline | `7c14d27f47219424c44004c0a2d4f95d33da371e1b3067172e63098b096b486f` |
| **Complete corrected `tool/deploy_msec_reference.cjs`** | **`fbe21267ac43a7d3e7562c18712df3fa5eb41f5a6a1aa19030a0f20a1a272cfe`** |
| `tool/supabase_cli_json.cjs` | `26b139dca22f6ab4cbca9517d163879ecb89ac07c7c85e6720432f556ca3b74a` |
| `tool/msec_catalog_session.cjs` | `c191e824eec61455be6bc30c463ca0fa5ba68c1f0601db4ccbdbf906c05f750f` |
| `tool/render_msec_reference.cjs` | `787d8d4b6e7d41fa81f36cf3df04f99230e83b712254c264e5ab35bc2e853574` |

The main-file hash identifies the complete entrypoint, not its imported modules.
To additionally bind all four production files, the ordered path-to-hash JSON
map in the table's current-file order (runner, CLI JSON, session, renderer) has
SHA-256 **`40622bb2946c3a79f136c1cfc28032a1e3a9bf1d6c031cdce52e82f924c51da6`**
over UTF-8 `JSON.stringify(map)`. This dependency-set identity does not claim to
hash the external CLI binary, Docker image or Node runtime.

Reconfirmed original identities:

- Raw atomic payload: `153f97a2eaff6fa02a723a65bcf4c135ab91bc63b2acb8dc151c93966833e428`.
- Dedicated-session plan: `b44a29ca2f28188b67388ef557cc0ad1e8646849ddd653334828531d1c5eea83`.
- Response contract: `9530698dc297c73f07caff55a3b63fc36d76444124de03ca20b5005f6acd40be`.

The plan was independently reconstructed by removing its attached hash field
and hashing UTF-8 `JSON.stringify(descriptor)`. The session helper matches the
reviewed baseline; catalog SQL/manifests and the five controls were not edited.

### Fresh review evidence

- **11/11 parser tests passed**: malformed/unexpected/scalar/prefixed/trailing
  responses fail closed; missing migration target is rejected; no stderr/table
  fallback or sensitive raw-output disclosure; supported query arrays normalize.
- **76/76 catalog/session safety checks passed**, including wrong target,
  missing review/hash, malformed payload, atomic rollback, exact idempotency,
  session lifetime/reset/termination and unrelated schema/user-data preservation.
  The new disposable local cluster was
  `msgi-catalog-test-1794686954296-721a548f`: 24 new test databases, network none,
  no shared volumes. Only that new cluster was stopped; no existing DB reset.
- **One fresh hosted read-only runner preflight passed** using
  `--check --project-ref=sbgshejyvkptmrffiwvd`. It verified the exact authenticated
  project/database-host metadata and eleven-version local/remote migration match
  (11 applied, zero pending). Observed institutions **0**, departments **0**,
  programmes **0**, skills **0**; no exact-record conflict detected.
- Backup `20261114T134947Z-3d9e4376`: unchanged manifest SHA-256
  `6ce4fa5779fbff0ec6bafc821ca25bddc5b2fcf52834bd7b49daaebc7d38dbfa`;
  all **15 encrypted file hashes matched**, current-user-only restricted ACL
  intact, zero plaintext SQL/log exports. No decryption/copy/modification occurred.
- Signed competition APK SHA-256 remains
  `aff9c799950863ddd7130bfe4c2b60926a0b199d95e1d41f66106564a0f63809`.

**Conclusion: ready for renewed authorization, not deployed.** Any approval must
identify this corrected runner/dependency set and response contract while retaining
the existing payload/session-plan identities. Direct TLS connectivity, credential
availability, backup currency, migration/catalog/concurrency checks must still
pass immediately before a separately authorized deployment; a successful CLI
read-only review is not proof of a direct TLS login or actual hosted insertion.

No hosted writes, migrations, Auth/SMTP/RLS changes, session-control execution,
administrator/user/profile operations, signing changes, commit or push occurred.
Only this review report was updated in this review task; prior working-tree
changes and unrelated untracked reports remain preserved.
