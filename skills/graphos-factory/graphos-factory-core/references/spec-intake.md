# Spec intake: OpenAPI 3.x and Swagger 2.0

Before authoring, assess customer context ([`customer-context.md`](customer-context.md)). A readable
API contract does not establish that customer-defined fields or the chosen
scope are available. Reuse existing answers and record unresolved inputs.

`graphos-factory-core inventory build <document>` reads a description document —
OpenAPI 3.x or Swagger 2.0, JSON or YAML — into `.factory/inventory.json`.
Record which one it is with `sources pin` (`kind: openapi` or `kind: swagger`,
detected from the document; the workspace's `intake` is `spec` for both).
Work from the inventory, not the raw spec: a large API's document (hundreds
of operations, megabytes of JSON) does not fit in context, and
`inventory list` / `inventory describe <key>` exist so it never has to.

Swagger 2.0 is rewritten into the OpenAPI 3 model while reading (a separate
reader; the vendor's bytes are what `sources.lock.yaml` records). `host`/`basePath`/`schemes` become `base_urls`,
`definitions` become shapes, `securityDefinitions` become `api.auth`. A `body`
parameter is the request body with the content type `consumes` names
(operation over root; a wildcard or no `consumes` means JSON). `formData`
parameters leave `parameters` and become one request body — an object shape
named `<opId>Request`, urlencoded and supported — unless a part is
`type: file` or the API accepts only multipart, in which case the body is
`multipart/form-data` and the operation is `unsupported` with that reason
(Connectors send JSON or form bodies). An operation that declares both a body
and formData parameters is `needs_review` naming the parts that were not
modelled. `type: file` is spelled `string`/`binary`; `x-nullable` is read as
`nullable`. None of this applies to an OpenAPI 3 document, which is read
exactly as before even when it carries those keys.

```bash
graphos-factory-core inventory build openapi.json                      # build (swagger.json works the same way)
graphos-factory-core inventory list --tag Incidents --limit 25         # page, grouped by tag
graphos-factory-core inventory list --support needs_review             # what needs a decision
graphos-factory-core inventory describe get:/v2/incidents              # one operation, shapes expanded
graphos-factory-core inventory links . [--json]                        # every relationship hint flat: shape, property path, canonical GET-by-id target, list-item host, target selected; then the GET-by-id operations refused as targets and why
graphos-factory-core inventory diff old.json .factory/inventory.json # what a refresh changed
```

`inventory list` prints one page: 50 operations unless `--limit N` (1 or more)
says otherwise. The text page ends with `next page: --offset N --limit L`
when more remain. The `--json` object carries `total`, `offset`, `limit` and
`next_offset` — the offset of the next page, `null` on the last one — and
prints the same `next page` line on stderr, leaving stdout pure JSON. Anything
that walks every operation (an obligations loop, a coverage count, a
selection draft check) reads `next_offset` and calls again until it is
`null`; reading `operations` from the first page alone silently stops at 50.
An unparsable `--offset` or `--limit`, a bare one with no value (an empty
loop variable), or `--limit 0`, is refused with exit 1.

## What the reader decides, and what it refuses to

It classifies every operation as `supported`, `needs_review`, or
`unsupported` **with a reason**, because that is a fact about Apollo
Connectors rather than about your API:

| Classification | Cause |
|---|---|
| `unsupported` | no documented success response; a non-JSON success body (CSV, NDJSON, binary); a request body the connector cannot send; a `$ref` that does not resolve |
| `needs_review` | `deepObject` or exploded object query params; repeated array query params |
| `supported` | everything else, including a 204 with no body |

Everything else is your decision: `semantics` is `read` for GET/HEAD and
`write` for everything else, **a POST included** — a POST is a write until
the user says so, because a write mistaken for a read puts a side effect
under `Query`, where callers, caches and retries treat it as safe, and the
reader cannot tell; a read mistaken for a write only changes the schema's
root, which the user corrects at `select`. So the reader never guesses
`read`. A POST
whose name carries a read verb gets a `read_hint` (`[read?]` in
`inventory list`); surface those to the user and confirm which are reads
before choosing `root: query`. Nothing in the file names a GraphQL type,
field or root.

## Facts and judgements

`inventory.json` is a straight, deterministic representation of the source:
every field is checkable against the document, the whole file is regenerable
at any time, **it is never hand-edited, and it never governs the schema**.
Every judgement that affects the schema or the tests lives in
`selection.yaml`.

So the inventory does not say which key a payload's content sits under. It
records the facts that decide it, and the tool proposes an answer from them:

| Response fact | What it means |
|---|---|
| `root_is_array` | the success shape is itself an array — nothing to unwrap |
| `root_property_count` | how many properties the root object declares, links included |
| `link_root_properties` | the hypermedia ones (`_links`, `links`) |
| `array_root_properties` | the array-typed ones |
| `sole_root_property` | the only non-link property, when there is exactly one |
| `total_items_property` | the one naming a collection total |
| `cursor_root_properties` | the ones that could carry a next cursor |

A key carrying no information is omitted, so every key present says
something true. `graphos-factory-core selection draft` turns them into one
`response: { envelope: …, confirmed: false }` block per included operation
and each `candidate_entity_link` fact into a `links:` entry, also
`confirmed: false`; see [schema-authoring.md](schema-authoring.md) §Envelopes for the rule and
for what to do when you disagree with a proposal.

**When an inference is wrong, never edit `inventory.json`.** The lock hashes
it, so `lock --check` exits 3, `reconcile` names it and lint reports
`unacknowledged-inventory-edit`; `inventory build` refuses to overwrite it
and prints what it would have changed. There are exactly two right moves:

- **the document is wrong** (a field the API sends as null, a missing
  response, a wrong type) — edit the pinned working copy and
  `graphos-factory-core codify --source PATH --reason R`, then rebuild the
  inventory. That is the rest of this page.
- **the tool made a judgement you disagree with** — write the answer you
  want into `selection.yaml` (the envelope, the root, the name, the
  pagination block) and re-run `reconcile`. No codify is needed: the
  selection is where judgements belong, so there is nothing to codify.

`graphos-factory-core codify --key` is for neither: it records a hand edit to the
*schema*, and refuses a span that is in sync with the lock.

The inventory also records what it *couldn't* read, in `unresolved[]`.
Between `operations[]` and `unresolved[]`, every operation the spec
contains is accounted for. When you present the inventory to the user,
present that accounting too — "what was left on the table" is the question
a selection UI exists to answer.

## What the reader records about authentication

`components.securitySchemes` becomes `api.auth[]`, one entry per scheme with
its `kind`, the header or query parameter, the scheme prefix where the
document implies one (`http`/`bearer` → `Bearer `; an `apiKey` scheme
carries no prefix — that comes from the vendor's docs or a probe and goes in
`memory.md`), and `source: spec`. An `oauth2` scheme also records what it
declares about its flows, verbatim:

```jsonc
{
  "kind": "oauth2", "header": "Authorization", "prefix": "Bearer ",
  "scheme_name": "oauth", "source": "spec",
  "oauth2": {
    "flows": ["authorization_code", "client_credentials"],   // every flow named
    "authorization_code": {                                   // each declared flow, verbatim
      "authorization_url": "https://accounts.google.com/o/oauth2/v2/auth",
      "token_url": "https://oauth2.googleapis.com/token",
      "refresh_url": "…",                                     // when declared
      "scopes": [{ "name": "…/spreadsheets.readonly", "description": "See all your Google Sheets spreadsheets" }]
    }
  }
}
```

A flow missing either endpoint is named in `flows` but not recorded; an
`openIdConnect` scheme is `oauth2` to the request (a bearer token) and has
no flow. Swagger 2.0's `accessCode` / `application` flows arrive as
`authorization_code` / `client_credentials`.

Which operations need which scopes is recorded where the document says it:
`api.security` is the document's default requirement and
`operations[].security` an operation's own, both in OpenAPI's grammar — a
list of alternatives, each a map from scheme name to scopes — and an
operation without its own key requires the default. `[]` on an operation
means the document says it takes no credential. A target that drafts
auth configuration unions the scopes of the selected operations from
these, so a read-only selection asks for read-only scopes; its references
say what it writes and what you still have to decide.

## Spec defect classes, and the policy for each

Vendor specs lie. These classes recur:

- **Write schemas omit fields the API accepts.** No automated layer can see
  this: fixtures derived from a spec are self-consistent with a *wrong*
  spec. Only real traffic finds it. → patch, per the convention below.
- **Explicit `null` where a list or object is expected** (`tags: null`).
  Spec-noncompliant, common. → treat as absent.
- **`requestBody.required` lives on the referenced component**, not on the
  operation. Reading the operation object directly reports "not required"
  for a body that is. → resolve the `$ref` before concluding anything about
  a body's nullability. (The inventory reader already does.)
- **A free-form `type: object` body** — description, maybe an example, no
  properties — is a real shape meaning "arbitrary JSON", not a defect. →
  opaque JSON scalar with a whole-body passthrough, never a synthesised
  input wrapper.
- **`x-extensible-enum`** means an open enum. → `String`.
- **Constraint-only and augmentation `allOf` members** (a member with
  `required` and no properties; a member re-declaring a property to add
  fields) are normal composition idioms. → merge them; the reader does.
- **Wrong `operationId`s**, copy-pasted from a sibling endpoint. → fix the
  *name in `selection.yaml`*, never by editing the spec.
- **Declared-but-dead endpoints**, documented and 404 forever. The spec
  cannot tell you; only a probe can. → record in `memory.md`, exclude with
  a reason.

## Pinned specs and patches (the former FACTORY PATCH convention)

The spec is pinned in two copies. `graphos-factory-core sources pin --path
openapi.json [--url URL]` (or `--path swagger.json` for a 2.0 document; the
file name is yours, the kind is detected) keeps the vendor's bytes exactly as
retrieved at `.factory/sources/<name>.upstream.<ext>` (never edited; its hash
is `upstream_sha256`), records kind (`openapi` for 3.x, `swagger` for 2.0),
version and hashes on the `sources.lock.yaml` entry, and acknowledges the
working copy in `applied.lock.yaml`. The file at `path` is the working copy:
the reader reads it, and the agent or the engineer may edit it.

When the spec is wrong in a way that changes the schema, edit the working
copy and codify the edit:

```bash
# edit the working copy (openapi.json here), then
graphos-factory-core codify . --source openapi.json --reason "live API returns null summary; spec marks it required"
```

codify computes the structural difference between upstream and working copy
(JSON Patch; formatting never counts), writes it to the entry's `patches`
with the reason (and `context`, from `--context TEXT`), records no
decision, and refreshes
the lock, and prints the next step: rebuild the inventory (`graphos-factory-core
inventory build openapi.json`; an `intake: mixed` workspace re-runs `infer
--update-inventory` after it) and re-run `reconcile`: nothing records which document the
inventory was built from, so until you do, `inventory.json` and the schema
still describe the vendor's version and every gate stays green. An
operation already recorded keeps its own reason, context and decision; when
nothing changed, nothing is written and codify says so (the `--reason` is not
used). Add `verified:` by hand — a patch without it is a
guess. `--decision D-id` (numbered or random) attaches the new patches to
a real decision the user made: they take that id, and codify warns if no
such record is there yet. codify rewrites the whole `patches:`
block each run, so the keys you
add to a patch (`verified`, and `reason`/`context`/`decision` edits) survive but YAML
comments inside the block do not; put commentary in `context` instead:

```yaml
contract_version: 1
sources:
  - kind: openapi
    version: "3.0.3"
    url: https://api.widgets.test/openapi.json
    retrieved_at: 2026-09-08T14:02:11Z
    path: openapi.json
    upstream: .factory/sources/openapi.upstream.json
    upstream_sha256: 3f1c…
    patches:
      - op: replace
        path: /components/schemas/Widget/required
        value: [id]
        was: [id, summary]
        reason: "live API returns null summary; spec marks it required"
        context: "every draft widget probed so far has a null summary"
        verified: { how: recorded sample, sample: .factory/samples/getWidget/1.json }
```

An edit nobody codified is named by `lock --check` (exit 3), `reconcile`
and `lint` (`unacknowledged-source-edit`), and blocks `apply`. A modified
upstream is `source-upstream-modified`: restore it, never codify it. Because
the patches are enumerated over the untouched upstream, re-bundling the
vendor spec means re-applying them and reporting the ones that no longer
fit — which is why they are recorded rather than merely marked.

## Refreshing against a new spec

`discover` rebuilds the inventory and **never touches the schema**. Run
`inventory diff` against the previous file, take the added / removed /
changed list to the user, change `selection.yaml`, then `apply`. A refresh
that silently rewrote the schema would be regeneration by another name, and
losing hand edits that way is the failure this whole tool exists to avoid.

Watch for a changed operation whose `fields` list includes `response`: the
component behind an unchanged `$ref` moved, so every operation using it
changed too. The diff reports it on each of them deliberately.

An API-level summary can move with no operation changing. The diff reports
it on its own line, `api.pagination: cursor -> offset (counts, request,
style)`: the headline moved, but each operation's own `pagination` block is
still what gets exposed.

**A new vendor document is a new baseline, not a hand edit.** When you
re-fetch the spec, do not `codify --source` the vendor's changes as
patches, and do not copy it over the working copy. Fetch it to a file and
refresh:

```bash
curl -fsSL https://api.example.test/openapi.json -o /tmp/openapi-2.1.json
graphos-factory-core sources refresh . --path openapi.json --from /tmp/openapi-2.1.json \
  --url https://api.example.test/openapi.json --reason "vendor published 2.1"
```

`refresh` makes the fetched file the upstream copy, replays the entry's
`patches[]` over it and reports each one: **re-applied** (its target is as
the patch left it; kept with its reason, decision and `verified`),
**obsolete** (the vendor now says what the patch produced; dropped), or in
**conflict** (the vendor changed the target — dropped, not applied, exit 3).
The working copy is rewritten from the new upstream plus the re-applied
patches, a finding recorded in `findings.json` (`source: sources`)
captures both hashes, the origin label and every patch's fate with
the reason it had, `applied.lock.yaml` acknowledges
the new working copy, and `.factory/inventory.json` is rebuilt with the
`inventory diff` printed — so `lock --check` and `lint` are clean right
after, and the next step is the one above: `reconcile`, take the diff to
the user, edit `selection.yaml`, `apply`. A conflict is yours to finish:
re-apply its intent to the working copy by hand and `codify --source` it
with the new reason; the old one is in the finding. Re-verify a re-applied
patch's `verified` sample against the new version when the vendor's
changelog touches that operation. `--dry-run` prints the fates and the diff
and writes nothing. `--reason` is required (the finding's text); `--url`
is kept from the entry unless the vendor moved the document. The refresh
refuses (exit 2, nothing written) an uncodified edit to the working copy
(it would be overwritten — codify first), a modified upstream, a `--from`
that is the working copy itself, and a document the reader cannot build an
inventory from (a dangling `$ref`: fix a copy, or refresh from a version
that reads). Exit 4 is a write that failed once writing had begun (a disk
error): the message lists what was written and the `git checkout --` that
restores it; run the refresh again after. A YAML working copy is re-emitted from the parsed document when
a patch survives — its comments do not; it is upstream plus patches and
nothing else. After a real refresh, say what else it invalidates: recorded
fixtures and `tests/live.yaml` cases were made against the previous version,
so re-run e2e and the live smoke before calling the workspace current.

`sources pin --force --reason R` remains the tool for a baseline that is
*wrong* rather than old (the edited copy was pinned by mistake): it replaces
the upstream with the current working copy, records a finding (`source:
sources`) with both hashes, and does not replay patches. A plain `sources pin` refuses a
modified or missing upstream once the entry records `upstream_sha256` —
restore the file instead of re-pinning it. Both copies are workspace-relative — never absolute, never `..` —
because they are committed and travel with the workspace, and the vendor
copy lives directly under `.factory/sources/` (a directory reserved for
vendor copies, one per document, never shared), never at a working copy or
the schema, so `--force` cannot overwrite one; an entry that breaks either
rule is `source-outside-workspace` / `source-upstream-misplaced` (or
`source-duplicate-path` for two entries pinning one file) and nothing is
read or written through it. An entry with no `upstream_sha256` yet (hand-written, or
from before the two copies were distinguished) is the one case a plain
`pin` takes the bytes on disk as the baseline — provided they parse; a
stray unreadable file at that path is refused. Removing a document entry
from `sources.lock.yaml` while `applied.lock.yaml` still acknowledges the
file is `source-unpinned`; run `graphos-factory-core lock` to stop watching it
on purpose. Let `sources pin` write `kind`: the inventory's patch marks
resolve a Swagger document's `/definitions/` pointers by the recorded kind,
so a hand-typed wrong kind (`source-kind-mismatch`) loses them until the
record is fixed.
