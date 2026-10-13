# Service workspace contract

**Status:** All workspace contracts use `contract_version: 1`, except `evidence/latest.json`, which is `contract_version: 2` (the `write_body_proof` layer and `case_proofs` were added to a closed schema, so a version-1 reader rejects the file), the record files under `.factory/decisions/` and `.factory/findings/`, each `contract_version: 2` from the first (`decisions.json` and `findings.json` stay 1), and `selection.yaml`, which is `contract_version: 2` (`context` on overrides and waivers, `decision:` optional; a version-1 file is still read, and codify or `decisions migrate --split` upgrades it when it writes a `context`). The seven
machine-readable files described here are enforced by JSON Schemas in
the repository's `schemas/` directory — `workspace.schema.json`,
`inventory.schema.json`, `selection.schema.json`, `evidence.schema.json`,
`applied-lock.schema.json`, `sources-lock.schema.json`, `context.schema.json` — which
`graphos-factory-core inventory` and `graphos-factory-core lint` validate against. The binary
embeds them, and a target adds its own schemas for the files it owns.

`workspace.yaml`'s `context_mode` records the generic / specialized /
undecided assessment; the optional `context.yaml` companion records
only the requirements and inputs that assessment depends on, and exists only
when there are any. An unrecorded `context_mode` reads as generic:
`graphos-factory-core context check` blocks only on `undecided` and on the
requirements and inputs `context.yaml` declares. The
[`customer-context.md`](customer-context.md) reference covers discovery and resumption.

A *service workspace* is the local git repository the skill creates for one service — one external source wrapped as a Federation subgraph. It is the only durable state the skill
has: the schema the engineer iterates on, the machine-readable record of
what the API offers and what the user chose, and the agent's memory of
decisions and vendor quirks. A host UI, if there is one, reads and writes
the same files, so this contract is also the interface between it and the
skill.

Three rules the layout is built around:

1. **Inventory, selection, and schema are three different files.** What
   the API offers (inventory) is discovered and can be refreshed. What the
   user wants (selection) is decided and must survive refreshes. The schema
   is the artifact and is hand-editable. A generator that collapses the
   last two into "regenerate from manifest" keeps hand edits only inside
   the regions it promises not to touch, and engineers stop editing the
   schema (lessons.md § Regeneration destroys iteration).

   The dividing line is **facts against judgements**.
   `inventory.json` carries only what a reader can verify against the source
   in seconds; it is regenerable at any time, is never hand-edited, and
   never governs the schema. Every judgement that changes the schema or the
   tests — the GraphQL root, the field name, the envelope, what is exposed
   of the pagination, the tags, the exclusions — is in `selection.yaml`. The
   tool drafts those deterministically and marks each draft as a hint; the
   agent confirms them with the user; `reconcile`, `lock` and `codify`
   guard them. A derived fact may stay in the inventory to *support* a
   judgement, but it is named for what it is
   (`array_root_properties: ["modules"]`, never `envelope: "modules"`).
2. **The schema is never regenerated wholesale after the first commit.**
   Applying a selection change is a *reconciliation*: the agent reads the
   schema as it stands, computes the delta against the selection, and edits
   only the affected operations and types. Every apply is one git commit
   whose message names the selection or decision that caused it.
3. **Every judgment is written down once, where the next agent will look.**
   One test decides where: *could a reasonable engineer have
   gone the other way, and would the service still be valid?*

   - **Yes** → a decision in `.factory/decisions.json`
     (`graphos-factory-core decisions add`, with the question and every
     alternative), resolved by the user, or by the agent with `--note`
     saying why it was confident enough not to ask (§ `decisions.json`).
   - **No, because a reference or the wire settles it** → a
     finding in `.factory/findings.json` (`graphos-factory-core findings add
     --cites …`), and only when an instrument needs its `omits` or
     `affects` or the next session needs the fact (§ `findings.json`).
   - **A vendor quirk, a dead endpoint, an auth detail** → `memory.md`.
     Also `memory.md`, under `## Tried and rejected`: a negative result
     ("moving to the deployment's pins fails on two v0.4-only constructs"),
     an accepted residual no instrument can waive, a standing correction
     the user gave. None is derivable from current state, and the next
     session reads `memory.md`, not `git log` (§ `memory.md`).
   - **A measurement, a correction to an earlier record, a stash, "found
     and fixed"** → the commit message, or an edit to the record it
     corrects (through its verb: `decisions resolve --force`, or a new
     finding that supersedes the old).
   - **Something the next service would want** → the skill's
     `references/lessons.md`.

   Both logs are written only through their verbs (`graphos-factory-core
   decisions`, `graphos-factory-core findings`), never hand-edited. An agent
   must read both (`decisions list`, including `--open`, and `findings
   list`) before proposing a change that reverses a `resolved` decision,
   and must not silently re-litigate anything recorded there. To revise the
   answer when the user asks, `decisions reopen` the record and resolve it
   again; when the question itself changed, record a new decision or mark
   the old `superseded`. Never rewrite a record in place.

## Layout

Below is the core layout. A target adds files of its own beside it (its
`Target.init_files` and `output_files`) and, when it publishes a workspace,
says which subset leaves the workspace and how; its own references describe
both. Nothing under `.factory/` is ever part of that subset.

```
<service>/                         # git repo, created by the skill
  <service>.graphql                # the Apollo Connectors schema (hand-editable)                                        (init header / hand)
  supergraph.yaml                  # rover's compose config: federation_version pin + this one subgraph   (init / hand)
  template.yaml                    # {{BASE_URL}}, {{AUTH_EXPR}} declarations + local test values         (init / hand)
  README.md                        # scope, configuration, limitations & exclusions
  openapi.json | swagger.json …    # the description document's working copy (OpenAPI 3.x or Swagger 2.0), when one exists   (intake)
  tests/
    router.yaml                    # override_url -> WireMock; include_subgraph_errors: all   (init / hand)
    <service>.connector.yaml       # rover connector test suite
    cases/{name}.graphql + {name}.expected.json
    fixtures/mappings/*.json       # WireMock stubs, x-cases scoped
    live.yaml + live/*.graphql     # optional credential-gated smoke cases                  (local only)
  .factory/                      # skill + UI state; never leaves the workspace
    workspace.yaml                 # identity: service name, prefixes, skill version, contract version
    sources.lock.yaml              # where every input came from; for a pinned spec: kind, version, upstream + hashes, patches[]
    sources/                       # the vendor's bytes for each pinned spec (<name>.upstream.<ext>); never edited
    context.yaml                   # intent, build/live requirements, resolutions, metadata hashes
    context-artifacts/             # local specialized inputs captured byte-for-byte; committed and absent for generic work
    inventory.json                 # what the API offers (discovered; refreshable)
    selection.yaml                 # what the user chose (decided; durable) + overrides (hand edits, codified)
    applied.lock.yaml              # the schema (one hash per span) and the pinned specs (one content hash each) as last applied
    decisions.json                 # tracked decision log: decisions only — resolved calls with their alternatives + open questions (schema-governed; written only by graphos-factory-core decisions); the older-format records, numbered D-nnnn, never added to
    decisions/                     # every newer decision: one file each, <id>-<slug>.json, random D-k7m2qx ids
    findings.json                  # settled facts an instrument reads (omits, affects), F-nnnn (schema-governed; written only by graphos-factory-core findings); the older format, never added to
    findings/                      # every finding added since: one file each, <id>-<slug>.json
    memory.md                      # vendor quirks, dead endpoints, auth details, gotchas, tried and rejected
    evidence/
      latest.json                  # last validation run: per layer, per operation
      runs/<timestamp>/            # raw logs for the last N runs
    samples/                       # recorded live responses (scrubbed), by operation
      <operationKey>/<n>.json
    inferred-schema.json           # JSON Schema synthesized from samples (no-spec oracle)
```

Everything under `.factory/` is committed. It is small, textual, and is
the reason a future agent can continue without the original conversation.

### The local-validation files

The files marked *(init / hand)* are written by `init` for a target that
declares them, or by hand; `init` never overwrites one that already
exists, and reports it left alone. Their shape, for one subgraph
(`directory: widget-co`, `service: widget_co`):

```yaml
# template.yaml: local test values only, never the production host
variables:
  - name: BASE_URL
    description: "Base URL of the Widgets REST API, including the /v1 path"
    test_default: "https://api.widgets.example/v1"   # the document's first absolute server
  - name: AUTH_EXPR
    description: "Complete Connectors authentication expression for the Widgets bearer token (scheme bearerAuth, sent as `Authorization: Bearer <token>`)"
    test_default: "{$env.WIDGET_CO_TOKEN}"            # a complete expression; the scheme prefix stays in @source
```

With only a relative server (`/api/v3`), `BASE_URL` is a local stand-in
(`http://127.0.0.1:8080/api/v3`) under a comment asking for the host. With
no security scheme, `AUTH_EXPR` is still declared, under a comment: an API
that takes no credential removes the Authorization header from `@source`
(a target whose `init` writes the schema header puts one there) and deletes
the entry, since lint reports a declared variable the schema does not use.

```yaml
# supergraph.yaml: composes this one subgraph for the local layers; not the
# user's supergraph. The pin equals workspace.yaml's federation_version.
federation_version: =2.15.2
subgraphs:
  widget-co:                       # directory
    routing_url: http://localhost
    schema:
      file: widget-co.graphql
```

```yaml
# tests/router.yaml: the e2e layer's router config; render moves the port per run
connectors:
  sources:
    widget-co.widget_co:           # <subgraph>.<@source name>: directory, then service
      override_url: "http://localhost:8080"
include_subgraph_errors:
  all: true
```

Such a target's `init` can also write the schema's header alone: a comment,
the two `@link`s at the workspace's pins and the one `@source` with
`{{BASE_URL}}` and the credential header, and no root field, so compose
fails until the first apply adds one.

**Every file under `.factory/` is a regular file inside the workspace, and
the binary enforces it**. One module owns every `.factory/*` read
and in-place write: it `lstat`s each component of the path — `.factory`
itself, `sources/`, `evidence/runs/<stamp>/`, the file — and refuses a
symlink at any of them, opens with `O_NOFOLLOW`, and writes by truncating
the file where it stands rather than renaming a temporary over it (a rename
replaces a link silently, and would lose the line-by-line splicing that
keeps every other line and comment in `selection.yaml`). The refusal names
the workspace-relative path and never the link's target:

```
.factory/selection.yaml: refused — a symlink, not a regular file; the factory
refuses it rather than follow it outside the workspace
```

This is the one genuine filesystem boundary between a host that runs the
binary and a workspace it did not author, so it is a refusal and not a
warning: `lint` reports `unreadable-file`, the editing verbs exit non-zero,
and `sources refresh` exits 2 having written nothing (custody reads every
`.factory` input before the first write), and every `graphos-factory-core
decisions` verb exits 1 rather than read or rewrite a symlinked
`decisions.json`. Restore the real file rather than reading the target by
hand. Paths outside `.factory/` — the schema, the
source working copy, the test suite — are the user's own and keep the
access they had.

## `workspace.yaml`

```yaml
contract_version: 1
service: incident_io           # snake_case; equals the @source name
directory: incident-io         # kebab- or snake-case directory / subgraph name
type_prefix: Incident_Io
field_prefix: incident_io
skill: { name: example, version: 0.3.0 }   # the target's name, which the binary writes
source_kind: rest              # the only implemented kind; grpc / database / graphql are planned
connect_spec: v0.4             # rest: the default for a new workspace; v0.3 remains valid for older workspaces
federation_version: "2.15.2"    # composition plugin pin; render/compose match this exactly against supergraph.yaml
# federation_spec_version: "2.12"  # set only when the schema links an older federation spec than the plugin minor (e.g. an older workspace moved to plugin 2.15.2 but still linking v2.12); a new workspace links federation/v2.15 and omits it
sparse_fieldsets: { param: fields }  # optional: the string query parameter a GET names its fields in; absent means `fields`; `enabled: false` turns the rule off for a source whose parameter means something else (schema-authoring.md § Sparse fieldsets)
intake: spec | discovered | mixed   # rest: how inventory.json was built — from a description document (`inventory build`; the format is the sources.lock entry's kind), from docs and probes, or both
created_at: 2026-09-08T00:00:00Z
```

## `sources.lock.yaml`

Where every input came from, so no spec's origin goes unrecorded.
Enforced by `sources-lock.schema.json`. A *document* entry pins a
description document in two copies: `upstream`, the vendor's bytes exactly
as retrieved and never edited, and `path`, the working copy the reader reads
and people edit. `kind` names the dialect — `openapi` for OpenAPI 3.x,
`swagger` for Swagger 2.0 (`postman`, `har` planned) — and
`graphos-factory-core sources pin` writes kind, version, upstream and the hashes
so they are never hand-typed. `docs` and `probe` entries record pages read
and live requests made.

```yaml
contract_version: 1
sources:
  - kind: openapi                 # openapi = OpenAPI 3.x; swagger = Swagger 2.0
    version: "3.0.3"
    url: https://api.incident.io/openapi.json
    retrieved_at: 2026-09-08T14:02:11Z
    path: openapi.json            # the working copy
    upstream: .factory/sources/openapi.upstream.json   # the vendor's bytes; a change here is an error
    upstream_sha256: 3f1c…
    patches:                      # JSON Patch over the upstream, written by `graphos-factory-core codify --source`
      - op: replace
        path: /components/schemas/Incident/required
        value: [id]
        was: [id, summary]
        reason: "live API returns null; spec says non-nullable string"
        context: "every open incident probed so far has a null summary"   # optional, from codify --context
        verified: { how: recorded sample, sample: .factory/samples/incidentsShow/1.json }
  - kind: docs
    url: https://api-docs.incident.io/tag/Incidents-V2
    retrieved_at: 2026-09-08T14:05:40Z
    used_for: [incidentsV2List, incidentsV2Show]
  - kind: probe
    base_url: https://api.incident.io
    retrieved_at: 2026-09-08T14:10:03Z
    operations: [incidentsV2List]
    credential: INCIDENT_IO_TOKEN     # env var name only, never the value
```

`patches` is the codified form of a hand edit to the spec, exactly as
`overrides` is for the schema: the working copy stays editable, the
difference from the upstream is recorded with its reason, and applying the
patches to the upstream must reproduce the working copy (lint checks it:
`source-patches-stale`). `was` keeps the value a `replace` or `remove` took
away so `sources refresh` can tell a vendor change from a still-valid patch
(a re-applied patch stays; an obsolete or conflicting one is dropped and
recorded in the finding the refresh writes, `source: sources`). A patch
carries its why in `reason` and `context`; `decision:` names a real
decision only when the patch carries one out. The
tool edits this file in place — keys of one entry, or its `patches` block —
so the agent's notes survive.

## `inventory.json`

The API as the skill understands it. Compact enough to load whole for
medium APIs; for large APIs (hundreds of operations) a host UI and the agent page
through `operations[]` and fetch one operation's full `shape` on demand
via the bundled `inventory` script. Operation keys use the same
`{method}:{path}` form the existing Apollo generator UI uses
(`get:/widgets/{widgetId}`), so the two UIs can share selection state.

```jsonc
{
  "contract_version": 1,
  "api": {
    "title": "incident.io API",
    "base_urls": ["https://api.incident.io"],
    "auth": [{ "kind": "bearer", "header": "Authorization", "prefix": "Bearer ", "source": "spec|docs|probe" }],
                                                // an oauth2 scheme adds "oauth2": { "flows": [...], "authorization_code": { urls, scopes } }
    "security": [{ "bearer": [] }],             // the document's default requirement (scheme -> scopes), verbatim; operations[].security overrides it
    "pagination": { "style": "cursor", "request": "after", "response": "pagination_meta.after",
                    "counts": { "cursor": 12, "unknown": 1 } }   // the majority of operations[].pagination, never a pooled parameter-name set; counts absent when nothing is paginated
  },
  "operations": [
    {
      "key": "get:/v2/incidents",
      "operation_id": "incidentsV2List",         // spec id, or synthesized method+path id
      "method": "GET",
      "path": "/v2/incidents",
      "summary": "List incidents",
      "tags": ["Incidents V2"],
      "semantics": "read",                        // read for GET/HEAD, write for everything else (a POST included); unknown only in a hand-written inventory
      "read_hint": null,                          // on a POST whose name suggests a read: why; advisory, confirm with the user before root: query
      "provenance": "spec",                       // spec | docs | probe | inferred
      "confidence": 1.0,
      "parameters": [
        { "name": "page_size", "in": "query", "type": "integer", "required": false },
        { "name": "after", "in": "query", "type": "string", "required": false }
      ],
      "request_body": null,
      "response": {
        "content_type": "application/json",
        "shape_ref": "#/shapes/IncidentList",     // fully dereferenced JSON-schema-like shape
        // The facts an envelope judgement rests on; the envelope itself is
        // in selection.yaml. A key with nothing to say is omitted.
        "root_property_count": 2,
        "array_root_properties": ["incidents"],
        "cursor_root_properties": ["after"]
      },
      "support": "supported",                     // supported | unsupported | needs_review
      "support_reason": null                      // e.g. "response is NDJSON", "repeated query param"
    }
  ],
  "shapes": {
    "IncidentList": { "type": "object", "properties": { "incidents": { "type": "array", "items": { "$ref": "#/shapes/Incident" } }, "pagination_meta": { "$ref": "#/shapes/PaginationMeta" } } },
    "Incident": { "type": "object", "properties": { "id": { "type": "string", "format": "id" }, "name": { "type": "string" }, "severity": { "$ref": "#/shapes/Severity" } }, "required": ["id", "name"] }
  },
  "unresolved": [                                 // every discovered thing that is not an operation yet
    { "hint": "POST /v2/incidents/{id}/actions", "source": "docs", "reason": "no response documented" }
  ]
}
```

A shape property or array item may carry **`x-expansion`** beside its
`$ref`: `{target, mechanism: fields, default, evidence?}`, a relationship to
another node that the source expands on the wire. `default` is
the verified list of leaves the source returns unexpanded, with `evidence:
{kind: probe|doc, ref}`, or `unverified`. Anything short of a non-empty
list of names with that evidence (`[]`, no evidence, a blank `ref`) is read
as `unverified`. It comes from the source document
(the Meta converter writes it); `inventory build` keeps it, and the
reference and target shape stay whole. `source-coverage` stops its walk
there; every other consumer reads the full target.

`response` records, and omits any key that carries no information:
`root_is_array` (the success shape is itself an array), `root_property_count`
(links included), `link_root_properties` (`_links`, `links`),
`array_root_properties`, `sole_root_property` (the only non-link property,
when there is one), `total_items_property`, `cursor_root_properties` (a
next-cursor key whose property can carry a string). `graphos-factory-core
selection draft` turns them into a proposed `response.envelope` per included
operation, and each `candidate_entity_link` fact into a proposed `links:`
entry; the rules are in [schema-authoring.md](schema-authoring.md)
§Envelopes and § Cycles and depth.

**The inventory is never hand-edited.** `applied.lock.yaml` hashes it, so
`lock --check` exits 3, `reconcile` names it and lint reports
`unacknowledged-inventory-edit`; `inventory build` refuses to overwrite a
file that changed since the lock and prints what it would have changed
(`--force` overwrites and loses the edit). A wrong *document* is corrected in
the pinned working copy and codified with `codify --source`; a judgement you
disagree with is written into `selection.yaml`, where it belonged all along.

Every operation the skill ever saw is accounted for as one of
`supported`, `unsupported` (with reason), or listed under `unresolved`.
The same accounting (selected / excluded / unsupported / unresolved) is
what lets a reader, or a host UI, see "what was left on the table".

## `selection.yaml`

The durable intent. Written by the user (by hand or through a host UI) or
by the agent on the user's instruction; read by the agent when applying. No command creates it: `init`
does not, and `selection draft` and `selection set` splice into a file that
already exists. `selection draft` proposes a `response.envelope` only for
operations the file already marks `include: true`, and on a fresh workspace
it exits 1 with a message that names the missing `.factory/selection.yaml` and
states the `include: true` requirement. The operations, their roots and names are
the select verb's judgements. Field paths use the same
`>`-separated path grammar the existing UI emits
(`get:/animals/{animalId}>**` means "everything under this operation").

```yaml
contract_version: 2             # 2 adds `context` on overrides and waivers; a version-1 file is still read
defaults:
  fields: all                 # all | none — what an included operation selects by default
  max_depth: 6
  opaque_json_policy: forbid  # forbid | allow_with_reason — an undocumented JSON field fails lint under forbid
  null_handling: omit         # omit | send_null — what an explicit null argument sends; optional, a decisions.json entry overrides it per argument
operations:
  get:/v2/incidents:
    include: true
    response:
      envelope: incidents     # the root key the payload sits under, or null for none
      confirmed: true         # false while it is still `selection draft`'s proposal
    graphql:
      root: query             # query | mutation; explicit, never derived from HTTP method
      name: listIncidents     # semantic name; default is the sanitized operation_id
      description: null       # override; default from summary, else description (discovery specs have no summaries)
    fields:
      exclude:
        - "incidents[]>external_issue_reference"     # per-field exclusion; every array segment is spelled with [] (`_links[]`, `incidents[]>x`, `[]>x` under a root-array response): a path missing one excludes nothing, and reconcile reports it with the spelling that matches, as far as the inventory's top-level and envelope-item paths reach
      rename:
        "incidents[]>incident_status": status
      tags:
        "incidents[]>creator>email": [internal-low]
    pagination: { expose: [page_size, after], next_cursor: "pagination_meta.after" }
  post:/v2/incidents:
    include: true
    graphql: { root: mutation, name: createIncident }
    tags: [beta]
  get:/v2/incidents/{id}:
    include: true
    graphql: { root: query, name: incident, entity: true, key: id }
  post:/v2/incidents/{id}/actions:
    include: false
    reason: "customer asked for read-only in first release"   # shows up in COVERAGE / README
  # A bulk exclusion reads better as a one-line flow entry, and is equally
  # valid. `graphos-factory-core selection set` edits either form in place — it
  # replaces just the `include` value's bytes and leaves the reason, the
  # quoting, the spacing and the key order exactly as written.
  # Keep a flow entry on ONE line: a `{ … }` wrapped across lines is legal
  # YAML but `selection set` refuses it and tells you to unwrap it.
  "delete:/v2/incidents/{id}": { include: false, reason: "read-only in first release" }
overrides:
  # Hand edits, codified (written by `graphos-factory-core codify`). Each names a
  # schema span, says why (`reason`, and `context` from --context), and
  # asserts what must stay true; `decision:` (optional, D-0019 or D-k7m2qx) names a
  # real decision only when the edit carries one out. Drift
  # between selection and schema on these is reported,
  # not fixed; the agent may still change the span when the selection or
  # inventory changes, as long as every assertion holds.
  - key: get:/v2/incidents/{id}
    reason: "severity is read first; the engineer ordered the selection by hand"
    context: "the on-call dashboard renders the first field as the row title"
    assert:
      - contains: "severity   # first"
      - tag: internal
    until: "incident.io returns fields in a stable order"    # free text, for humans
    expires: "2027-01-01"                                     # machine-checked: reported as expired after this
```

**`response`** is where the envelope judgement lives: `envelope`
names the single root property the payload's useful content sits under, or is
`null` when the field returns the whole body. It must name a root property of
the operation's response shape — `reconcile` and lint both refuse one that
names nothing (`unknown-envelope`), because a typo would otherwise flatten
the field to a type with no fields. `graphos-factory-core selection draft`
proposes one per included operation from the inventory's response facts and
marks it `confirmed: false` — as it proposes each `links:` entry below;
while it is false, `reconcile` names it as still the tool's draft and lint warns (`response-envelope-unconfirmed`). An
operation with no `response` block at all falls back to the suggestion, and
`reconcile` says which one it used (`no-response-envelope`). An absent
`confirmed` means confirmed: a hand-written selection is the user's word.

**`response.referenced_shape`** is a different judgement in the same block:
which branch of a two-branch success/error `oneOf`/`anyOf`
response is the actual payload, for a case the source document itself
leaves ambiguous. `inventory build` already writes the same key as a
*fact* when the source makes the branches distinguishable on its own (one
branch's shape also documented at an explicit non-2xx status, or both
branches pinning a shared boolean property to the opposite literal) — never
from a property's name alone. When `inventory.json` has no such fact for a
known two-branch response and a human or agent has reviewed the case,
recording the same key here (a `#/shapes/<Name>` pointer, the grammar
`shape_ref` already uses) resolves the finding without ever touching
`inventory.json`: `reconcile`'s `root_properties` and `scaffold`'s response
body both read the inventory fact first and fall back to this judgement
only when the fact is absent. Absent both, the response types as the
workspace's JSON scalar and the finding stays open — `scaffold` says so in
a note.

**Field paths** are rooted at the response body and use a
`>`-separated grammar with `[]` after a list segment:
`incidents[]>incident_number` for an item field in a paginated list,
`incident>pending_actions` for a field under a single-object envelope,
`more` for a top-level field. An operation that returns the type shares
the exclusions of every other operation that returns it — write them on
each (YAML anchors keep them in one place); `graphos-factory-core reconcile` reports the
selection that says "all fields" while the connector maps fewer.

**`overrides`** carry the engineer's intent. A key names a *span* of the
schema — an inventory operation key (its root field or fields), `type:<Name>`
(a type, enum, input, union or scalar with its doc and comments), `Query.<f>`
/ `Mutation.<f>` (a root field the inventory does not explain) or `header`
(everything before the first type). `graphos-factory-core reconcile` lists each
override's drift from the selection in its own section, never counts it as
work, and checks its assertions against the span's current text:
`contains` / `not_contains` (runs of whitespace compare equal), `matches`
(a regex), `tag`, `arg` / `no_arg` (root fields), `field` / `no_field`
(types). A failing assertion is not clean. An override with no assertions
is **pinned**: the span is compared byte-for-byte against `--baseline` and
the agent must not change it — lint warns, because a pin freezes the
operation forever; assertions are what let it keep evolving. `until` is
free text saying when to revisit; `expires` (YYYY-MM-DD) is checked, and an
expired override is reported and is not clean. `customized` (the old
list of fenced operations) is retired; reconcile and lint refuse it.

**`links`** are the relationship fields the user chose to expose — a
property that carries another resource's id becomes a field on its host
type, resolved by that resource's GET-by-id operation through a
field-level `@connect` keyed by `$this` (no `@key`). One entry per
relationship, keyed by the inventory shape and the property's path:

```yaml
links:
  - shape: Song                          # #/shapes/Song, the shape that carries the foreign key
    path: album_id                       # the property's path from the shape's root, wire names
    operation: "get:/albums/{album_id}"  # the by-id operation the field resolves through; must be included
    parameter: album_id                  # its trailing path parameter (wire name); defaults to the fact's
    field: album                         # the GraphQL field on the host type; camelCase
    include: true
    confirmed: false   # drafted by `graphos-factory-core selection draft`
```

`shape`, `path`, `operation` and `parameter` restate the inventory's
`candidate_entity_link` fact (what the property matched); `field`,
`include`, `confirmed`, `reason` and `decision` (`D-0019` or `D-k7m2qx`) are the
judgement. `path` is the inventory walker's grammar: wire-name segments
joined by `>`, each followed by one `[]` per list level — `album_id` for a
top-level property, `[]>album_id` under a root-array shape,
`songs[]>album_id` for a property of a nested list's items,
`matrix[][]>owner_id`, `owner>account_id`. The host GraphQL type is not
recorded: `graphos-factory-core reconcile` derives it from the included
operations that return the shape, their root fields' return types and the
path, and reports when it cannot.

`graphos-factory-core selection draft` appends one entry per surviving fact with
`confirmed: false` (`--links` drafts only links, `--envelopes` only
envelopes, neither both; the two together are a usage error, exit 1). It
never touches a fact whose `<shape> > <path>` already has an entry, in any
state: it skips it and says why (`already has a links entry (--force
replaces it)`, `already has a confirmed links entry (--force replaces only
a draft)`, `already has a declined links entry (include: false)`).
`--force` redraws an entry only while it is still `confirmed: false`. Two
facts on one object that would derive the same field name get distinct
ones — the second `<derived><FkCamel>` (`ownerSellerId`). A `links:`
section it cannot index line by line (the entry count it walks differs
from the count the file parses to) is left byte-identical and every fact
is skipped with that reason. `selection review` lists `unconfirmed_links`.
An unconfirmed entry never governs — it is a reconcile note and a
`link-unconfirmed` lint warning, not drift. Once confirmed,
`graphos-factory-core links apply . --dry-run` prints the field text to paste
(connectors-language.md § Relationship fields), and `reconcile` reports a
missing field as `links.add`, a `{$this.` GET-by-id connector no included
entry declares as `links.remove`, and a wrong operation, verb or `$this`
variable as `links.change`. A confirmed entry the current rules no
longer back (its target refused, its fact gone, or a target the builder
would never propose) is **stale**, and raises an open decision for the
field: the refusal reason as `context`, choices `keep` and
`drop`, `affects: [Type.field]`, recorded with the `decisions add` command
reconcile and lint print in their fix text, and named in the entry's
`decision:`. While that decision is open (or the entry names none) the
entry is `links.change` with `stale: true`, never `links.add`, lint
reports it, and `links apply` refuses it `target-refused`.
Resolved `keep` is the exemption; resolved `drop` means setting
`include: false` with a `reason` citing the decision and removing the
field on the next apply. Only a decision keeps a stale link, never a
finding. Decline a link with `include: false` and a
`reason`. A drafted entry may be `no-host` — no root field in the schema
returns a type that reaches its shape (the draft also follows a `$ref`
under a property the selection excludes: gitea's `Organization > username`
sits under `Repository.repo_transfer`) — until an operation returning the
shape is applied; once it is confirmed, lint warns (`link-no-host`) and
`links apply` refuses it.

**JSON-field reasons** (`graphos-factory-core spans json-accounting`) are the
judgement behind a JSON-scalar field, keyed `"<TypeName>.<fieldName>"`
against the rendered SDL rather than an inventory path — the same span
namespace `overrides` uses for `type:<Name>`, without the `type:` prefix,
since a field belongs to exactly one type declaration. The reason is a
`decisions.json` record, never a `selection.yaml` field or a schema doc
comment (the decisions-only rule — the same rule `null_handling` below
follows): `spans json-accounting` enumerates every field the current SDL
still types as the workspace's own JSON scalar (nested inside another
object type, or wrapped in a list at any depth, included) and reports one
with no matching `json_reasons` entry on a **resolved** decision, or one
whose `reason` is outside the closed vocabulary (`free-form-object`,
`recursive`, `vendor-undocumented`, `polymorphic-without-discriminator`,
`depth-cap`), as unaccounted:

```bash
graphos-factory-core decisions add . --title "Incident.body stays JSON" \
  --question "Type Widget_Co_Incident.body, or keep the JSON scalar?" \
  --choice 'json:keep the JSON scalar' --choice 'typed:type the fields observed so far' \
  --resolved --chosen json --decision "why" \
  --json-reason 'Widget_Co_Incident.body|free-form-object'
```

`json_reasons` live only on decisions, which carry their alternative
(`decisions add` refuses a record with neither a question nor choices).

`defaults.fields: all` never counts as a reason on its own — it decides
which fields are selected, not why one of them is still untyped.

The recorded `reason` is not trusted forever: each is a predicate over the
CURRENT `.factory/inventory.json` shape at the field's own path, checked
fresh every run — no timestamp or history lives on the entry itself.
The field's path starts at its type's shape, located by name (a top-level
shape), through the root field's operation response, or through a parent
type's property (an inline item shape the vendor never named).
`spans json-accounting --json` reports one of five statuses per field:
`accounted` (the predicate holds), `unaccounted` (nothing recorded),
`stale` (recorded, but the predicate no longer holds — the vendor spec
moved), or `recoverable` (the inventory is now fully typed at that path,
regardless of what is recorded — the field should be re-typed, not
re-justified, and this overrides the other three), or `unresolved` (a
reason is recorded but no shape could be located for the field's type, so
the claim cannot be checked; never read as accounted or stale). `--check`
fails closed
on anything but `accounted`. `graphos-factory-core evidence` runs this as the
`json_accounting` layer alongside `lint`, writing its per-type and total
counts into `.factory/evidence/latest.json` (`schemas/evidence.schema.json`
§ `layer.counts`).

**`waivers`** carry the engineer's acceptance of a conformance gap, in the
same grammar. `graphos-factory-core validate` reports a body it could not judge
as `unchecked` (the spec documents no shape for it) or `unmatched` (no such
operation, or an unreadable body — this one fails the layer); a waiver names
one body (`where`: a fixture path, or `tests/<suite>.connector.yaml#<entry
name>`) or every such body of one operation (`operation`), the `status` it
accepts, a `reason`, and optionally `context` (from `--context`), a
`decision` (`D-0019` or `D-k7m2qx`, only a real decision the waiver carries out) and
`until` / `expires` as overrides do. Written by `graphos-factory-core codify
--waive`, which refuses a gap validate does not report and records no
decision; validate then reports the body as `waived`
and evidence records it per operation. Lint: `waiver-unused` (nothing has
that status there any more), `waiver-expired`,
`waiver-bad-target`, `waiver-unknown-key`, `waiver-bad-status`.

```yaml
waivers:
  - where: tests/fixtures/mappings/incident_not_found.json
    status: unchecked
    reason: "PagerDuty documents no 404 body; the fixture carries the one observed live"
    context: "recorded against a deleted incident on 2026-09-08"
    until: "PagerDuty publishes the error schema"
```

## `applied.lock.yaml`

The schema as the agent last wrote or acknowledged it — one SHA-256 per span
(same keys as `overrides`) — under `sources`, each pinned document's
working copy as last acknowledged, and under `inventory`, `inventory.json`
itself (each a SHA-256 of the compact JSON, so formatting never counts).
Written by `graphos-factory-core lock` at the end of
every `apply`, refreshed span-by-span by `graphos-factory-core codify --key` and
per document by `sources pin`, `sources refresh` and `codify --source`.
New locks add an optional `provenance` block. The skill state describes the
runtime checkout. The binary state describes its source tree at build time.
The block also records build tools and exact hashes and byte counts for inputs
and authored outputs. This data helps explain why two authored states differ. It
records a supplied model identifier as an attestation. The identifier is
self-reported. It does not prove the model identity or full session history.
The record is not signed and does not prove who created the lock.

Two values fall back when nothing names them. The model is recorded as
`unknown` without `--model` or `$GRAPHOS_FACTORY_CORE_LLM_MODEL`. The skill is
recorded from the binary's own build revision, with `source: binary-build`,
without `--skill-dir` or a `$GRAPHOS_FACTORY_CORE_SCRIPTS` inside a Git
checkout. An empty variable counts as unset. `lock` prints one `lock:
warning:` line to stderr for each value that fell back. The line names the
flag and variable that supply the value, and, when a variable is set, the
value it holds and why that is not a checkout. When
`$GRAPHOS_FACTORY_CORE_SKILL_ROOT` is set it wins over
`$GRAPHOS_FACTORY_CORE_SCRIPTS`, and the line says to repoint or unset it. The
lock is still written, and the exit code is still 0.

```yaml
contract_version: 1
schema: incident-io.graphql
written_at: 2026-09-09T01:02:56.738Z
written_by: <binary> 0.5.0   # the product binary that wrote it
spans:
  header: 8b1f…
  "type:Incident_Io_Incident": 2c9a…
  "get:/v2/incidents": e07d…
  Query.incident_io_probe: 41aa…
inventory: 9c4b…
sources:
  openapi.json: 46d8…
provenance:
  recorded_at: 2026-09-09T01:02:56.738Z
  skill: { revision: a1b2c3d…, dirty: false, source: GRAPHOS_FACTORY_CORE_SCRIPTS }
  authoring_agent: { model: gpt-example, attested: true }
  binary: { version: 0.5.0, revision: a1b2c3d…, dirty: false, rustc: "rustc …", target: aarch64-apple-darwin }
  toolchain: { connect_spec: v0.4, federation: 2.15.2, rover_pin: 0.41.0, router_pin: 2.17.0, wiremock_pin: 3.13.2 }
  inputs:
    .factory/selection.yaml: { sha256: 2a4b…, bytes: 1402 }
  outputs:
    incident-io.graphql: { sha256: 8f7e…, bytes: 18420 }
  omitted_outputs: {}
  reproducibility: records the authored state and tools; the model is self-reported and does not prove model identity, full session history, or bit-for-bit LLM replay
```

`graphos-factory-core lock --check` enforces schema spans, pinned sources, and the
inventory. It also rehashes every provenance input and output and lists each
file whose bytes differ from the record (`~ path (outputs)`, or `- path
(inputs, missing)`), but that listing does not change its exit code: an
apply must stop on an uncodified hand edit, not on a memory.md line or a
case added since the last lock. `lock --check --provenance` exits 3 on any
such drift. CI runs it on every pilot, and `validate` runs it before
reporting, so a lock that no longer describes the committed tests is caught.

Relock on that drift only when a plain `lock --check` reports no changed
or unattributed span (a relock refuses to write on an unattributed one),
no pinned-source problem and no edited inventory. The schema, the
pinned documents and `inventory.json` are recorded provenance files too, so
an uncodified hand edit to any of them also appears in the drift listing. A
relock would acknowledge it: `codify --key` then refuses the span as in sync,
and the edit is never recorded. Follow the hand-edit path first (codify a
span or pinned source, rebuild an edited inventory). A document
`sources.lock.yaml` no longer pins is the exception: it is not a hand edit,
and relocking is how you stop watching it on purpose. `lock --check`
withholds its relock advice exactly when one of those is reported, and
`lock --check --json` carries the same judgement as `relock_advisable`.
`--provenance` is a `--check` option; without `--check` it exits 2 rather
than writing a lock.

The output map hashes regular files only. The recorder does not follow
symlinks under `tests/`. It lists each such path in `omitted_outputs`, which
prevents traversal outside the workspace and recursion through symlink loops.

Under `tests/` the recorder hashes what git would commit: tracked files, and
untracked ones no ignore rule excludes (`git ls-files --cached --others
--exclude-standard`, run from the workspace so a workspace nested in a larger
repository gets workspace-relative paths). Untracked files are kept because
`lock` runs before an apply's commit, when the cases it just scaffolded are
not tracked yet. Outside a git work tree it hashes every file on disk. Either
way it skips dotfiles and dot-directories (`.DS_Store`, editor swap files),
which a checkout never has and `--provenance` would otherwise report missing.

A partial writer does not fail only because provenance collection fails. It
completes the requested lock update, removes the old provenance block, and
prints a warning. This prevents stale provenance from describing new bytes.

Any span — or pinned document, or the inventory — whose current content
hashes differently is a **hand edit nobody has codified**. `graphos-factory-core reconcile` lists them under "hand edits since
applied.lock.yaml", `graphos-factory-core lock --check` exits 3 on them, and
`graphos-factory-core lint` reports each as an `unacknowledged-edit` error
(`unacknowledged-source-edit` for a pinned document) — so a
committed hand edit fails CI until it is codified, and an `apply` must not
start while any exist (the agent could not tell them from its own delta).
An edited `inventory.json` is `unacknowledged-inventory-edit`, and there is
nothing to codify: the inventory is built, never edited, so the
fix is to correct the pinned document (`codify --source`) or to move the
judgement into `selection.yaml`, and rebuild.
A root field whose path several operations match equally, and that the
selection does not declare, is not a hand edit either: its `Query.<f>` key
would move to an operation key once the selection names it. `lock` and
`codify` refuse to record it, and `lock --check` (exit 3) and `lint`
(`unattributed-span`) report it as a tie to settle in `selection.yaml`
(schema-authoring.md § Which operation a root field serves).
Git history is not the baseline on purpose: engineers and a host UI commit
too, and the lock is the one file that means "the agent has seen this".

## Codifying a hand edit

`graphos-factory-core codify --key K --reason R …` is how a detected edit becomes
something the next apply can carry. It refuses an intent the text does not
satisfy, then writes two things at once:

1. the `overrides:` entry in `selection.yaml` — its `reason`, its
   assertions and, with `--context TEXT`, its `context` (replacing any
   previous one for the key; every other line of the file is left as it
   was), or, with `--expressed`, none — the operation must already
   reconcile without drift, because the selection now carries the intent
   (a tag, a rename, an exclusion, a root). An `--expressed` codification
   given `--context` records that prose as a finding (`source: codify`),
   since no entry is left to hold it;
2. the span's hash in `applied.lock.yaml`, so the edit stops being a hand
   edit.

codify appends to no log. `reason` is required and carries the
why; `context` carries the prose the diff cannot show; the entry's
`decision:` is optional. `--decision D-id` (numbered or random) attaches the entry to a real
decision — one the user made that this edit carries out — and codify warns
when no such record exists. Never record a decision only to have one to
cite.

`--key` records a hand edit to the **schema**, and refuses a span that is in
sync with the lock: there is no edit there, and the override it would write
("the engineer edited … by hand") would be a false record. The one exception
is a key that already has an override — the engineer is rewording its reason
or its assertions, not recording a new edit. A correction to something the
tool *inferred* is a different thing and has its own routes: a wrong shape or
response is a spec defect (`--source`), and a judgement goes in
`selection.yaml`.

Expressible edits go into the selection (`--expressed`); everything else
gets assertions (`--assert contains=…`, `--assert tag=…`, …); `--pin` is
the last resort. `--dry-run` prints the writes without making them.

`graphos-factory-core codify --source PATH --reason R` does the same for a
pinned spec: the structural difference between the upstream copy and the
working copy becomes the entry's `patches` in `sources.lock.yaml`, each new
one carrying the reason and `--context` (an operation already recorded
keeps its own reason, context and decision; one no longer present is
dropped), and the working copy's hash is acknowledged in
`applied.lock.yaml`; no decision is recorded. It refuses when
the upstream copy was
modified — the vendor's bytes are restored, never codified.

Validation rules the skill enforces before applying:

- `selection.yaml` satisfies `selection.schema.json` — `reconcile` validates
  it before reading anything out of it, so "valid against inventory.json"
  means the file is valid and not merely that its keys resolve;
- every key exists in `inventory.json` (a typo never silently thins the schema);
- `response.envelope`, when present, names a root property of the operation's
  response shape;
- every `links` entry names a shape in `inventory.json`, a path that
  resolves in that shape, and an included `get:` operation
  (`link-unknown-shape`, `link-unknown-path`, `link-unknown-operation`,
  `link-operation-excluded`); two entries never name the same field on the
  same object of one shape (`link-duplicate-field`); a confirmed entry
  whose shape no root field in the schema reaches is a warning
  (`link-no-host`); a field-level `@connect` inside a type carries
  exactly the credential its by-id root connector carries — no header and
  no token argument under source-level auth, the same per-call argument
  sent the same way otherwise (`link-credential`); one keyed by a foreign
  key the host declares nullable carries the null guard `links apply`
  prints, in `isSuccess` and in the selection (`link-null-guard`, a
  warning); a confirmed entry whose by-id target `inventory
  links` refuses or that no `candidate_entity_link` fact backs is
  `link-target-refused` — an error once its field is pasted, a warning
  before — until its `decision:` names its keep-or-drop decision resolved
  `keep` (connectors-language.md § Relationship
  fields); every field-level
  `@connect` in the schema has a unit entry targeting `<Type>.<field>` and
  an e2e case that selects the field on its host type (`link-untested`, a
  warning naming the one missing or both; this one reads the
  schema and `tests/`, not `links:`); one whose fk is nullable and that
  has an e2e case also has a mapping answering the empty-segment GET that
  serves a case selecting it (`link-null-untested`, a warning);
  when `tests/live.yaml` exists, each is selected by a listed live case or
  named by a `field:` exclusion (`link-live-unaccounted`, a warning),
  and each exclusion names exactly one of `operation:` or `field:`
  (`live-exclusion-malformed`, an error);
- `root` is present for every included write-shaped or POST operation
  (the Query/Mutation split is a judgement, and is recorded);
- an operation marked `unsupported` in the inventory cannot be included
  without a `force_reason`;
- `rename` targets are unique within their type; the result satisfies the
  `{service}_{name}` / `{Service}_{Type}` namespacing rules.

## `decisions.json`

The workspace's decision log (`schemas/decisions.schema.json`,
`contract_version: 1`), which a host UI's decisions view, if any,
projects. It holds **decisions only**: calls a reasonable
engineer could have made the other way, each carrying its alternative, so
a reader sees the choice taken and the ones not. Two kinds of record share
one shape:

- an **open question** the service still needs answered — `status: "open"`,
  with a `question`, agent-suggested `choices` (`{id, label, detail?}`), and
  `multiple: true` when more than one choice may be picked;
- a **resolved decision** — `status: "resolved"` with a `resolution` —
  recorded whenever the agent or the user chooses between alternatives,
  with the question and the alternatives it chose between.
  (`superseded` marks one a later decision replaced.)

A fact with no alternative is a finding (§ `findings.json`); the why of a
hand edit, waiver or spec patch is the entry's own `reason` and `context`;
session narrative is a commit message. **`decisions add` refuses a record
that names its alternative none of three ways: a `--question`, two or more
`--choice`s, or an `--omit` with reason `editorial`** (exit 1,
`no-alternative`; a `consumed` or `not-applicable` omit does not count): if
you cannot name what else you could have done, you are not recording a
decision. `add --resolved` and `resolve` set
`resolution.by` to `agent` when `--by` is absent; a UI that records on the
user's behalf passes `--by user`, so the field says who chose. An agent-chosen
decision's `--note` says why you were confident enough not to ask. An
`editorial` omit ("deliberately not exposed") lives only on a decision:
"expose it" is always its alternative.

`graphos-factory-core decisions` is the **only** writer; the file is never
hand-edited. The same commands serve a headless agent and an interactive
host: a choice made in a host UI reaches the agent, which records it
through the same path:

```bash
graphos-factory-core decisions list .   [--open] [--json]     # read the log; --open = questions still awaiting the user
graphos-factory-core decisions add  . --title T [--question Q] [--choice id:label]… [--multiple] \
                                  [--phase P] [--affects PATH]… \
                                  [--resolved --chosen id --note TEXT --decision TEXT --by user|agent]   # raise a question, or record a call already made; refuses no-alternative
                                  [--omit 'operation|direction|path|reason']… \
                                  [--null-handling 'operation|argument|behavior']…   # behavior: send_null or omit
                                  [--foreign-type NAME]…   # a type another subgraph owns, declared under its owner's name; read on a resolved record, by a target that allows it
graphos-factory-core decisions resolve . --id D-id [--chosen id]… [--note TEXT] [--decision TEXT] [--by user|agent] [--force]
graphos-factory-core decisions reopen  . --id D-id [--json]  # clear the answer so the user can revise it; status back to open
graphos-factory-core decisions supersede . --id D-id [--json]  # a resolved decision a later one replaced; answer kept, omits, json_reasons and null_handling stop counting
graphos-factory-core decisions add  . … [--slug S] [--after D-id]… [--amends D-id]…   # a new record's file name, and the decisions it presumes or changes
graphos-factory-core decisions link . --id D-id (--after D-id | --amends D-id)…   # edges on a record that is its own file; a numbered record is refused
graphos-factory-core decisions list . --causal                # the log in the order its decisions presume one another
```

### One file per new record

`decisions.json` holds the records written in the older format, with their
numbered ids, at `contract_version` 1, and **never gains a record or a
field**. Every decision added since is its own file under
`.factory/decisions/`, and every finding under `.factory/findings/`:

```
.factory/decisions/D-k7m2qx-paginate-by-cursor.json
{
  "contract_version": 2,
  "decision": { "id": "D-k7m2qx", "slug": "paginate-by-cursor", "title": "…", "status": "open", … }
}
```

- **The id** is `D-` (`F-`) and six random base36 characters, at least one
  a letter, so it never reads as a number; the writer draws again on a
  repeat. Every id pattern is `^D-([0-9]{4,}|[0-9a-z]{6})$`: the schemas,
  `selection.yaml`'s `decision:`, a finding's `related`, and the zero-case
  suite citation `unit.sh` checks.
- **The name** is `<id>-<slug>.json`. The slug comes from the title (lower
  case letters and digits in hyphen-separated runs, at most 40, an
  apostrophe joining its word) or from `add --slug`, and is stored on the
  record. `load` refuses a file whose name does not begin with its record's
  id and any entry that is not a `.json` file; a dot-file is ignored.
- **Readers see one log**: the file's records in file order, then the
  record files by `date` and id (records added the same day order by id).
  `save` puts each record back where it lives, by the ids the file on disk
  holds: an old record changed by `resolve`, `reopen` or `supersede` is
  rewritten in place in `decisions.json`, which stays version 1; a new one
  is truncated in place in its own file, or created with `O_EXCL`. Nothing
  is renamed or removed. A workspace with no log starts with record files.
- **Edges** (`after`, `amends`) exist only on new records, which may name
  old ones. `decisions link` adds them after the fact. An old record never
  gains a field, so `link` refuses it (`old-record`). `slug`, `after`,
  `amends` and `resolved_against` are forbidden in a version-1 document by
  the schema, and a single file that is not version 1 is refused on read.
- **What a merge can break, lint reports**: `decision-id-duplicate`,
  `decision-link-unresolved`, `decision-link-cycle` (errors; the writer
  also refuses all three) and `decision-overlap` (warning: two resolved
  decisions, at least one new, name the same `affects` span, or one names
  `every operation`, and no `after`/`amends` path relates them; two
  numbered records are exempt, since their numbers order them). Each
  finding names the file or directory its record lives in.
- **The two migrations that produce the single file**, `decisions migrate`
  from `decisions.md` and `migrate --split`, still write it whole; `--split`
  refuses once record files exist.
- The lock's provenance and `selection review` hash every record file beside
  the single files, and `lock --check` reports a record file the lock never
  recorded as added (`+`), as it reports a changed `decisions.json`.
- `decisions add --json` and `findings add --json` print the record file they
  wrote, `{"id": "D-k7m2qx", "path": ".factory/decisions/D-k7m2qx-….json"}`,
  so a caller stages or copies it without globbing.

Records in `decisions.json` keep the `D-nnnn` id grammar, so ids from the
Markdown log and the migrated pilots carry over unchanged; `decisions migrate --split` keeps
every decision's id. A `resolved` record
must carry a `resolution`; everything the old Markdown block held becomes
field values, and nothing is lost. `resolve --force` replaces the whole
resolution, so a re-resolve must pass `--chosen` again when the record
names a choice and `--decision` again when it names a decision; a call
that would drop either (a `--note` alone, or only one of the two) is
refused rather than erasing it.

**Null handling.** What an explicit `null` argument sends is stated once
for the workspace in `selection.yaml`'s `defaults.null_handling` (`omit` or
`send_null`), and overridden per argument by a resolved record's
`null_handling` entry, `{operation, argument, behavior}`, recorded with
`decisions add --null-handling 'operation|argument|behavior'` on a
decision whose choices are the two behaviors. `omit` means
"do not touch" (the key is dropped and the stored value stays); `send_null`
means "clear" (the key reaches the vendor as JSON `null`). State `omit`
unless the vendor needs the clear. It must still be true of the connector,
because the write-body proof check reads a stub that shows the other
behavior as unproven, whichever rule applied. With neither a default nor an
entry, the argument is unproven: the check never picks a value, and never
reads prose. Both fields are optional and additive, so `contract_version`
stays 1.

**Superseding a decision.** `decisions supersede . --id D-id`
sets a `resolved` record's status to `superseded` and changes nothing else:
the resolution stays, so the log still says what was decided, and its
`omits` stop counting. Use it when the question itself changed, or when
`lint` reports a `stale-omit` (the schema now maps, or the source no longer
offers, a path the decision omits); record on a new resolved decision
whatever of it still applies (a stale omit on a finding is fixed the same
way with `findings supersede`, § `findings.json`). A superseded record stops counting
everywhere a resolved one does, not only for `omits`: its `affects` no
longer suppress lint, a `links:` entry whose `decision:` names it is no
longer kept, a sparse-fieldsets default it justified loses its reason,
and its `json_reasons` and `null_handling` entries stop accounting for a
field or an argument. It refuses, exit 1 and nothing written, an unknown
id (`unknown-decision`), a record that is open (`not-resolved`) or already
superseded (`already-superseded`), and a missing or invalid log; `--json`
prints `{id, status, previous_status, exit}` or `{error, code, exit}`.

**Revising a decision.** `decisions reopen . --id D-id` takes a `resolved`
or `superseded` record back to `open`: it removes the whole `resolution`
(`chosen`, `note`, `decision`, `by`, `at`) and keeps every other field —
title, question, context, choices, affects, omits, json_reasons, secret_fields — and the
record's place in the log. A later `decisions resolve` records the new answer without
`--force`. The log keeps no history field; the cleared answer survives in
the workspace's git history (commit the reopen, `decide:`) and in
`--json`'s `cleared`. While a record is open its `omits` (and `json_reasons`) are not counted,
so `source-coverage`/`spans json-accounting` reads those paths as unaccounted again until it is
resolved. `reopen` refuses — exit 1, nothing written — an unknown id
(`unknown-decision`), a record that is already open (`already-open`), a
missing log (`decisions-missing`; it never creates one) and an unreadable
or invalid one (`decisions-invalid`). With `--json` a refusal prints
`{error, code, exit}` and success prints `{id, status, previous_status,
cleared, exit}`.

**Migrating a legacy workspace.** A workspace authored before `decisions.json` existed has a
free-form `.factory/decisions.md` and no `decisions.json`. Run
`graphos-factory-core decisions migrate .` once: it imports every `## D-nnnn` block
as a `resolved` record (`Context:` → context, `Decision:` →
resolution.decision, `Alternatives:`/`Evidence:` → resolution.note, `Affects:`
→ affects), **preserving the `D-nnnn` ids** so `selection.yaml`'s override and
waiver `decision:` references still resolve and the next id continues the
sequence, then removes the `.md` (`--keep-md` to keep it, `--dry-run` to
preview, `--force` to overwrite an existing `decisions.json`). Fences are
``` or `~~~`. A decision header inside a fence, or the same `D-nnnn` twice,
refuses the migration: nothing is written and the `.md` stays, because a
block skipped there would be lost when the `.md` is removed. Do this before
any `codify`/`sources` run in an upgraded workspace, or a fresh `decisions.json`
would start at `D-0001` and collide with the ids in the orphaned `decisions.md`.

**Splitting an older-format log.** A `decisions.json` in the older format
mixes decisions with findings, the binary's provenance records and
session narrative. `graphos-factory-core decisions migrate . --split` sorts it
once, writing both files:

- a record carrying `omits`, `choices` or a `question` is never treated as
  provenance, whatever its title;
- `Hand edit codified:` / `Source patch:` / `Conformance waiver:` → moved
  onto the override, waiver or patch whose `decision:` names it (its
  `context` copied into the entry's `context` unless it is the binary's
  template sentence), then dropped; one no entry cites (what `--expressed`
  left) becomes a finding, `source: codify`;
- `Upstream replaced:` / `Upstream refreshed:` → a finding, `source:
  sources`;
- a `question`, `choices` or an `editorial` omit → stays a decision; lint's
  `decision-without-alternative` (a warning) then asks a record lacking its
  question and choices to gain them;
- everything else is **sorted by hand** by you, by the test in rule 3
  above: a decision stated as prose is re-recorded with its question and
  choices; a fact an instrument reads becomes a finding; a negative
  result, an accepted residual no instrument can waive, or a standing user
  correction becomes a `memory.md` line under `## Tried and rejected`; the
  rest is dropped, because git keeps it and current state plus a re-run is
  the status. `--split` lists each such record and refuses to run without
  `--sorted` until every one is assigned. Nothing becomes a finding just
  to avoid deleting it.

Decisions keep their ids; findings get fresh `F-nnnn` ids, and the rewrite
updates every `decision:` reference it moved. Commit the result `decide:`.

```jsonc
{
  "contract_version": 1,
  "decisions": [
    {
      "id": "D-0007",
      "title": "Cursor pagination exposed as explicit args",
      "status": "resolved",
      "date": "2026-09-08",
      "phase": "select",                       // optional: the verb/phase that raised it
      "context": "incident.io lists use `after` cursors; connectors have no pagination primitive.",
      "requested_by": "user (chat, \"keep it simple, mirror the REST shape\")",
      "affects": ["get:/v2/incidents", "get:/v2/actions"],
      "choices": [                             // the options the agent offered; `decisions add --choice LABEL` numbers them "1", "2", …; ids like these are kept only when every `--choice` is `id:label`
        { "id": "explicit-args",    "label": "Expose pageSize/after args", "detail": "map nextCursor: pagination_meta.after; no Connection type" },
        { "id": "relay-connection", "label": "Relay-style connection",     "detail": "rejected: no Federation-level benefit here" }
      ],
      "resolution": {
        "chosen": ["explicit-args"],           // ids drawn from choices[]; `decisions resolve --chosen` also takes an exact label
        "note": "mirror the REST shape on every list operation",
        "decision": "expose pageSize/after args and map nextCursor: pagination_meta.after; do not synthesize a Connection type",
        "by": "user",
        "at": "2026-09-08T00:00:00Z"
      }
    },
    {
      "id": "D-0031",
      "title": "Root for POST /schedules/preview",
      "status": "open",                        // no resolution yet; a host UI may show it as a live question
      "date": "2026-09-09",
      "phase": "select",
      "question": "This POST reads (renders a preview) but carries a request body. Query or Mutation?",
      "multiple": false,
      "affects": ["post:/schedules/preview"],
      "choices": [
        { "id": "query",    "label": "root: query",    "detail": "it only reads; the body is the input" },
        { "id": "mutation", "label": "root: mutation", "detail": "keep the POST as a write" }
      ]
    }
  ]
}
```

An agent collects the design questions a service needs answered as `open`
records at `select` (not as loose chat messages), then resolves each with the
user; the open → resolved status the user watches settle lives in the
artifact, not in transient UI state. Nothing else writes here: `codify`
puts its why on the entry it writes, and `sources refresh` and `sources pin
--force` write a finding. Read the log — including `--open` — before
proposing a change that reverses a `resolved` decision, and record a new
decision (or `superseded`) rather than editing one in place.

## `findings.json`

The facts the agent established that an instrument must read, or the next
session must know (`schemas/findings.schema.json`, `contract_version: 1`).
A finding has no alternative, because a reference or the
wire settles it: "`errors[]` and `success` are consumed by the `@source`
error mapping on every operation", "enums keep wire casing per naming.md",
"descriptions end with the returned field names". A call
somebody could make the other way is a decision, never a finding, and
nothing becomes a finding just to avoid deleting it.

`graphos-factory-core findings` is the **only** writer; the file is never
hand-edited:

```bash
graphos-factory-core findings list . [--json]
graphos-factory-core findings add  . --title T --body TEXT [--cites REF] [--affects PATH]… \
                                 [--omit 'operation|direction|path|reason']…   # reason consumed or not-applicable; editorial is refused
graphos-factory-core findings supersede . --id F-id     # a later finding replaces it
```

Ids are `F-nnnn` in `findings.json`, a sequence of their own beside
`D-nnnn`, and random `F-9k2wde` for every finding recorded as its own file. A
record:

```jsonc
{
  "contract_version": 1,
  "findings": [
    {
      "id": "F-0003",
      "title": "errors[] and success are read by the @source error mapping",
      "date": "2026-10-01",
      "status": "current",                     // current | superseded
      "body": "The @source errors block reads errors[].message and success on every operation; neither is a field.",
      "cites": "references/schema-authoring.md § Errors",
      "source": "agent",                       // agent | codify | sources
      "affects": ["post:/candidate.info"],
      "omits": [
        { "operation": "post:/candidate.info", "direction": "response", "path": "success", "reason": "consumed" }
      ],
      "evidence": ["graphos-factory-core source-coverage . post:/candidate.info"],
      "related": ["D-0004"]
    }
  ]
}
```

- `body` is the fact in prose; `cites` is the rule that settles it
  (`references/schema-authoring.md § Enums`).
- `source` is who wrote it: `agent` (`findings add`); `codify` (an
  `--expressed` codification given `--context`, which leaves no entry to
  hold the prose); `sources` (`sources refresh` and `sources pin --force`:
  both shas, the origin label and each patch's fate — re-applied, obsolete
  or in conflict — with `related` naming any `--decision`).
- `affects` takes the decision grammar (`Type.field`, `field(arg)`,
  operation keys); `omits` takes `{operation, direction, path, reason}`
  with `reason` `consumed` or `not-applicable` only. `findings add --omit`
  refuses `editorial`: "deliberately not exposed" always has "expose it" as
  its alternative, so it is a decision.
- `evidence` (operation keys, file paths, the command run) and `related`
  (`D-0019`, `D-k7m2qx`, `F-0003` or `F-9k2wde`) are free.
- There is no `question`, `choices`, `resolution` or `reopen`. A finding is
  `current` until a later one supersedes it; a superseded finding stops
  counting everywhere.

**Readers take the union.** Every instrument that takes `omits` or
`affects` from a resolved decision reads the resolved decisions **and** the
current findings together: `source-coverage` (wire omits and `behaviour`
waivers) and its `stale-omit`, lint's description waivers,
`closed-enum-as-string`, and `sparse-fieldsets`' literal matching. An open
or superseded decision and a superseded finding count for none of them. The
one exception is the kept-link rule: a stale `links:` entry is kept only by
its decision resolved `keep` (§ `selection.yaml`, `links`), never by a
finding. `json_reasons`, `null_handling`, `secret_fields` and
`foreign_types` stay on decisions. `findings.json` is a hash input of `selection review` and of the
applied lock's provenance, as `decisions.json` is.

## `memory.md`

Free-form but sectioned: **Auth**, **Vendor quirks** (spec vs reality,
dead endpoints, undocumented fields), **Testing gotchas** (fixture matcher
traps hit in this workspace), **Open questions**, and **Tried and
rejected** (below). **Auth** is where the credential's provider facts go —
the scheme prefix, which header or parameter carries it, an OAuth flow's
endpoints and the vendor page that documents them, whether the tokens are
opaque — one line each, with the page that states it. A target that drafts
auth configuration names its own markers in its references.

**`## Tried and rejected`** holds what no current file shows and
the next session must not repeat, one line each with what was tried and
why it was rejected:

- a negative result ("moving to the deployment's pins fails on two
  v0.4-only constructs");
- an accepted residual no instrument can waive;
- a standing correction the user gave.

None is derivable from current state, and the next session reads
`memory.md`, not `git log`, so this is where it goes rather than a decision
with no alternative or a commit message alone.

## `evidence/latest.json`

Per-operation statuses are `pass`, `fail`, `skipped` (tool missing),
`not_run` (input missing: no credential, no cases), `excluded` (the layer
ran but deliberately did not exercise this operation; the reason is under
the layer's `exclusions`, from `tests/live.yaml`; a relationship field,
which has no row, is excluded by a `field:` entry instead, kept as an
`EXCLUDED FIELD: <Type>.<field> — <reason>` line in the live layer's
`findings` and named on evidence's report as not validated) and `n/a` (the layer ran
and nothing covered it; this includes a unit layer that ran zero cases,
whose empty suite covers no operation by a recorded decision).
Only `pass` is proof.

What was proven, per layer, per operation, at which commit. A host UI can
show this next to each operation; the skill refuses to call a workspace
"validated" when any selected operation lacks executed evidence.

```jsonc
{
  "contract_version": 2,
  "commit": "a1b2c3d",
  "run_at": "2026-09-08T15:00:00Z",
  "inputs": {
    "digest": "5e0c…",
    "files": { ".factory/selection.yaml": "2a4b…", "incident-io.graphql": "8f7e…", "tests/router.yaml": "c3d1…" }
  },
  "toolchain": { "rover": "0.41.0", "federation": "2.15.2", "connect_spec": "v0.4", "wiremock": "3.13.2" },
  "layers": {
    "compose":        { "status": "pass" },
    "connector_unit": { "status": "pass", "cases": 14, "failed": 0 },
    "wiremock_e2e":   { "status": "skipped", "reason": "docker unavailable", "case_proofs": {} },
    "write_body_proof": { "status": "fail", "reason": "3 write gaps, 0 read gaps (exit 1)", "cases": 2, "failed": 2, "write_gaps": 3, "read_gaps": 0 },
    "spec_conformance": { "status": "pass", "oracle": "openapi.json" },
    "lint":           { "status": "pass", "findings": [] },
    "json_accounting": { "status": "fail", "counts": { "json_fields": 2, "accounted": 0, "unaccounted": 2, "stale": 0, "recoverable": 0 } },
    "live":           { "status": "not_run", "reason": "no credential" }
  },
  "operations": {
    "get:/v2/incidents": { "unit": "pass", "e2e": "skipped", "live": "not_run" },
    "post:/v2/incidents": { "unit": "n/a (object input)", "e2e": "skipped", "live": "not_run" }
  }
}
```

**`inputs`** fingerprints what the layers ran against, with no git. Before
the first layer runs, `evidence` hashes every file a layer reads: the
schema, `template.yaml`, `supergraph.yaml`, the target's own output files,
every file under `tests/` (dotfiles aside; a linked directory that stays
inside the workspace is walked like any other), and
`.factory/workspace.yaml`, `selection.yaml`, `inventory.json`,
`context.yaml` and the snapshots it names, `sources.lock.yaml` and the
documents it pins, `inferred-schema.json`, and the decision and finding
logs with their record files. `README.md`, `memory.md` and
`.factory/evidence/` are not inputs: no layer reads them.
`applied.lock.yaml` is not one either: lint reads it, but it is left out
because `export` lints the workspace again when it runs, so the lock is
judged as it is then. `files` maps each workspace-relative path to the
SHA-256 of its bytes, and `digest` is the SHA-256 of one `<sha256>  <path>`
line per file in path order (`sha256sum`'s line format). A reader hashes
the same files again to tell whether the evidence is for the workspace as
it is now, and names each one that changed, was added or was removed.
`inputs` is optional and additive: evidence written before it existed has
none, and such a reader falls back to `commit`, which still needs git. A
run where a file could not be hashed (a link under `tests/` that resolves
outside the workspace) records `inputs_error`, the reason, instead of
`inputs`: re-running `evidence` cannot help until that file is fixed, so a
reader says so rather than falling back. `evidence`'s report prints
`inputs: <first 12 hex> over N files`, or `inputs: not recorded (<why>)`,
beside the commit on its first line.

The applied lock's `provenance` and `inputs` hash the same file the same
way, so a file's SHA-256 is equal in both, but they answer different
questions. The lock records what was authored and committed: it is
written by `lock` after an apply, covers `README.md` and `memory.md` too,
and `lock --check --provenance` holds the committed files to it. `inputs`
records what the layers saw when they ran: it is written by `evidence`,
covers only what a layer reads, and goes stale on any edit to one of those
files, committed or not. A file can match one and not the other: a README
edit is provenance drift but leaves the evidence current, and a schema
edit after `lock` and before `evidence` is in the evidence and not the lock.

`write_body_proof` is `fail` when a selected operation has a gap, including
when the e2e layer was skipped or failed: a write with no executed case is an
unproven assertion, not a `not_run` layer. It is `not_run` only when there is
nothing to prove: no `selection.yaml` or `inventory.json` to check, or no
selected operation with a write, an argument or a list (every obligation
`not_applicable`); `assert-evidence.sh` accepts that `not_run`, as it
accepts one from `json_accounting`, because neither is a missing tool.
A stub that could answer any request the case sends (no body pattern or a
loose one on a body-sending write, a `urlPathPattern`/`urlPattern`, no
method) disqualifies that case as proof, and a case marked
`expect-unmatched-upstream` never proves anything. Its `reason`
and `write_gaps`/`read_gaps` count gaps on body-sending writes and on every
other operation apart, so a workspace with no write gap is not summarised by
its reads alone. The layer is non-gating, like `json_accounting`: neither
fails `evidence`'s own exit code, and the validation gate and
`assert-evidence.sh` print a `fail` from either as open findings, never as
a pass.
`wiremock_e2e.case_proofs` reports each case's own verdict (`pass`, `fail`,
`unproven`) whatever the layer's aggregate status.

`skipped` and `not_run` are first-class and visible. They are never
reported as `pass`.

**A unit run with zero cases is `not_run`, not `pass`.** rover reports an
empty suite (`tests: []`) as `SUCCESSFUL 0  passed; 0 failed; 0 skipped`.
`unit.sh` counts cases per suite from rover's `TEST SUITE:` / `TEST CASE:`
listing. Every suite with zero cases must say, in the first sentence of its
header comment, why it is empty and cite the decision that settled it by
id (for example `Deliberately empty (D-0011).`, where D-0011 records that
every GET's `fields` value contains a comma, which rover cannot assert). A
zero-case suite whose first sentence cites no decision id, including one with
no header comment, is a `fail` (exit 1), whether or not other suites ran.
When no suite ran a case, `unit.sh` exits 3, and evidence records:

- `connector_unit` as `not_run`, with `cases: 0`;
- as its reason, `unit.sh`'s whole line: `unit: no runnable cases:
  <suite>: <first sentence of its header comment> (not_run)`, with one
  `<suite>: <sentence>` pair per suite, joined by `; `;
- every operation's `unit` as `n/a`.

When other suites ran cases, the layer is judged on those, and `unit.sh`
names each cited empty suite in its log. A `skip: true` case is a `fail`,
whether it is one case or all of them: rover counts it as skipped and still
says SUCCESSFUL. A missing suite file is a `fail` too.

**`write_body_proof`** is additive: optional in
`evidence.schema.json`, not yet part of the validation gate below, and
excluded from `evidence`'s own exit code as well — a `fail` here never
fails the `evidence` command itself, or a CI step that keys off its exit
code. It reads the SAME run's `wiremock_e2e` status and log — never
`.factory/evidence/latest.json` on disk, which mid-run still holds the
*previous* run's file (the same-run evidence contract) — and attaches its
per-case verdicts to `wiremock_e2e`'s own `case_proofs`, additive beside the
existing integer `cases`. When an argument was placed by execution (an
executed case's stub demands its value at one body pointer) the
layer entry also carries `placements`: `{operation, argument, via:
"executed", location, case}` for each; an argument not listed was placed by
the reader. Absent when none needed execution.

**The validation gate.** A workspace is validated only when every offline
layer (`compose`, `connector_unit`,
`wiremock_e2e`, `conformance`, `lint`) is `pass`, with one exception:
`connector_unit` may be `not_run` when no suite ran a case **and** the
recorded reason cites the decision behind each empty suite (`unit.sh`
fails the run otherwise). Any other `not_run`, and any `skipped` or
`fail`, on an offline layer means the workspace is not validated. The live
layer does not gate: it runs against the real API and stays local, and a
live-only gap is reported as `not_run` without blocking the offline
layers. Neither does `json_accounting`: none of the 14 workspaces measured
when it was added is anywhere near clean, and gating on it today would block
every one. Report its status as it is; a `fail` there is a real, tracked
finding, just not yet a blocker.
Report live's status as it is; it is never a pass. The same holds
per operation: `fail`, `unchecked` or `skipped` on an offline layer of any
selected operation means not validated, whatever the layers say (a
conformance body that matches no operation is recorded as `fail`).
An operation's e2e verdict is `unchecked` in two cases: a case
without `# expect-upstream-status` whose stub answered an error status on an
operation documenting several, and a documented non-2xx status that no
passing case saw answer the operation's **own** request. The second is
recorded per status in `layers.wiremock_e2e.error_coverage[<op>]` as
`{documented, executed, not_run}` (additive, contract_version 1), with a
`note` on the operation naming the `not_run` statuses; a status served to a
nested lookup or side call is not the operation's. CI's `assert-evidence.sh`
treats any `not_run` status as an error, with no way to allow one.
A target that publishes a workspace computes this gate as one of its
evidence layers (`target_evidence_layers`) and refuses to hand
the workspace on without it; `lint` does not enforce it, since it accepts a failed layer
that carries a reason.

## Creating a workspace: `graphos-factory-core init`

A spec-backed workspace starts from one description document (OpenAPI 3.x or
Swagger 2.0) the agent has already fetched; the binary never fetches.
The workspace belongs to one target, whose name `init` writes to
`skill.name`; a binary that registers more than one target needs it named
with `--target <name>`, and the skill's own `init` row says which:

```bash
graphos-factory-core init <dir> --name widget-co --spec /tmp/widget-co.json \
  [--url https://api.widget.test/openapi.json] [--retrieved-at T] [--created-at T] \
  [--context-mode generic|specialized|undecided] [--dry-run] [--json]
```

The agent makes the judgement calls — the name, the `context_mode`
assessment, and git — and `init` does the mechanics. `--name` is the service
name in snake_case or kebab-case; every word is lowercase letters and digits
starting with a letter, because the type prefix capitalises each word
([naming.md](naming.md)). `init` derives the four names from it, and always
writes `directory` in kebab-case. A consumer that needs the snake_case
filename (naming.md) is a hand edit of `directory` right after `init`,
before any file is named for it: `<directory>.graphql`, the
`supergraph.yaml` subgraph key and file, and `tests/<directory>.connector.yaml`
(`scaffold`'s default) all follow it, and renaming them after the first
`lock` means relocking. It creates
these five files and nothing else, in this order:

| File | Content |
|---|---|
| `.factory/workspace.yaml` | `service`, `directory`, `type_prefix`, `field_prefix` from `--name`; `skill.version` is the binary's version; `source_kind: rest`; `connect_spec` and `federation_version` at the toolchain's current pins; `intake: spec`; `created_at` (`--created-at`, else now); `context_mode` only when `--context-mode` is given |
| `openapi.<ext>` or `swagger.<ext>` | the working copy: the document's bytes verbatim, named for its dialect, `.json` for a JSON document and `.yaml` (or `.yml`, when `--spec` had it) for YAML |
| `.factory/sources/<name>.upstream.<ext>` | the vendor copy: the same bytes, never edited |
| `.factory/sources.lock.yaml` | one document entry — `kind`, `version`, `url` (with `--url`), `retrieved_at` (`--retrieved-at`, else now), `path`, `upstream`, `upstream_sha256` — written by the same function `sources pin` uses |
| `.factory/inventory.json` | the inventory, built by the same reader `inventory build` uses; a later `inventory build` reproduces it byte for byte |

Without `--context-mode`, `workspace.yaml` records no `context_mode`, and
`context check` reads the workspace as generic.
With `specialized`, the agent writes `context.yaml` next (see
[`customer-context.md`](customer-context.md)). No `applied.lock.yaml` is written
before the first `apply`, so `sources status` reports the working copy as
`not in applied.lock.yaml` until the first `graphos-factory-core lock`, as it does
after a hand-run `sources pin`.

Every file is computed before anything is written. `--dry-run` writes
nothing, not even the directory, and reports the same bytes a real run
writes — given the same `--created-at` and `--retrieved-at`; without them
each run stamps its own time into `workspace.yaml` and `sources.lock.yaml`.
A caller that shows a dry run for approval and then applies it passes both. With `--json`, both runs print one object:

```jsonc
{
  "workspace": "<dir as given>",
  "service": "widget_co", "directory": "widget-co", "type_prefix": "Widget_Co", "field_prefix": "widget_co",
  "context_mode": "generic",                 // null when not given
  "path": "openapi.json", "kind": "openapi", "version": "3.0.3",
  "upstream": ".factory/sources/openapi.upstream.json",
  "upstream_sha256": "…",                    // the document's bytes
  "content_sha256": "…",                     // the canonical-JSON hash applied.lock.yaml will record
  "inventory": { "title": "…", "format": "OpenAPI 3.0.3", "operations": 12, "supported": 11,
                 "needs_review": 1, "unsupported": 0, "shapes": 30, "unresolved": 0, "warnings": [] },
  "dry_run": true,
  "files": [ { "path": ".factory/workspace.yaml", "content": "…", "sha256": "…", "bytes": 291 }, … ],
  "exit": 0
}
```

`path` is workspace-relative and `content` is the file's exact text. `init`
refuses a document that is not UTF-8, so every file can be shown as text.
A refusal exits non-zero and writes nothing. With `--json` it prints
`{ "error": "…", "code": "…", "exit": N }`:

| Exit | `code` | When |
|---|---|---|
| 1 | `usage` | a missing, unknown or invalid flag (`--context-mode`, an `--created-at` that is not RFC 3339) |
| 1 | `invalid-name` | `--name` breaks the naming rule above |
| 2 | `workspace-exists` | the directory already holds `.factory/` or `workspace.yaml` |
| 2 | `file-exists` | a file `init` would create is already there (a working copy is never adopted) |
| 2 | `not-a-directory` | the target is a file |
| 2 | `spec-unreadable` | `--spec` cannot be read, or is not UTF-8 |
| 2 | `spec-invalid` | it does not parse as JSON or YAML, or yields no valid inventory |
| 2 | `spec-unsupported` | it declares neither `openapi: 3.x` nor `swagger: "2.0"` |
| 2 | `write-failed` | the directory could not be created or the first write failed; no file was written |
| 4 | `incomplete` | a write failed after the first file; the object adds `written: [...]` — remove those files and run `init` again |

A workspace with no document (`intake: discovered`) is still created by hand:
the agent writes `workspace.yaml` and a `sources.lock.yaml` of `docs`/`probe`
entries ([api-discovery.md](api-discovery.md)).

## Git conventions inside the workspace

- `main` is the only branch the skill writes to unless the user says
  otherwise. The engineer can branch freely.
- Commit subjects are prefixed by origin: `apply:` (selection applied),
  `discover:` (inventory refreshed), `decide:` (decisions/findings/memory only),
  `test:` (fixtures/cases/evidence), `edit:` (user hand edit committed on
  their behalf), `decide:` also for a `graphos-factory-core codify`, `fix:`. An
  `apply:` starts with `graphos-factory-core lock --check` (no uncodified hand
  edits), runs `graphos-factory-core reconcile --baseline HEAD` before editing
  (the delta it will apply) and after (must be `clean`, every override's
  assertions holding, and `changed since HEAD` naming only the spans the
  delta covers), then `graphos-factory-core lock`, and quotes all of it. On a
  first apply neither the schema (`<directory>.graphql`, as `workspace.yaml`
  names it) nor `.factory/applied.lock.yaml` is in HEAD yet: `reconcile`
  says so on stderr, naming that file, and reads the baseline as having no
  spans, so every span — the header included — is `added` in
  `modified_since_baseline`. A commit that holds the applied lock but not
  the schema is not a first apply, and like a `--baseline` that names no
  commit it is exit 2.
- The agent never amends or force-pushes. It never commits a file that
  contains a credential value; the bundled `scrub` script runs on every
  recorded sample and fixture before commit.
- Regenerating inventory (`discover`) never touches the schema; the agent
  reports the inventory diff (new, removed, changed operations) and waits
  for a selection change.

### Standalone repo, or a folder in a shared monorepo

A workspace works two ways, and every git-aware instrument already handles
both:

- **Standalone** — after `graphos-factory-core init`, the agent runs `git init`
  in the directory and the workspace *is* the repo.
- **A subdirectory of a shared repo** — a monorepo with one folder per
  service, so a team shares services without a repo each. The agent must **not** nest a second repo here: when the target is
  already inside a git repo, `graphos-factory-core init <repo>/<name>` creates
  the folder and the enclosing repo tracks it.

`graphos-factory-core init` itself never runs git, so the choice is always the
agent's (see [Creating a workspace](#creating-a-workspace-factory-init)).

Nothing else changes. `reconcile` derives the baseline with `git rev-parse
--show-prefix`, checks the revision with `git rev-parse --verify
<rev>^{commit}`, probes `<rev>:<prefix><schema>` (and, when that is
absent, `<rev>:<prefix>.factory/applied.lock.yaml`) with `git cat-file -e`,
then reads the schema with `git show`; `evidence` scopes its dirty check
with `git status --porcelain -- . ':(exclude).factory/evidence'`, taken
before any layer writes; and hand-edit detection reads the file's
log — all path-scoped, so they hold whether the `.git` sits at the workspace
root or above it. History is shared in a monorepo (`git log -- <name>/` for
one service); prefix commit subjects with the service (`apply(<name>): …`) to
keep the shared log legible. A target's publishing command is unaffected —
it reads the workspace folder wherever it lives.

## Read-only selection review

`selection review` validates and compares a candidate without saving, confirming choices,
or applying a schema. Read [selection-review.md](selection-review.md) only when using that
instrument. Ordinary selection and apply workflows do not require a review session or UI.
