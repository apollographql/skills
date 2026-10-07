# Your first subgraph: the linear path

A new workspace's first subgraph, document to `export`, in the order that
works: per step the commands, what to check, and the reference to read when
it does not match. `SKILL.md` stays the authority. Commands run from the
workspace root as `graphos-factory` (the shared references write
`graphos-factory-core`); `$S` is the scripts directory `env.sh` exports;
examples are Swagger Petstore v3. An exit marked **expected** is no stop.

## 0. Before the first command

- `bash <skill>/scripts/bootstrap.sh --check` (on 127, run it without
  `--check`), then `. <skill>/scripts/env.sh`.
- Ask the user, and wait for each answer:
  1. **The Elastic License v2** (https://www.elastic.co/licensing/elastic-license):
     only on an explicit yes, prefix the wrappers and `evidence` with
     `APOLLO_ELV2_LICENSE=accept`. Without it compose, unit, e2e and live
     are `not_run`, and nothing validates.
  2. **The toolchain**: when `bash $S/toolchain.sh --check` exits 1, ask
     before `bash $S/toolchain.sh` (the plugin and the Router only once the
     licence is accepted; Java 17+ is theirs).
  3. **Versions**: their Router (the oldest deployment) and their build
     pipeline's federation version. `init` pins `connect/v0.4`, which needs
     Router 2.15.0 and pipeline 2.14.1 (federation-subgraph.md § Versions).
- `context_mode`: `generic` for a generic wrapper (SKILL.md step 3). Fetch
  the document yourself; the binary never fetches.

Record nothing before step 1: `decisions add` in an empty directory creates
`.factory/`, and `init` then refuses the directory as a workspace.

## 1. `init`

```bash
graphos-factory init <dir> --name <name> --spec openapi.json --url <where you fetched it> --context-mode generic
cd <dir> && git init && git add -A && git commit -m "init: <name>"   # inside a repo: no git init
```

It lists `.factory/` (workspace, sources, inventory with its counts), the
working copy, and four skeletons: `<directory>.graphql` (links and the one
`@source`, no root field), `template.yaml`, `supergraph.yaml`,
`tests/router.yaml`. Act on every comment in `template.yaml` and the header:

- **Relative server** (`/api/v3`): `BASE_URL` is the stand-in
  `http://127.0.0.1:8080/api/v3`. Keep it; the production host comes at `export`.
- **Several security schemes**: the `AUTH_EXPR` comment names the one it
  describes; ask which the subgraph sends, and record it. A key sent bare in
  its own header (`value: "{{AUTH_EXPR}}"`) draws `quoted-auth-expr`.
- **No security scheme**: delete the Authorization header from `@source`
  and the `AUTH_EXPR` entry from `template.yaml`.

Now record the step 0 answers as decisions (step 3) and the licence consent
in `.factory/memory.md`. Read: workspace-contract.md § Creating a workspace.

## 2. What the API offers

`graphos-factory inventory list` (50 a page: follow `--offset
<next_offset>` until it is null) and `inventory describe <op-key>`. `?` is
needs_review (the reason beneath), `x` unsupported, `[read?]` a POST whose
name suggests a read: ask about each, since a POST is a write until the
user says otherwise. `links:` lines feed step 4. Read: spec-intake.md.

## 3. Agree the selection, and write it down

Agree each operation in or out, its root and its name. Each judgement is a
decision; `add` prints `N  label` per choice, and `--chosen` takes the N:

```bash
graphos-factory decisions add . --title "First release scope" --question "Which operations?" --choice "reads only" --choice "reads and writes"
graphos-factory decisions resolve . --id D-xxxxxx --chosen 1 --note "what the user said" --by user
```

No command creates `.factory/selection.yaml`; write it:

```yaml
contract_version: 2
defaults: { fields: all, max_depth: 6, opaque_json_policy: forbid }
operations:
  get:/pet/{petId}:
    include: true
    graphql: { root: query, name: pet }   # camelCase, unprefixed: the field is petstore_pet
  "post:/pet": { include: false, reason: "read-only first release" }
```

A name with an underscore is refused (`^[a-z][A-Za-z0-9]*$`). Read:
workspace-contract.md § `selection.yaml`.

## 4. `selection draft`, then confirm

`graphos-factory selection draft .` adds a `response.envelope` per included
operation and a `links:` entry per candidate fact, all `confirmed: false`.
Confirm each with the user (`confirmed: true`; a link may instead be
`include: false` with a `reason`). Without `selection.yaml`, `draft` exits
1 and `reconcile` exits 2 advising `selection draft`: write the file first.
Read: connectors-language.md § Relationship fields.

## 5. The first apply

| **Expected** on a fresh workspace | Exit | Why |
|---|---|---|
| `graphos-factory lock . --check` | 3 | "no .factory/applied.lock.yaml": nothing to codify yet |
| `graphos-factory context check .` | 0 | generic (a specialized workspace resolves its gaps first) |
| `graphos-factory reconcile . --baseline HEAD` | 1 | "N operations to apply", every span `added` |
| `bash $S/compose.sh .` | 1 | `QUERY_ROOT_MISSING`: no root field yet |
| `graphos-factory lint .` | 1 | `missing-field` per included operation until its root field exists; `no-applied-lock` and `no-evidence` warn until step 9 |

Write the schema under the header: a `<TypePrefix>_<Name>` type per shape,
a root field with its `@connect` per operation. An `int64` id argument is
`ID`; an `int64` output is `String` mapped with `->match([null, null], [@,
@->jsonStringify])` (schema-authoring.md § Scalar choice). Done when
`reconcile` ends `reconcile: clean` (exit 0) and `compose: pass`. Read:
connectors-language.md § `@connect`, mapping-language.md.

## 6. Relationship fields

`graphos-factory links apply . --dry-run` prints each confirmed link's
field: paste it into the host type it names, re-run `reconcile`. A refused
entry (`circular`, `self`, `no-fk-field`, `field-exists`, `nullable-fk`,
`no-host`, `no-root-field`, `target-refused`) exits 1. Write its tests:

- a unit entry, `target: "<Type>.<field>"`, `variables: { $this: { <fk>:
  "7" } }`, asserting the request and a `connectorResponse` (the
  `apiResponseBody` carries every property the selection names);
- an e2e case selecting the parent and the field: add it to the `x-cases`
  of the parent's and the by-id stubs, keeping their own;
- for a field printed with the null guard: a null-parent case whose parent
  stub omits the fk (a `null` fails conformance unless the spec allows it),
  a stub for the empty-segment GET (`/pet/`), and `graphos-factory codify .
  --waive <that stub> --status unmatched --reason R`.

Read: connectors-language.md § Relationship fields.

## 7. Tests: scaffold, audit, generate

```bash
graphos-factory scaffold .
bash $S/e2e.sh . --generate && bash $S/e2e.sh . && bash $S/unit.sh .
graphos-factory scaffold . --op <key> --status all-missing   # per operation, then --generate again
```

Audit every placeholder before `--generate`: valid is not meaningful. An
integer-backed `ID` gets an integer literal (`petId: 1`) the API must
accept. A `unit-no-response` note: write that `connectorResponse` by hand.
Read every snapshot for `redacted`, `valueCompletion` and `errors`. Exit 3
from the error scaffold refused a status whose stub would match an existing
one: hand-write that case with a distinct matcher (another argument value;
a WireMock scenario for a call with none) and `# expect-upstream-status:
CODE` first. `graphos-factory error-statuses .` shows what is owed. Read:
testing.md § Scaffolding the tests, § Error cases.

## 8. The offline checks

```bash
graphos-factory validate .                 # no fail, no unmatched; unchecked is reported, never a pass
graphos-factory source-coverage . --check  # "0 of N selected operations fail the bar"
graphos-factory lint .                     # 0 errors (schema-authoring.md § Coverage, testing.md)
```

## 9. `lock`, then `evidence`

```bash
graphos-factory lock .            # --model only with the identifier the host supplies
git add -A && git commit -m "apply: <what changed>"
graphos-factory evidence . --scripts $S
git add .factory/evidence && git commit -m "apply: evidence"
```

`lock --check --provenance` exiting 3 on provenance drift alone (a case, a
stub, `selection.yaml`) means relock; a changed span means codify first
(SKILL.md, "Hand edits"). `evidence` records a hash of every file its
layers read, and `export` refuses any of them changed since: run `evidence`
last, after your final edit (a commit is not required). Only `pass` is a
pass. The `operations:` line counts selected operations with executed
evidence; a `not validated:` line names each without, and its absence is
the only all-clear. `live` is `not_run` without `tests/live.yaml` and the
credential (testing.md § Live smoke tests); `supergraph_check` is `not_run`
until the user's `APOLLO_KEY` and a graph ref are both there: ask once
which `<graph>@<variant>` and set `GRAPHOS_FACTORY_GRAPH_REF` on the run
(verification.md). Report each `not_run` as not run.

## 10. `export`

Ask the user for the production base URL, base path included (Petstore:
`/api/v3`), then run `graphos-factory export . --out <dir outside the
workspace> --base-url <that URL>`. Hand the user its output: the `rover
subgraph check` and `publish` commands they run with their own credentials,
the router minimum and credential variables, and the "Not verified by this
export" list, which you report as not verified. Never run rover yourself.
Read: export-graphos.md.

## When something refuses

| Refusal | Fix |
|---|---|
| `evidence-stale` (export) | re-run `evidence`: it names each file changed, added or removed since the last run |
| `base-url-local` (export) | the test default is this machine: `--base-url` with the production host the user gave |
| `--out … is inside the workspace` (export) | a directory outside the workspace |
| `unacknowledged-edit` (lint, `lock --check`) | yours, in this apply: `lock`; anyone else's: codify it (SKILL.md, "Hand edits") |
| `missing-template` (lint) | restore `template.yaml` (`git checkout --` it; its shape: workspace-contract.md § The local-validation files) |
| `fixture-overlap` (lint) | add the `absent` matchers it names to the broader stub, or give the narrower one a priority |
| `unproven-operation` (lint) | a selected operation with no evidence row: re-run `evidence` |
| `pagination-bounds-unknown` (lint) | write "no documented maximum" in the size argument's doc comment |
| `quoted-auth-expr` (lint) | right only for a key the API takes with no scheme; otherwise `Bearer {{AUTH_EXPR}}` |
| ELv2 `not_run` (compose, unit, e2e, live) | ask once (step 0); on a yes, prefix with `APOLLO_ELV2_LICENSE=accept` |
