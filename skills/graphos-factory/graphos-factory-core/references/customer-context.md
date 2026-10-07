# Customer context before authoring

You are reading this because SKILL.md step 3 could not settle the intake as a
plain generic wrapper: the user wants customer-/tenant-specific fields, or the
scope is unclear. A generic wrapper is already handled — `context_mode: generic`
in `workspace.yaml`, no file here. This reference is the **specialized** path.

## The one decision

A supported API description can omit the data that determines a useful schema.
The field definitions for tenant analytics, CRM custom objects, or CMS content
types often live in customer metadata the spec only *points at* (a `modelId`, a
`/models/{id}/fields` endpoint, an opaque JSON blob). Wrapping such an API
generically composes and passes every offline layer, yet returns a schema the
customer cannot actually query for their own fields.

So decide the outcome, and record it as `context_mode` in `workspace.yaml`:

- **generic** — wrap the documented API. Model identifiers stay runtime
  arguments; documented free-form payloads stay JSON. (You would not be here.)
- **specialized** — expose selected customer-defined fields or operations.
  Their definitions and scope become inputs to schema authoring.
- **undecided** — you cannot yet tell, and it affects the design. Ask one
  focused question; do not silently default to generic.

Evidence, not surface, decides. A `modelId` parameter, a JSON scalar, a large
payload, or an ordinary record ID does **not** by itself establish a missing
build input — it can be a normal runtime argument or a reusable shared type.
Specialized means the *customer's own* field set governs the schema.

A generic JSON wrapper stops here. Keep the model identifier as a runtime
argument and the documented free-form payload as JSON. Record
`context_mode: generic`, create no `context.yaml`, and continue the normal
intake. Do not request tenant metadata or credentials for this path.

## Discover, ask, persist, resume

1. **Name each missing input** and the capability that depends on it. Separate
   scope choices, metadata definitions, and access needed for live validation.
2. **Reuse what exists.** Read `decisions.json` (`graphos-factory-core decisions
   list .`, including `--open`) and any `context.yaml` first;
   reuse supplied model choices, topic lists, exports, and credential
   references. Never re-ask a question the user already answered.
3. **Discover within authorized access.** Inspect read-only metadata endpoints
   or an offline export for exactly the agreed scope. Do not request a secret
   in chat or broaden permissions to make discovery succeed. A spec-only
   inspection request does not authorize live tenant discovery.
4. **Persist requirements.** Put exposure decisions in `selection.yaml` and
   their reasons in `decisions.json` (recorded via `graphos-factory-core
   decisions`). Keep `inventory.json` as regenerable facts.
   Record the requirements in `.factory/context.yaml`. Capture a local
   authoritative artifact with `context capture`; do not label a transcription
   as an authoritative raw artifact.
5. **Report open requirements.** Run `graphos-factory-core context check . --json`.
   If it exits 2, report the number of build and live blockers. Describe each
   blocker with its `affects`, `reason`, and `resolve_with` values.
6. **Ask only for what remains.** Ask for unresolved input and say what each
   answer unlocks. If related questions are clearer together, group them. Offer
   generic wrapping when it meets the goal. Never silently substitute it for
   requested specialized fields.
7. **Update, check, then resume.** Record each answer and its provenance in the
   corresponding `.factory/context.yaml` requirement. Keep incomplete
   requirements open. Run `graphos-factory-core context check . --json` again.
   Continue independent preparation while requirements are open. Resume
   dependent work as each input resolves. Never invent field names or mark a
   requirement resolved to pass the check.
8. **Before live validation**, run the check with `--phase live`. Missing live
   credentials alone do not block an offline build; record unavailable live
   tests as `not_run` with their reason in the existing evidence contract.

## The `context.yaml` requirements contract

The **decision** lives in `workspace.yaml` (`context_mode`). This file exists
only when there are **requirements to track** — the metadata a specialized
schema depends on, and any live-validation access. A generic wrapper with
nothing outstanding has no file at all. The agent writes it; the binary
validates the declared records and rehashes local files — it never infers a
requirement or contacts the API. Schema:
`context.schema.json`, embedded in the binary.

```yaml
# .factory/context.yaml — with workspace.yaml carrying `context_mode: specialized`
contract_version: 1
intent: Expose the customer's chosen analytics fields so they are queryable.
inputs:
  - path: openapi.json
    sha256: 3b1f…                      # shasum -a 256 openapi.json
requirements:
  - id: selected-model-fields
    phase: build
    affects: [typed analytics fields]
    reason: The API document refers to customer-defined model metadata.
    resolve_with: Use the chosen model and topics to retrieve their field definitions.
    status: resolved
    resolution: Finance model selected in D-0007; fields from the export below.
    evidence:
      - id: selected-fields-raw
        path: .factory/context-artifacts/selected-fields-raw/artifact.json
        sha256: 9c4a…
        byte_count: 24320
        representation: raw
        authority: authoritative
        format: json
        captured_at: 2026-09-16T09:00:00Z
        capture_method: administrative export
        source: approved scoped metadata export
        scope: [selected model, selected fields]
        refresh_by: 2026-10-16
  - id: live-identity
    phase: live
    affects: [live query validation]
    reason: The effective test identity has not been established.
    resolve_with: Verify the approved credential's identity and access.
    status: missing
```

The digest in this example is not real. Use the command to write the real
digest and byte count:

```bash
graphos-factory-core context capture . \
  --requirement selected-model-fields \
  --id selected-fields-raw --from /approved/export.json \
  --representation raw --authority authoritative --format json \
  --capture-method "administrative export" \
  --source "approved scoped metadata export" \
  --scope "selected model" --scope "selected fields" \
  --refresh-by 2026-10-16
```

`context capture` accepts an existing local file. It does not fetch the file
or accept a credential. It copies the file into the committed
workspace. It rejects recognizable credentials, but it does not detect all
confidential or personal data. Use this path only when the artifact is safe to store
in the workspace repository.

The command records the source, capture method, scope, representation, lineage
and refresh date. A raw artifact can be `authoritative`. A `derived` or
`transcribed` artifact is `supporting` and must name its `derived_from`
artifact IDs.

Field notes:

- **`inputs`** — every local source document the assessment relied on, so a
  changed spec forces reassessment. `path` is workspace-relative, `sha256` is
  64 lowercase hex from the file bytes. Existing `{path, sha256}` records stay
  valid. Captured artifacts also record an ID, byte count, representation,
  authority, capture details, scope and refresh date. Never paste an example
  hash.
- **Each requirement** has a stable `id`, a `phase` (`build` or `live`),
  `affects`, `reason`, `resolve_with`, and `status` (`missing`, `resolved`, or
  `stale`). `resolved` needs a nonempty `resolution` — the answer and its
  provenance (a decision reference). `evidence` snapshots are hashed like
  `inputs`; changed bytes, a changed byte count or an expired `refresh_by`
  date blocks that requirement's phase.
- **Specialized mode needs at least one `build` requirement** recording the
  scope or metadata that governs the schema, even once resolved. List only
  dependencies of the agreed scope; record exclusions in the selection, not as
  dead requirements. Keep tenant values in the workspace, never in shared
  lessons.

### What the check enforces

`graphos-factory-core context check . [--phase build|live] [--json]` reads
`context_mode` and validates the file if present. An unrecorded `context_mode`
reads as generic: the marker is self-attested, so its absence is
not a gap, and only `undecided` and the declared requirements block. Only an
absent key reads as generic: an unreadable `workspace.yaml` or a non-string
marker is an invalid record (exit 1). It rehashes `inputs` and
`evidence`, checks byte counts and refresh dates, and verifies artifact
lineage. It does **not** poll remote APIs or certify metadata completeness.

| Exit | Meaning |
|---|---|
| 0 | ready for the requested phase |
| 2 | unresolved context (undecided, an open requirement, or a changed or overdue snapshot) |
| 1 | an invalid record or invocation |

- **Lint** runs the same check on every workspace: build gaps are errors,
  live-only gaps are warnings. A workspace with neither marker nor
  `context.yaml` reads as generic and has nothing to report. A clean lint is
  not an assessment — step 3's question still decides specialized work.
- **`graphos-factory-core evidence`** runs the check before the live wrapper: unresolved requirements make live `not_run` with their reason;
  invalid records fail the live layer. Offline layers still run. `--skip live`
  still reports `skipped`.
- On a known remote metadata change, fetch the scoped snapshot again and mark
  affected requirements `stale` until reassessed; rerun dependent tests. Never
  rehash a file merely to make the check pass.

Readiness is not proof that a connector works or that a credential is valid.

## Route new findings back to the right input

| Finding | Repair |
|---|---|
| Missing customer scope or metadata | Update the requirement; discover or ask, then resume dependent work |
| The saved API contract disagrees with the API | Verify against a current contract or recorded response; use the pinned-source correction/refresh workflow |
| Correct inputs produce incorrect mappings | Fix authoring or the generator and add a mapping regression case |
| A live request is denied | Inspect the effective identity and permissions; do not infer that schema generation failed |
| Customer metadata changed | Refresh the scoped snapshot, reassess affected requirements, and rerun dependent tests |

For specialized work, include a test tied to the requested capability — a
chosen field is present in the schema and its query uses the intended metadata
identifier. Compose and spec-derived mocks alone cannot prove that the
connector serves the selected customer model.
