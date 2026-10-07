# Testing

`graphos-factory-core evidence` checks customer context before invoking live
tests. Unresolved context is `not_run` with a reason;
an invalid record fails that layer. Offline layers continue. Run
`graphos-factory-core context check . --phase live --json` to see what is missing.
See [`customer-context.md`](customer-context.md).

Eight layers. Each exists because it catches something no other layer can, and
each has a blind spot that makes a green result mean less than it looks. The
table is the most valuable thing in this file: it tells you which green
checkmarks to distrust.

| Layer | Command | Catches | Blind to |
|---|---|---|---|
| compose | `scripts/compose.sh` | invalid SDL, unresolved selection fields, connect-spec violations | anything about runtime values |
| connector unit | `scripts/unit.sh` | outbound request shape for scalar-argument operations | **every write** (below), object-valued `$args`, whether the API agrees |
| WireMock e2e | `scripts/e2e.sh` | the only layer where a real router parses real documents and sends real requests | whatever the fixture does not assert |
| write-body proof | in-process in `graphos-factory-core evidence`; standalone `graphos-factory-core serialization` | a body-sending write whose argument, fixed body value, omission or explicit null no executed e2e case demands at its own wire location; a write with no arguments; reports write gaps and read gaps apart (non-gating) | anything the e2e layer does not execute: it reads that layer's per-case log and is only as strong as it |
| conformance | `graphos-factory-core validate` | fixture and request bodies vs. the spec or the inferred schema | anything self-consistently wrong in a wrong spec |
| lint | `graphos-factory-core lint` | coverage, namespacing, the target's contract, opaque-JSON policy, a decision with no alternative (`decision-without-alternative`) | correctness of what is covered |
| json-accounting | `graphos-factory-core spans json-accounting --json --check` | a response field the SDL still types as the workspace's JSON scalar with no resolved `json_reasons` entry, or one whose recorded reason no longer holds against `inventory.json` (non-gating) | whether the reason is the right call: it re-checks the predicate, not the judgement |
| live | `scripts/live.sh` | spec-vs-reality, silent nulls | runs only with a credential (or against a keyless sandbox); a case chains ids only from an earlier case in the same run |

compose, unit, e2e and live run rover's supergraph composition plugin, and
e2e and live run the Apollo Router; the composition plugin and the Router
are licensed under the Elastic License v2
(https://www.elastic.co/licensing/elastic-license). The user accepts it,
once, by reading it and setting `APOLLO_ELV2_LICENSE=accept` in their
environment; rover reads the variable itself. The scripts never set it:
until it is set, `toolchain.sh` downloads neither the plugin nor the Router,
e2e downloads no Router, and those four
wrappers print the instruction and exit 3, which `evidence` records as
`not_run` with the reason `<layer>: APOLLO_ELV2_LICENSE is not set to
accept, …`. The agent asks once, showing the link; on an explicit yes it
sets `APOLLO_ELV2_LICENSE=accept` for the commands it runs in that session
(a prefix on each wrapper call, or one `export`), records the consent in
`memory.md`, and tells the user that an `export` in their shell profile
makes it permanent. Never set it unasked, and never report such a
workspace as validated.

`evidence/latest.json` records the status of each layer per run and per
operation. `skipped` and `not_run` are first-class and are never reported as
`pass`. A unit run with zero cases is `not_run` (`unit: no runnable cases:`
plus each suite header's first sentence), not a pass, because rover's
`0 passed; 0 failed` proves nothing. `unit.sh` counts cases per suite, and
every suite with none must cite in that sentence the decision behind it
(`D-0019` or `D-k7m2qx`), or the layer fails, whether or not other suites ran. A
`skip: true` case also fails the layer: rover counts it as skipped and
still says SUCCESSFUL. The zero-case run is the one `not_run` the
validation gate accepts
([workspace-contract.md](workspace-contract.md) § `evidence/latest.json`). A workspace where any selected operation lacks executed evidence is
not validated — say so plainly rather than quoting the layers that did run.
`evidence`'s report counts it for you: after the layer table, an
`operations:` line gives the selected operations, those with executed
evidence (a unit, e2e or live `pass`; conformance executes nothing) and
those left `unchecked` at e2e or at conformance, and the report ends with a
`not validated:` line naming each operation with none (ten, then a count),
or one saying no executed layer ran, with the first layer's reason. The
absence of that line is the only all-clear the report gives.

## Running a subset

`unit.sh` and `e2e.sh` take `--only PATTERN` to run one case instead of the
whole suite while iterating on it. PATTERN is a literal substring, never a
glob, matched against whichever name the layer actually lays cases out by:

- `unit.sh` matches the quoted `name:` of a `tests:` entry in
  `*.connector.yaml`. That entry is coarser than what `TEST RESULTS:`
  counts — one entry asserts several things (method, URL, headers, body,
  response mapping), and rover's "N passed" tallies those, not entries; a
  suite of 67 entries can report 402 passed.
- `e2e.sh` matches a case's file basename under `tests/cases/` (the
  three-files-per-case layout), hyphens and underscores
  interchangeable — the same normalisation the mapping classifier below
  already applies.

A PATTERN matching no case fails closed (exit 1, with a message) rather
than let an empty run print a vacuous "0 passed; 0 failed" as a green
result. `e2e.sh` still classifies every mapping in
`tests/fixtures/mappings/` regardless of `--only`, so a filtered run
cannot hide an unclassifiable fixture — only which cases actually execute
is filtered. This is a different flag from `graphos-factory-core evidence
--only layer,layer`, which selects whole layers, not cases within one;
`evidence` always shells `unit.sh`/`e2e.sh` with no flags, so it keeps
running every case.

## Cases and fixtures

Where the workspace has recordings, fixtures are **derived**, not typed:
`graphos-factory-core fixtures` builds every mapping from `.factory/recordings.yaml`
(case → sample), so a stub's request matcher is the request that was really
sent (base path stripped, repeated parameters as `hasExactly`) and its
response is what the API really returned. Re-record and regenerate; never
edit a derived mapping.

Derivation also closes the sibling hazard that flat loading creates.
Grouped by method and `urlPath`, `fixtures` takes the union of the query
parameter keys *any* sibling mapping asserts, and writes `{"absent": true}`
into every mapping in the group that does not assert one. Without it a
recording that sent no optional parameter derives a matcher with no
`queryParameters` at all — unconstrained, so it also answers the sibling
request that *did* send one, and which stub wins is WireMock's tie-break
rather than which case is running. Deck-of-cards is the worked example:
`new_deck` (no parameters) now demands `jokers_enabled`, `deck_count` and
`cards` all absent, so it can no longer stand in for `new_deck_jokers`.
This is why a hand-written mapping is a liability — regenerate instead, and
if you must write one by hand, assert every sibling key you do not send as
`absent` yourself.

A case is a GraphQL document plus its expected response:

```
tests/cases/list_widgets.graphql
tests/cases/list_widgets.expected.json
tests/fixtures/mappings/list_widgets.json     # the WireMock stub that answers it
```

The runner loads every stub once, before the first case, and leaves them all
loaded for the whole suite — only the request journal resets between cases —
so every stub is mounted flat for the whole suite, and a mapping
must still be classifiable as exactly one of:

1. **Case-scoped by tag** — `"metadata": { "x-cases": ["list_widgets", …] }`.
2. **Case-scoped by name** — the basename matches the case name; hyphens
   and underscores are interchangeable.
3. **Explicitly shared** — `"metadata": { "x-shared": true }`, for a stub
   every case genuinely hits (an auth endpoint). Not for "several cases".

An empty `"x-cases": []` is valid and useful: it preserves a recorded
response for an operation that has no case yet, classified but loaded for
nothing. Use it — with an `x-note` saying why — when a required argument or
a fixed pagination path makes a recording unreachable. Do not invent a case
the connector cannot send.

A case-scoped stub may also carry `"metadata": { "x-required": true }`:
`e2e.sh` then fails the case, naming the file, unless that stub answered at
least one of the case's requests. "Some stub matched" cannot tell a case
whose connector ran from one the planner answered another way. `scaffold`
sets it on a `$batch` case's lookup, whose planner resolves the
entity's fields locally, and never calls the lookup, when the root
connector already maps them.

There is deliberately no fallback. A mapping that fits none of the three
fails the run before any case executes, because unclassifiable loading lets
one case be answered by another case's stub while accounting still looks
green.

Flat loading means every stub's `request` matcher must be unique across the
whole workspace: two stubs WireMock could both match for the same real
request are answered by whichever one WireMock's own tie-break happens to
prefer, never by which case is running. `graphos-factory-core lint`'s
`fixture-collision` rule (an error, not a warning — it means a test proves
less than it looks like it does) catches the exact-duplicate case: two
stubs whose whole `request` object is structurally identical, naming both
files. `fixture-overlap` (an error too) catches the *partial*
overlap: a stub whose matcher constrains a subset of what a sibling's does
(fewer query parameters or headers, fewer body patterns, the rest equal), so
it answers every request the sibling was written for. A scaffolded
`X_minimal` stub that names no optional query parameter is the shape: it
also matched `X`'s `?lang=` request, and the stub WireMock loaded last
answered. The finding names the `absent` matchers that settle it, or, when
only a body tells the two apart, a `priority` for the more specific stub
(lower answers first; a stub that outranks the broader one answers its own
requests, the broader one the rest). It compares every mapping, the ones
loaded for no case too, because a runner that mounts the whole directory
loads those as well. `scaffold` writes the minimal stub with every query key
it drops `absent`, and `fixtures` does the same for derived siblings.

`e2e.sh` still catches what the rule cannot (two matchers that overlap
without one containing the other, `equalTo` against `matches`): after each
case it reads the request journal and fails the case when a stub that
answered is not the case's own (its `x-cases`, its name, or `x-shared`),
naming the foreign stub. That is how a connector that drops a query
parameter still fails when a sibling's `absent` matcher would answer it.
It loads stubs and runs cases in byte order (`LC_ALL=C`) whatever the
shell's locale: WireMock answers a request two stubs match with the one
loaded last, and under `en_US.UTF-8` `X_minimal.json` sorts before `X.json`
while under C it sorts after, so the locale used to decide which stub
answered and a run could pass on one machine and fail on another.

Some requests are identical by definition — no field left to make them
differ (a fetch endpoint that sends no body at all, so its success
stub and its negative-control error stub can never be distinguished by
`request`). The only way to answer two such requests differently is
WireMock Scenarios: give both stubs the same `scenarioName` and each its
own `requiredScenarioState`. Spell the name with letters, digits, `.`, `_`,
`~` and `-` only: WireMock 3.13.2's scenario admin API does not decode a
percent-encoded name, so `e2e.sh` refuses any other name before a case runs. `fixture-collision` accepts a colliding group
on exactly those terms — same scenario, every member's own distinct
state — and still fails a group that only partly qualifies (no scenario,
mixed scenario names, a missing or repeated state). `e2e.sh` resets every
scenario to `Started` before each case (`POST $ADMIN/scenarios/reset`,
alongside the request-journal reset), then reads that case's own stub(s)
for a `requiredScenarioState` other than `Started` and sets it directly
(`PUT $ADMIN/scenarios/{name}/state`) before firing the request. No
separate per-case declaration exists or is needed for this: the state to
run from is already on the stub that answers the case.

A runner that starts WireMock once for the whole suite and never resets
scenario state between cases cannot run a scenario pair: the pair would
depend on alphabetical ordering and stay in its advanced state for every
later case touching the same stub. A target that hands the suite to such a
runner says, in its own references, how a scenario member is marked and
dropped.

## Pagination test coverage

When an operation exposes a page-limit argument—especially when the inventory
declares a `maximum`—author cases covering: (a) a rejected over-maximum limit
and its error shape; (b) recovery that restarts at page 0 after a page-size
change (continuing at page N with the new size skips records in the gap);
(c) iterating to complete coverage rather than treating one page as the
collection (page 0..N, last page short or empty, assert the union of records
covers the expected set). These cases are not scaffolded automatically.

## Copy and update test coverage

When a write implements a copy or update flow touching a behavior-affecting
field (pinned, archived, visibility, status...), the case's body matcher must
demand the preserved field with the source's value — `equalToJson` on a body
containing `"pinned": true`, not an empty or partial body with
`ignoreExtraElements` (which matches anything; see the trap noted elsewhere
in this file). Prove the assertion is load-bearing: flip the demanded value
and confirm the case fails.

## Scaffolding the tests

Where the workspace has no recordings, the first draft of every test comes
from `graphos-factory-core scaffold`, not from typing. For each selected
operation with no case it writes the case document (every argument passed
with a placeholder typed from the spec, lists with two elements, the
connector's whole selection), the stub (method, path, credential header, a
matcher per query key, `equalToJson` for a flat body, a response built from
the inventory shape and carrying every path the selection names, however many
arrays it crosses; a branch the depth cap cuts keeps the properties its shape
requires, so the body still conforms) and a unit entry (scalar `$args`, the request, the
mapped response); a body-sending mutation with optional arguments also gets
its `_minimal` case. An input-object argument is sampled from the schema
(every required field, a nested input included, and one optional field per
object; the `_minimal` case keeps the required ones only) and a custom scalar
takes the JSON type of the wire slot it feeds (an `Int64` on an integer slot
is an integer literal, a map slot a one-key object). A `String` on a slot
that declares a closed set the schema could not make an enum (SCIM URNs)
takes the set's first value. An `ID` on an integer slot is an integer
literal; a `String` on a numeric or boolean slot (the non-identifying int64)
is that value as a string (`"1"`), since GraphQL rejects `1` for a `String`.
rover cannot pass an
object-valued `$args`, so a required input object means no unit entry (a note
says so; the e2e case proves the request) and an optional one is left out of
it, as a list is. A write whose required body argument is a list or an
integer, number or boolean gets no unit entry either: rover would drop or
stringify it, and `validate` would fail that request body. Every file carries a `scaffold:` header or an
`x-scaffold` mark: it is a draft.

```
graphos-factory-core scaffold .                 # every selected operation without a case; exit 2 when there is none
graphos-factory-core scaffold . --op KEY --force  # regenerate one: its case, its stub, and its own unit entry replaced (or removed, when the new plan writes none)
graphos-factory-core scaffold . --dry-run --json  # the plan, nothing written
```

`--force` alone is refused (it would replace every audited case). The suite
is parsed before the scaffold appends to it — a suite it did not write, with
items at column 0 or without a `tests:` key, is fine; an unparseable one, or
one with a top-level key after `tests:`, stops the run with nothing written —
and new entries take the suite's own indentation and go at the end of the
file, so a regenerated entry moves below any hand-written ones. A run that
writes no unit entry never creates a suite. Under `--op KEY --force` it still
parses an existing one, and removes the scaffold's own earlier entry for that
target when the new plan writes none (the note says so), so an entry can
leave the suite; a hand-written entry stays. The file is rewritten only when
an entry went in or came out.

### Error cases

```
graphos-factory-core scaffold . --op KEY --status 404          # one documented status
graphos-factory-core scaffold . --op KEY --status all-missing  # every documented non-2xx status no case covers yet
```

Per status: `tests/cases/<case>_<status>.graphql`, whose first line is
`# expect-upstream-status: <code>`, and a stub answering `<code>` with the
inventory's documented error body (none when the spec documents none; the
case's `scaffold:` comment says which). No unit entry: rover cannot set a
response status. Each status gets its own argument values (`id-404`), so no
two error stubs match the same request. When the error stub would match
exactly what an existing stub matches (an operation with no argument, or a
success stub matching method and path only), scaffold refuses that status
(exit 3) instead of writing a stub WireMock might not choose. Give the stubs
distinct matchers by hand. The same refusal applies to two error cases
planned in one run whose requests come out identical (an argumentless call,
a body whose values the sampler cannot vary by status): the first is written,
the rest are refused. `4XX` is written as 400 and `default` as 500. The
snapshot comes from `e2e.sh --generate`, as for every case.

e2e.sh reads what WireMock actually served, before the snapshot diff. A
status counts for an operation only when it answered **that operation's own
request**: a journal entry with the operation's method whose URL path ends
with its path template (a `{parameter}` is one non-empty segment; a base path
may stand in front). A nested `/users/` lookup that answers 404 beside the
root call's 200 is not the root operation's 404.
- **A case with `# expect-upstream-status: CODE`** fails unless the own
  request of an operation whose root field the case calls answered `CODE`.
- **A case without the directive** is `UNPROVEN` when both hold: an operation
  it calls had its own request answered a non-2xx status, and that operation
  documents more than one. It is counted apart (`e2e: P passed, F failed, U
  unproven`) and never as a pass. Evidence records that operation's e2e
  status as `unchecked`.

Put the directive on every hand-written error case too.

**Error coverage.** Evidence reconciles, per operation, the statuses the
inventory documents with the statuses a *passing* case saw answer the
operation's own request (`SERVED:` lines e2e.sh prints). The result is
`layers.wiremock_e2e.error_coverage[<op>] = {documented, executed, not_run}`.
A documented status in `not_run` has no executed case: the operation's e2e
verdict is `unchecked` (with a `note` naming the statuses), the layer's
findings say `error coverage incomplete`, the validation gate (and a
target's gate computed from it) refuses the workspace, and CI's `assert-evidence.sh` fails, because a green case next to a missing
one proves nothing about the missing one. `graphos-factory-core error-statuses .`
prints each operation's documented and executed statuses. There is no
allow-list: a status scaffold refused (its request is identical across
statuses) gets a hand-written case. Vary what the stub demands: a distinct
`from` header and `title` that the stub matches exactly (pagerduty's
`create_incident_401`), or, for a call with no input at all, a WireMock
scenario as described above: the error stubs share a `scenarioName`, each
has its own `requiredScenarioState` and `priority: 1`, and the success stub
stays outside the scenario so it answers in state `Started`
(pagerduty's `current_user_400` / `current_user_429`). Check each such case is load-bearing: change the
directive's status and the case must fail. A `4XX`/`5XX` range is covered by
any served code of that class, `default` by any non-2xx.

Then, in order: audit every placeholder against what the API really accepts
(the values are *valid*, not *meaningful*), `e2e.sh . --generate`, `unit.sh .`,
`graphos-factory-core validate .`, `graphos-factory-core lint .`. The notes printed per
operation name what the unit entry left out and why — list `$args`, a query
value carrying `:` or `,`, an optional integer/number/boolean body argument
(the three rover behaviours below) — and the e2e case proves those. What the
scaffold cannot assert honestly it does not write: no unit entry for an
operation whose spec documents no response body or whose body mapping is
neither a flat `key: $args.x` list nor the sub-selection form generators
write for input objects (`order: $args.order { customer_id: customerId }`,
evaluated against the case's own values, so the stub demands the wire names
exactly; an input object sent as dotted query keys, `"filter_by.x":
$args.filterBy.x`, has each leaf asserted), no `connectorResponse` for a selection in the
mapping language or one naming a key the shape-built body lacks. Each comes
with a note, and the layer or lint rule concerned (`write_body_proof`,
`unit-no-response`, `missing-unit`) keeps firing until you write it. The
scaffold asserts what the router sends: an enum argument forwarded without
`->match` is asserted as the GraphQL value, and when `validate` then fails
the request body it is the connector that needs the mapping, not the test.
Delete the header once you have audited; lint does not read it, people do.

**A sparse-fieldsets GET** (schema-authoring.md § Sparse fieldsets) gets two
cases from its declared default:

- **`<case>`** omits the argument, and its stub demands the exact default
  (`equalTo`). This is the only executable proof that the router applies
  the default; rover cannot give it. Its body carries only the fields the
  default requests, as the source's would: at the top for a node, in each
  item for a list, whose wrapper stays whole. A mapped field the default
  leaves out resolves null, and the scaffold notes name it.
- **`<case>_<param>_narrowed`** passes one field (`id` when the default has
  it). Its stub demands exactly that value and answers with that field
  alone, and its document selects only that field.

A default containing a comma gets **no unit entry**: rover percent-encodes
the comma, so the URL assertion cannot match any request form. The scaffold
notes say so, and `missing-unit` does not fire for such an operation. A
single-field default keeps its unit entry, with the default passed
explicitly.

When **every** selected operation is such a GET (a read-only Graph-style
service), scaffold writes no suite at all, lint stays quiet, and `unit.sh`
fails on the missing `tests/*.connector.yaml`, so `connector_unit` records
`fail`. Prefer one entry written by hand for the narrowed form: pass
`<param>: "id"` explicitly (no comma, so the URL assertion `?<param>=id`
matches) and give it a `connectorResponse` carrying that field alone, as
the `<case>_<param>_narrowed` stub does. `connector_unit` then passes on a
real assertion. The alternative is an empty suite whose header's first
sentence cites the decision that accepts it (`D-0019` or `D-k7m2qx`). `connector_unit`
is then `not_run` with that reason (see above), never a pass.

Stub bodies answer an **expansion boundary** the way the source does:

- an expanded boundary carries the children the declared default requests;
- any other boundary carries exactly its verified default leaves, so
  `business.name` under a two-leaf default gets a real `name`, not a
  misleading null;
- a boundary whose default is still `unverified` is left out of the body,
  with a note.

## Traps that have cost real sessions

- **The wrappers used to run whatever binary they found first.** The order
  is `$GRAPHOS_FACTORY_CORE_BIN`, the bootstrap cache
  (`~/.cache/graphos-factory-core/<owner>-<repo>/bin`), then PATH, so a cache a long-ago
  bootstrap filled shadows a newer binary on PATH. A session rendered every
  layer with a 0.5.1 cache while the skill expected 0.5.45, and nothing
  said so. `scripts/resolve-bin.sh`, which every wrapper sources, now prints
  `graphos-factory-core: <layer> runs <path> (from <where>), version <v>
  (expected >= <pin>)` on every run and exits 78 (`<layer>: FAIL — ...`)
  when the binary is older than the pin or reports no version. The pin is
  what `bootstrap.sh` installs: `$GRAPHOS_FACTORY_CORE_VERSION`, else
  `crate/Cargo.toml`, else, in a copy of the core installed inside a skill
  with no crate/ above it, that copy's `release.env`. A newer binary is accepted (edge is built from
  main's head). `graphos-factory-core evidence` sets `GRAPHOS_FACTORY_CORE_BIN` to
  itself when it is unset, so a layer runs on the binary that was invoked.
  Evidence records exit 78 as `fail`. Fix it with `bootstrap.sh` (`--build`
  in a checkout) or `GRAPHOS_FACTORY_CORE_BIN`; read the `runs` line in a layer's
  log before you trust its output.

- **A redacted error snapshot proves no status.** Without
  `include_subgraph_errors` in `tests/router.yaml`, every subgraph error
  renders as `"Subgraph errors redacted"`, so a 401 case and a 404 case
  snapshot alike. Swapping the two stubs' statuses still passes the snapshot
  diff (omni). `# expect-upstream-status: CODE` is what proves the
  operation's own request was served the status it names.

- **Every e2e case reports `dead stubs?` at once.** Check the
  `connectors.sources` key in `tests/router.yaml` first
  ([§ The connector-source key](#the-connector-source-key-in-testsrouteryaml)).
  A wrong key fails no layer on its own.

- **`equalToJson: {}` with `ignoreExtraElements` matches any body.** A body
  matcher that reads as evidence can assert nothing. Check what the matcher
  *demands*, not that one exists. Prove an assertion is load-bearing by
  changing the demanded value and confirming the case fails with
  `matched no loaded stub`.
- **`rover connector test` cannot cover a write, and fails at it quietly.**
  Object-valued `$args` are inexpressible: a YAML map is rejected outright,
  but a JSON string (`'{"a": 1}'`) and a GraphQL literal (`'{a: 1}'`) are
  both *accepted* and then silently never become an input object — the
  outbound body is `{}` while the method and URI assertions still report
  success. Cover every write with a hand-authored WireMock case (a real
  GraphQL document, so nested input literals work) plus a fixture whose
  `bodyPatterns[].equalToJson` demands the values.
- **`rover connector test` exits 0 even when suites fail.** The
  `TEST RESULTS: FAILED` / `SUCCESSFUL` summary line is the verdict;
  `unit.sh` reads it and fails closed when no summary appears at all.
  [rover#3746](https://github.com/apollographql/rover/pull/3746) makes it
  exit 1 but is not released yet (rover 0.41.0 is current); keep reading the
  summary line either way.
- **Never cite `rover connector run` as evidence.** When the connector
  fails it still exits 0, and `--format json` says `"success": true`;
  mapping problems and 4xx/5xx responses do not fail it either. Use it to
  look at one request by hand, and prove the connector with a unit or e2e
  case.
- **Remove `"persistent": true` from any imported mapping.** WireMock
  restores persistent stubs after the `POST /__admin/reset` the runner does
  between cases, so stubs accumulate and an earlier fixture answers a later
  request while accounting stays green.
- **An empty credential header is a matcher hazard.** A header declared by
  `@source` is still sent when its expression resolves empty (`Bearer` with
  no token), and WireMock normalises an empty-value matcher as `absent` —
  removing the discriminator and making the stub match everything on that
  path.
- **A loose `contains` body matcher can select the wrong fixture
  deterministically** when the token also appears as a field name in
  another operation's body. Match syntax unique to the operation.
- **Assert error mappings with `include_subgraph_errors: { all: true }` in
  `tests/router.yaml`**, or the snapshot shows only `Subgraph errors
  redacted` and the test passes without asserting anything.
- **Never edit a recorded fixture to make a test pass.** Fix the schema, the
  case, or the expectation. A fixture edited to fit is a test that agrees
  with itself.
- **A green suite is not evidence for *your* change.** Before citing a pass
  count as verification of a specific field, grep the case for that field.
  A run of 210 passing cases says only that nothing else broke if no case
  selects the thing you changed.
- **A negative assertion needs a control.** "The request was rejected" only
  says something about your change if something else could have accepted
  it. Pair it with a run differing *only* in the setting under test.
- **A new regression test can pass vacuously.** Revert the fix and confirm
  the test fails; assert that the fixture actually exercised the condition,
  so it fails loudly if a later change stops reaching it. A test whose
  subject never occurs asserts over an empty set.
- **Two defences, one test: delete each one separately.** When a guard is
  layered — `.factory` custody is an `lstat` per component *and* `O_NOFOLLOW`
  on the open — reverting one layer leaves the tests green,
  because the other layer catches the case. That reads as "this test does not
  cover the change" and tempts you to add an assertion that is already true.
  Delete each layer on its own and record what goes red for each: the
  `lstat` walk turns out to own the directory components, `O_NOFOLLOW` owns
  the final one, and deleting both turns everything red. If a layer's control
  turns *nothing* red, say so plainly rather than claiming coverage — a race
  window is real even when no deterministic test can open it.
- **An "optional file" read that defaults to empty hides a refusal.**
  `read(...).unwrap_or_default()` treats *every* failure as absence: a
  missing file, a permission error, and a file the tool deliberately refused
  all become `""`, and the next write appends to nothing. Separate "not
  there" from "not allowed" at the read (`is_not_found()`), and let
  everything else reach the caller. `.ok()` and `.ok().flatten()` at the
  *call site* undo it again, and that reads as harmless because the read
  itself is correct: `sources::status` took the vendor copy with
  `read_optional(...).ok().flatten()`, so a symlinked
  `.upstream.json` reported "no upstream copy — restore it
  (git checkout -- …)" about a file that was sitting right there. Grep the
  callers, not only the reads, and test the refusal through the *surface the
  user sees* — the status line, the lint rule — not only the status struct.

## The connector-source key in `tests/router.yaml`

`connectors.sources` is keyed `<subgraph>.<source>`: the subgraph name as
written in `supergraph.yaml`, a dot, and the `@source` name. The two halves
are spelled differently. The subgraph name is usually the hyphenated
directory, and the source name is underscored:

```yaml
connectors:
  sources:
    granola-dryrun.granola_dryrun:   # supergraph.yaml subgraph . @source(name:)
      override_url: "http://localhost:8080"
```

pagerduty's is `pagerduty.pagerduty`, where the halves happen to match. A
wrong key is not an error anywhere: the override never applies, no request
reaches WireMock, and every e2e case fails with `case made no upstream
request (dead stubs?)`, with no hint that the key is wrong or which half.

- **A stack overflow in the binary is a bug; never raise limits to get past
  it.** `source-coverage` aborted with `thread 'main' has overflowed its
  stack` on HubSpot's Lists operations (a `oneOf` of seven `$ref`s that
  each hold the array again). Raising `ulimit -s` or
  `RUST_MIN_STACK` did not finish the walk: the recursion is unbounded, and
  one such run grew past 90 GB before it was killed. Record the operations
  as "not verified by that layer", report the crash, and fix the walk. Run a
  heavy command as `/usr/bin/time -l` and stop it at 4 GB.

## Two suites side by side

`e2e.sh` takes its ports from the environment — `WIREMOCK_PORT` (8080),
`ROUTER_PORT` (4000), `ROUTER_HEALTH_PORT` (8088); `live.sh` the latter two —
and both refuse to start on a busy one. The committed `tests/router.yaml`
keeps `override_url: "http://localhost:8080"`; `graphos-factory-core render`
writes the copy the router actually runs with, every local `override_url`
moved to the WireMock port and `supergraph.listen` / `health_check.listen`
set (an `override_url` that is not local fails the render), so two workspaces
(or two runs of one) can validate at the same time. Do not set
`health_check.enabled: false` in `tests/router.yaml`: the rewrite keeps it,
and `e2e.sh` waits on that probe. Both scripts wait 30s for it by default;
`E2E_ROUTER_START_SECONDS` raises that for a large supergraph (the Databricks
one took Apollo Router 2.17.0 152.6s to report healthy). A router that exits
first is reported at once, with the tail of its log.

```
WIREMOCK_PORT=8090 ROUTER_PORT=4100 ROUTER_HEALTH_PORT=8188 bash $S/e2e.sh other-workspace
```

## Snapshots

Regenerate expected files rather than hand-writing them, then **read the
diff**. Audit every snapshot for `redacted` and `valueCompletion` — both
mean the response did not come back the way the case claims. And do not
reason about "added lines" from a rendered diff: alignment artifacts make a
pure deletion look like an insertion. Compare snapshot bodies as line
multisets when the change should only remove.

## Live smoke tests

Every selected operation is accounted for at this layer: it is either a
case below or an `exclusions:` entry naming the operation and the reason it
cannot be exercised live (a user-scoped token the CI key is not, an id that
must come from a previous response, a write against a shared account). The
evidence records an excluded operation's live status as `excluded` with the
reason; lint warns (`live-unaccounted`) on a selected operation that is
neither, because an anonymous `n/a` hides exactly the gap a reader of the
evidence needs to see.

A relationship field (connectors-language.md § Relationship fields) has no
evidence row, so it is accounted for by name: a live case whose document
selects it on its host type, or an `exclusions:` entry `field:
"<Type>.<field>"` with its reason. Each entry names exactly one
of `operation:` or `field:`. `live.sh` prints a field exclusion as
`EXCLUDED FIELD: <Type>.<field> — <reason>`; evidence keeps it among the
live layer's `findings`, never as a status, and its report names the field
as not validated. Lint warns `link-live-unaccounted` on a field that is
neither, whenever `tests/live.yaml` exists; an operation exclusion whose
reason mentions the field does not count.

`tests/live.yaml` holds credential-gated cases against a real sandbox. They
are the only layer that catches a **silent null** — a mapped field the
payload does not have, which yields `null` with no error anywhere else in
the stack. Add `require:` assertions on the fields you most depend on. When
the vendor has no safe sandbox, record that in `memory.md` and let the layer
report `not_run` with that reason.

**Chaining ids.** A case may take GraphQL variables from an *earlier* case's
response, so an operation that needs an id is a live case, not an exclusion:

```yaml
  - name: project
    variables:
      projectId: { from: list_projects, path: ".data.x_listProjects.results[0].id" }
```

`tests/live/project.graphql` declares `query ($projectId: ID!) { … }`. The
value is the jq `path` over the named case's saved response; a case that has
not passed before this one, an invalid path, or a path that yields `null`
fails the case with that reason — never a silent skip, so an empty tester
account shows up as a failure you fix (seed the data, record it under
`memory.md`), not as a green layer. A write chain (`create` → read →
`close`/`delete`) is `safety: write-safe` and must clean up after itself.

**Credentials file.** `live.sh` reads credentials from the environment, and
also loads the nearest gitignored `smoke.env` from the workspace up to the top
of its git checkout (or `$GRAPHOS_FACTORY_CORE_LIVE_ENV`, which must exist when
set). The file is `NAME=value` lines, parsed and never sourced; the
environment wins over it, and values are never printed. Nothing ignores it
for you: before writing one, add `smoke.env` to the repository's
`.gitignore` and confirm `git check-ignore smoke.env` matches, so a
credential is never committed. It is loaded inside
the live process **only**. The unit render ignores `<SERVICE>_BASE_URL`,
but compose and e2e render with every override, so a real value
exported into a whole `graphos-factory-core evidence` run would still change what
those layers test. A git worktree has
its own top — point `GRAPHOS_FACTORY_CORE_LIVE_ENV` at the main checkout's file.

## `rover connector test` behaviours that shape a suite

Learned on the pagerduty pilot (rover 0.40.0); each cost a run to find.

- **List-valued `$args` are rejected at parse time** (`Test Suite Parse
  Error - YAML`), as are maps. A list argument can only be proven at e2e —
  WireMock's `hasExactly` matcher on the repeated query parameter is the
  assertion.
- **Every selected property must exist in `apiResponseBody`**, and a
  sub-selection into a null object is a problem too. Both surface as
  `UNMATCHED GraphQL::Problem Occurred` and fail the case. Give unit
  payloads every selected key, with a real object wherever the selection
  descends. At runtime the router just yields null.
- **`connectorResponse` omits keys the payload lacked** — it does not
  null-fill from the type. Write the expectation from the payload.
- **A `:` in a query value cannot be asserted**: rover encodes it as `%3A`
  in the request and URL-normalises the expectation, so neither spelling
  matches. Use date-only values at unit; full timestamps at e2e.
- **Type-level (entity) connectors are testable here** with
  `target: "<Type>"` and `variables.$this`, and only here: the router does
  not expose `_entities` to clients.
- **A relationship field is testable here too** — a field-level
  `@connect` keyed by `$this` (connectors-language.md § Relationship
  fields) — with `target: "<Type>.<field>"`, `variables.$this` carrying the
  host's foreign-key field and, under per-call auth, `variables.$args` the
  mirrored credential. `scaffold` does not yet draft either
  test and `evidence/latest.json` has no row for the field: write this unit
  entry by hand, and one e2e case selecting the parent root field with the
  nested field inside it, served by a WireMock mapping for the by-id GET
  keyed on the parent stub's foreign-key value. Lint's `link-untested`
  warns on a field missing either: the unit entry is found by
  the `target:` of a `tests[]` entry, each suite read as YAML (a comment or
  a block scalar's text does not count, and with no suite the entry is
  missing); the case by parsing each `tests/cases/*.graphql` against the
  schema and walking each operation through the fragments it spreads (an
  alias, a spread or inline fragment counts; a comment, an unspread
  fragment, a literal `@skip(if: true)` / `@include(if: false)` or a
  same-named field on another type does not). It does not check that a
  mapping serves the by-id GET. The null-parent case is
  `link-null-untested`'s: with a nullable fk, some mapping must
  answer `GET` on the empty-segment path (`"urlPath": "/owners/"`) while
  serving a case that selects the field. A confirmed link with neither
  test, or with no null-parent case, is not validated; say so.
- **`$this` reaches only the request side, and a null `$this` value is not
  what the router sends** (rover 0.41.0, measured on AppWorld Spotify).
  `variables.$this: { albumId: 7123 }` builds the URI, but
  `isSuccess` and the selection see no `$this` (`Property .albumId not
  found in object`, location `IsSuccess` / `Selection`) — which is why the
  null guard reads `$($this.<fk> ?! 0)`. `albumId: null` renders
  `/spotify/albums/null`; the router sends `/spotify/albums/`. A null
  parent is therefore an e2e and live case only: a parent stub with a
  `null` fk beside a set one, and a mapping for the empty-segment GET
  answering what the API answers (connectors-language.md § Relationship
  fields).
- **Body constructors keep constant keys of nested objects when their
  argument is null**: `priority: { id: $args.priorityId, type: "x" }` sends
  `{type: "x"}`. Use `$args.priorityId->map({ id: @, type: "x" })->first` so
  an omitted argument drops the key; `->map` alone on a scalar yields a
  one-element array. An explicit `null` still goes through the map
  (`{id: null, type: "x"}`, measured on pagerduty): to drop that too, guard the
  argument, `$args.priorityId?->map({ id: @, type: "x" })->first`.

- **Every `$args` scalar reaches the connector as a string.**
  `escalationLevel: 2` under `variables.$args` becomes `"escalation_level":
  "2"` in the asserted body — not what the router sends for an `Int`. Keep
  Int and Boolean arguments that land in a JSON body out of unit entries and
  prove them at e2e (pagerduty `update_incident_escalate`). Query parameters
  are unaffected: they are strings on the wire anyway.
- **`#` comments inside a `selection` string are fine** for compose, the
  unit framework and the router; an engineer's annotated reorder is a real
  edit `graphos-factory-core reconcile --baseline` must preserve, not a formatting quirk.

## What lint and the write-body-proof layer demand of the tests themselves

These lint rules read the unit suites and the entity keys, and warn (or
fail, where marked) when a test or a key exists but proves less than it
looks like it does:

| Rule | What it wants | Why |
|---|---|---|
| `unit-no-credential` | every unit entry that asserts the request also asserts the credential header (the `@source` header carrying `{{AUTH_EXPR}}`) | the one header every request must carry |
| `unit-no-response` | every operation with unit entries has at least one asserting `connectorResponse` | request shape proven, mapping back not |
| `failure-case-missing` (warning; one finding per operation listing its open statuses, per-status detail in `--json`) | every non-2xx status the inventory documents for a selected operation has an e2e case calling its root field behind the case's own stub answering that status to the operation's own request (its method and path template; a nested lookup answering it does not count) (`4XX` any 4xx, `default` any non-2xx); unit entries do not count, since no suite sets a response status | an `errors` mapping that maps a 404 nobody returns is untested, however right it reads |
| `entity-without-lookup` (error) | each resolvable `@key` of a type is served by a selected operation that returns the type and takes that key (a path/query parameter named for it, a by-id last path segment ending with it, or a body property on a read), or by a bulk lookup batch find rates `batchable` on that key; a `resolvable: false` key needs none | nothing can resolve a reference by that key |
| `entity-key-not-embedded` (error) | wherever a connector's selection embeds a `@key` type, what it builds carries every field of at least one key, read through the selection (`pet { id: pet_id }`, `owner: user { … }`, `pet: { id: petId }`) at the wire path it reaches; a spread, method chain or `$this` is not judged | the router cannot turn that embedding into a reference |
| `entity-without-consumer` (warning) | some root field or field of another type returns the `@key` type | the key serves no reference in this subgraph |
| `entity-field-unresolved` (warning) | every field of a `@key` type is mapped by a connector selection that reaches the type, or has its own `@connect`; not checked on a `resolvable: false` stub | a resolved reference comes back without it |

**`graphos-factory-core serialization`**, wired as the `write_body_proof`
evidence layer next to `connector_unit` and `wiremock_e2e`,
replaced four earlier lint rules — `list-arg-unproven`, `mutation-cases`,
`loose-write-body`, `unit-no-body` — that only sampled the test *shape*
(does a case file pass every argument, is the stub's matcher exact) rather
than proving *placement*: a dropped argument whose value happened to recur
elsewhere in the same demanded body passed all four (`crate/tests/integration/lint.rs`,
`the_new_layer_catches_a_dropped_argument_whose_value_recurs_elsewhere_the_old_lints_miss`).
The layer reads where the connector puts every argument (a body pointer, a
query key, a path or header placeholder) and requires an executed e2e case
whose stub demands the case's value *there*, not merely somewhere in the
body or URL. It also requires a case proving each optional body argument's
key absent when omitted, and, for explicit `null`, a stated behavior plus a
case proving it: the workspace's `defaults.null_handling` in
`selection.yaml` (state `omit`, "do not touch", unless the vendor needs
`send_null`, "clear"), overridden per argument by
`decisions add --null-handling 'op|arg|behavior'` (behavior: send_null or
omit). With neither it is unproven, and a stub that shows the other
behavior is unproven whatever was stated. A body member the connector guards
with `?` (`$args.x?`) drops a null and an absent argument and nothing else:
an empty string, empty list, `false` and `0` are still sent, and a null
inside a kept object stays, so prove the drop with a case passing an explicit
null behind an exact stub. A request-direction omit decision
(`decisions add --omit`) removes an optional source body member from this
proof, because the record says why the connector does not send it; a member
the source marks required is never removed by one and stays a gap
(`required_member_omitted`, naming the decision), root omit (`.`) included. An argument the reader cannot place (a method chain, `??`) is
placed by execution when an executed, passing case's stub demands the
argument's own value at exactly one body pointer in the request that case
makes; the expression is not read. The value must be distinctive: a value
found at several pointers, a boolean, a short number or string, or the same
value as another argument's in the same case is `ambiguous_value` — give the
argument a different value in the case (the stub follows). A value the
connector reshapes (a date, a casing) is not found and stays
`unproven_mapping`: record why or restructure the mapping, never read it as
covered. `graphos-factory-core serialization --json` lists each argument's
`placements` (`static` or `executed`, with the proving case).

Same-run evidence contract: the layer takes the CURRENT
`evidence` run's own `wiremock_e2e` status and log — built earlier in the
same invocation — never `.factory/evidence/latest.json` on disk, which
mid-run still holds the *previous* run's file. Its per-case verdicts
(`pass` / `fail` / `unproven`) land in `case_proofs` on `wiremock_e2e`'s own
evidence-layer entry, additive to the existing integer `cases`. Run
`e2e.sh` (or `evidence`) first on a pilot, which commits no logs, or every
case reads not recorded.

Two more read the schema against the spec rather than the tests:

| Rule | What it wants | Why |
|---|---|---|
| `field-casing` | no snake_case field on any `type`, `interface` or `input`, and no root field whose name after the prefix is snake_case, unless a doc comment on the field says why the wire name is kept | GraphQL fields are camelCase; a type's rename belongs in the selection (`fooBar: foo_bar`), a root field's in `selection.yaml`'s `graphql.name`, and a silent exception is indistinguishable from an oversight |
| `wire-enum-drift` | an enum-typed argument declares no value the spec does not list for the parameter or body key its slot feeds; an enum-typed selected leaf declares every value the spec lists for that property — unless the slot's own expression maps it with `->match` | the router sends an argument's enum value and hands a payload's back as spelled; `RED` for a wire `red` fails at runtime, and a payload `pending` the enum lacks fails coercion; an enum value the API never returns is harmless |
| `unknown-tag` (warning) | every `@tag(name: …)` is in the target's tag vocabulary (`Target.tag_vocabulary`; no vocabulary, no rule) | no tag-based policy reads a name outside it, so the field looks tagged and is not |
| `error-path-unresolved` | every `$.` path in a connector `errors` block — the message and the extensions, each side of a `??` chain separately, and each `->first`/`->last` step into an array item — must resolve in at least one error body shape the inventory documents (`errors[].shape_ref` in `.factory/inventory.json`) for the operations the block covers: every operation on the source, for an `@source` block; the one operation, for a per-`@connect` block | a path guessed from another API's convention (`.detail` is FastAPI's, not this API's) silently reads nothing off a documented `{message}` or `{error: {message}}` body and the caller gets `null`; silent when no error shape is documented at all, and a free-form body counts as resolving |

A third reads the same argument and leaf slots from the other side
and is a warning, because the schema is less descriptive than the source
rather than wrong:

| Rule | What it wants | Why |
|---|---|---|
| `closed-enum-as-string` | no selected argument or response leaf typed `String` (or `[String]`) over a source parameter or property whose `enum` is all strings, **two or more** of them, every one a valid GraphQL enum name (`^[_A-Za-z][_0-9A-Za-z]*$`, not `true`/`false`/`null`) — unless the slot's own expression maps it (`->match`), or a **resolved** decision in `.factory/decisions.json` or a current finding in `.factory/findings.json` names the slot in `affects`: `Gitea_Issue.state` for a field, `gitea_listIssues(state)`, `Query.gitea_listIssues(state)` or the several-argument `gitea_listIssues(state, type)` for an argument. A field that several selected operations reach is judged on **every** spec property that reaches it, and fires only when all of them declare such an enum; a reach the spec does not document (no response shape, or a parent object absent from it) declares none | schema-authoring.md § Enums says that vocabulary is a GraphQL enum, and a consumer reading `String` has to guess it; a vocabulary the grammar cannot spell (`10`, `in-progress`) is not reported because `String` is right there; an `open` decision is a pending question, not a recorded reason. Two conditions keep it quiet where an enum would be wrong or empty, with no decision needed: a **one-value** `enum` is a constant discriminator (`Pagerduty_Service.type` is always `service`) and a one-member enum says nothing the field does not; and a **shared** field (`Pagerduty_Reference.type`, one type for ten reference slots, enumerated by the spec at one of them) would, as an enum built from the declaring slot, fail coercion on the others — when every reaching property does declare one, the finding lists the union of their values. An argument is one slot. One finding per argument and per field, at the field's own line, naming the operation, the parameter or property (each reaching one, for a shared field), the values (eight, then `(+N more)`) and both remedies; the proposed `enum` declaration carries every value, since it is the line to paste |

The argument half of `wire-enum-drift`, `int-overflow` and
`closed-enum-as-string` is one reading of the connector: a `queryParams`
entry `key: $args.arg`, a `{$args.arg}` in the HTTP path, or a flat `body` of
`key: $args.arg` entries. Entries are separated by **whitespace, and a
newline is whitespace**: `queryParams: "a: $args.a b: $args.b"` on one line is
both pairs, and a one-line `body` carrying several pairs is a flat body,
exactly as the same pairs written one per line. Earlier the
reading was line-oriented — a one-line `queryParams` yielded its first pair
only and a one-line multi-pair `body` was not flat at all — and the AppWorld
snapshot `appworld-0b51a5f3-20260915`, which writes all 275 of its blocks
that way (197 with two or more pairs), had its two G5 slots in exactly that
blind spot. A `->match` or `$(…)` on one pair skips that slot
alone, whatever shares its line. What is still not read, on one line as on
many: a body that is not a pure list of pairs — a nested object, a literal,
a method, a `$args.x.y` path, a bare `$args.input`, or pairs separated by
commas (the mapping language has none) — is not flat. `scaffold` evaluates
one of those itself, the `key: $args.x { wire: gql … }` sub-selection,
and says so in its notes for the rest. One pair per line stays the house style, and every pilot
writes it; a one-line block is no longer a way to lose a rule.

Five more enforce pagination and copy-state documentation in the schema. They fall into two categories: **generation defects** (the agent should have written it) and **source-contract gaps** (the source does not document it, and the schema should say so):

| Rule | Category | What it wants | Why |
|---|---|---|---|
| `pagination-bounds-undocumented` | generation defect | when the inventory declares `default` and/or `maximum` for a pagination size param, the schema arg's doc comment must state the number; for a bound outside `Int` (int64's `9223372036854775807`), `no practical maximum` / `no practical default` satisfies it instead | the agent already knows these values; omitting them from the schema is an oversight, not a source gap |
| `pagination-bounds-unknown` | source-contract gap | when the inventory has **neither** `default` **nor** `maximum` for a size param, the arg doc comment must state "no documented maximum" or similar | the source does not constrain page size; silence is indistinguishable from the agent forgetting |
| `page-limit-not-int` | generation defect | when the inventory says a size param is `integer` or `number`, the schema arg type must be `Int` | the agent chose a non-numeric type (`String`, `Float`) despite the spec saying integer |
| `list-completion-missing` | generation defect | a paginated operation's root-field doc comment must contain a keyword indicating pagination (`page`, `iterate`, `collection`, `total`, `cursor`, `complete`) | the schema describes one page as if it were the whole collection; a consumer needs to know it must iterate |
| `copy-state-undocumented` | advisory heuristic | a mutation whose name contains `copy`, `clone`, or `duplicate` should have a description containing a preservation keyword (`carry over`, `preserve`, `omitted`, `default`) | heuristic: a copy operation that does not document which fields carry over from the source is ambiguous; false positives are possible, hence advisory |

Those five are all warnings. A pilot is expected to be clean of the casing and
wire-vocabulary rules; the pilots' schemas predate the pagination guidance and still carry its
`pagination-bounds-unknown` warnings — a new service should be clean of all of
them.

Two things to know about `list-completion-missing`. It reads the
root field's **own** doc comment: an earlier version read from the first `"""`
in the file, so a block-doc root field was silently exempt and only a
single-line description could ever trip the rule. And it matches its keywords
anywhere in the description, so the `Returns:` line that
[schema-authoring.md](schema-authoring.md) § Descriptions requires satisfies it
on its own whenever the response envelope has a field named `total`. Write the
one-page/stop-condition sentence because a consumer needs it, not because the
rule is complaining. `copy-state-undocumented` reads the text the same way and
had the same blind spot; both now carry a block-doc firing/compliant test pair
in `crate/tests/integration/lint.rs`.

Two check that a description exists at all, for the default-on
halves of [schema-authoring.md](schema-authoring.md) § Descriptions and
§ Argument constraints. Each finding carries the text to write, so the fix is
a copy.

| Rule | Category | What it wants | Why |
|---|---|---|---|
| `undocumented-root-field` | generation defect (**error**) | a selected operation's root field has a doc comment whenever there is text to give it: the selection's `graphql.description`, else the inventory operation's `summary`, else its `description` (Google discovery specs have no summaries) | the doc comment is what an MCP client shows a model choosing between tools; one Drive build shipped 26 root fields with none while the inventory held the text for every one |
| `argument-constraints-undocumented` | generation defect (warning) | a root-field argument has a doc comment whenever the source parameter or body property it reaches (a `queryParams` key, a `{$args.x}` path segment aligned with the inventory path, a header whose value is the argument, a body key flat or nested in object literals) carries `default`, `minimum`, `maximum` or `enum`; the message spells the constraint clause (schema-authoring.md § Argument constraints). The page-size and page-index parameters are `pagination-bounds-*`'s and are skipped | the caller — usually another agent — otherwise guesses or probes; a warning because it reads only a missing comment, not one that omits the clause |
| `argument-constraints-undocumented`, omission half | generation defect (warning; `source-coverage --check` fails on the same sentence, and a `behaviour` waiver — on a resolved decision or a current finding — clears both) | an optional (no `!`) argument's doc comment carries its source description's omission sentence — the first sentence with a default (`by default`, `defaults to`, `default is`, …) or a condition on absence (`if not passed`, `If this parameter is not provided`, `If no card is given`, `when unset`, `unless specified`, `Omit to`, …; the full list is schema-authoring.md § Argument constraints) that names no other parameter or body property of the operation, nor a body key beside it — as a whitespace-normalised, case-insensitive substring without its final period; fires with or without a doc comment and quotes the sentence. Same skips as above | the first-sentence trim dropped Venmo's "If not passed, Venmo balance will be used."; agents that did not know it topped up the balance instead of paying by card and failed 7 of 7, where direct payments passed 26 of 26 |
| `argument-required-optional-in-source` | generation defect (**error**) | an argument is not `!` when its source parameter, or its body key's enclosing object, is optional (the inventory says `required: false`, or omits the key from the object's `required` list); a resolved `behaviour` decision naming the operation and `location:name` clears it, and an inventory that says nothing about requiredness is quiet | `!` hides the source's omission behaviour: the caller cannot leave the argument out, and it is the cheapest way past `source-coverage`'s behaviour gate |

When a root field has no doc comment at all and there is vendor text,
`list-completion-missing` and `copy-state-undocumented` stay quiet on it:
`undocumented-root-field` is the one finding. The source-sentence half of an
argument's doc comment is opt-in and has no machine-readable
marker, so nothing checks it.

One more reads the Returns line itself, and is a warning: the
line is prose for the consuming agent, and a wrong one misleads rather than
breaks.

| Rule | What it wants | Why |
|---|---|---|
| `returns-line-nesting` | in a selected root field's `Returns:`, `Returns a list of items with:` or ``Each item in `x` has:`` line, every listed name is a field of the type it is listed under (the SDL return type, list and non-null unwrapped; the item type of `x`); an object-typed first-level entry is braced (the envelope's payload field in the first line excepted); a second-level object entry is braced exactly when its type has at most 6 fields, every one a scalar, enum or opaque-JSON scalar. Not checked: order, the 14 and 6 caps, `(+N more)`; silent when the doc comment has no Returns line | a bare object name reads as a leaf and the agent selects it bare (schema-authoring.md § Returned field names); 11 bare-selection errors on the 25 Sep AppWorld bundle came from second-level names the one-level rule left bare |

Another reads a root field's description for the service's own credential
rule, and is a warning. It applies only to a service that mints its
credential through a selected operation.

| Rule | Category | What it wants | Why |
|---|---|---|---|
| `credential-source-undocumented` | generation defect | when two or more selected root fields declare an argument with the same credential name (`access_token`, `accessToken`, `token`, `api_key`, `apiKey`, `auth_token`, `authToken`, `bearer_token`, `session_token`) and a selected root field's return type (list and non-null removed) declares a field of that name or its camelCase form, at least one such minting root's doc comment names the argument **before** its Returns line. One finding per name, at the first minting root | the composed supergraph keeps one schema description, so a service's auth rule written there, or in a `#` comment, never reaches the consumer; the Returns line names the credential as a result field, which says nothing about where it goes next. Silent when no root returns the credential (it lives on `@source`), and on all three pilots, whose schemas declare none of these names |

One more reads the schema against the spec's declared **numeric range**,
and is an **error** rather than a warning: the value is wrong at
runtime, not merely undocumented, and it landed together with the pilot fix it
demands.

| Rule | Category | What it wants | Why |
|---|---|---|---|
| `int-overflow` | correctness bug | a selected operation's response leaf or argument typed `Int` must not be backed by a source property or parameter the spec declares `format: int64`, `uint64` or `uint32` (unsigned, so its upper half is past 2^31), or whose `minimum`/`maximum` falls outside [-2147483648, 2147483647]. That includes one made exclusive by a boolean `exclusiveMinimum`/`exclusiveMaximum` (OpenAPI 3.0, Swagger 2.0), a numeric exclusive bound (3.1), and a `default` outside `Int`, whose message names the default. An array's `items` shape is read, so `[Int]` over int64 items is a finding too. An argument's out-of-range default clears when its doc comment carries `default: unbounded` (schema-authoring.md § Argument constraints), because the router never sends it. When the doc comment states the number (`default 9223372036854775807`, the older spelling), the finding stays an error, quotes that clause and gives the replacement with the number filled in; if `default: unbounded` is already there too, it says to delete the numeric clause, and the finding does not clear until it is gone. `default: no upper bound` is treated the same way, and every legacy clause in the doc comment is named. A leaf's default and any bound do not clear. Exempt: an `ID`-typed slot, a leaf the connector already maps (any `->method`), and a pagination `size_param` (`page-limit-not-int` owns it) | GraphQL `Int` is signed 32-bit. Past 2^31 the router nulls the field and reports a coercion error instead of returning the number — and no offline layer sees it, because the recorded fixtures all carry small values |

Declared bounds beat the format hint in both directions: an `int64` property
whose `minimum` and `maximum` both sit inside `Int` is not a finding, and a
bound outside `Int` is one whatever the format says. That is what keeps
`int-overflow` and `page-limit-not-int` from ever disagreeing about the same
field. There is **no waiver and no doc-comment exemption** — `selection.yaml`'s
`waiver` carries only the conformance statuses (`unchecked`, `unmatched`),
which `lint_waivers` cross-checks against `validate`, and a sentence beside a
field does not change what the router coerces. The one exception is an
argument's `default` (row above), because the router never sends it. The fix is the fix
(schema-authoring.md § Scalar choice); `graphos-factory-core decisions` is where the
reasoning for choosing `ID` over `String` goes.

Two traps come with the fix rather than the defect, and neither is visible to
any layer, because every recorded body carries a number and no recorded body
carries a null:

- **`->jsonStringify` maps a JSON `null` to the string `"null"`.** Write
  `path->match([null, null], [@, @->jsonStringify])`
  ([connectors-language.md](connectors-language.md) has the measured table).
  `.github/scripts/null-mapping-probe.sh` is the negative control: it asserts
  the guarded form keeps `null` and that the bare form still corrupts it, on a
  throwaway workspace, in the CI `stack` job.
- **A pilot's `apiResponseBody` is also a conformance body.** `validate`
  checks every one against the spec, so a hand-written probe body cannot carry
  a shape the spec forbids: gitea declares all eighteen converted properties
  non-nullable, and null-body cases in `tests/gitea.connector.yaml` made
  `validate` report `23 bodies conform, 2 do not` and exit 1. That is why the
  null probe lives in `.github/scripts/`, on a workspace nobody validates.

One more is an **error** because it reads the request the connector sends:

| Rule | What it wants | Why |
|---|---|---|
| `sparse-fieldsets` | a selected GET whose operation takes a string sparse-fieldsets query parameter (`workspace.yaml` `sparse_fieldsets.param`, default `fields`) declares it as a `String` argument whose default is the derived fields list, or the literal a resolved decision (or a current finding) naming the operation records as a backtick span, and forwards it as `$args.<param>` in `queryParams`. A non-string parameter is an `info` finding | a hard-coded or stale fields list silently drops the fields the schema exposes, and every layer still passes (schema-authoring.md § Sparse fieldsets) |

The wider rule that `pagination-bounds-undocumented` and
`pagination-bounds-unknown` specialise — every argument whose inventory entry
carries `default`, `minimum`, `maximum` or `enum` documents it, and no
argument carries an executable `= literal` default
(schema-authoring.md § Argument constraints) — has no rule id of its own. Those
two check a page-size argument's doc comment and nothing else. The only rule
that reads an SDL `= literal` is `sparse-fieldsets`, and only on the one
argument it governs, whose default is the exception to the ban.
Review both halves by reading the schema. (The
other three pagination and copy-state rules are not specialisations of it:
`list-completion-missing` and `copy-state-undocumented` read descriptions, and
`page-limit-not-int` reads an argument's type.)

One more treats a name as evidence rather than reading behavior:

| Rule | What it wants | Why |
|---|---|---|
| `secret-field-exposed` | a **response** object field whose name marks it a credential — `token`/`secret`/`password`/`passcode`/`credential(s)` bare or as a compound's last word, and a compound `*_token`/`*_key` only when the word right before it is itself credential-shaped (`apiKey`, `accessToken`; a bare `key`, or `syncToken`/`incidentKey`, is not) — is excluded via `selection.yaml`'s `fields.exclude`, or covered by a resolved `secret_fields` decision whose choices are expose and exclude (`graphos-factory-core decisions add . --question … --choice … --resolved … --secret-field 'Type.field|disposition|reason'`, disposition expose or exclude) | a field this shape returning to every caller who can query the type is worth a second look before it ships; a warning, because the field's own name is the only evidence — the rule never inspects a value |

It is a warning, not an error, and inspects **names**, never values or the
spec's declared format: measured across the three pilots and 25 other
workspaces, zero response properties declare
`format: password`, so the rule does not read `format` at all: a response
field declared `format: password` under a harmless name is yours to catch. Only object-type fields are read:
`Query`/`Mutation`'s own "fields" are operation names, not response data, and
an `input` declaration's fields are arguments — so a create mutation's own
`password` argument never fires on its own, and fires only if a response type
echoes the same name back. Two measured false positives shaped the final
rule, recorded rather than silently avoided: an unqualified "any compound
ending in key" fired on PagerDuty's `incidentKey` (a deduplication key), and
an unqualified "any compound ending in token" fired on 40 of one ATS
vendor's list-response types' `syncToken` (a pagination cursor). Both now require the
word immediately before them to be credential-shaped when compound; a bare
`token` (and `secret`/`password`/`passcode`/`credential(s)`, bare or compound)
still fires unconditionally.

**No layer runs an OAuth flow.** Every layer here renders
`{{AUTH_EXPR}}` from one env var, so an OAuth configuration a workspace
carries is checked for structure only: report such a workspace as validated on its shared-credential path, with that
configuration unverified — never as validated end to end.

## What the conformance oracle could not judge

`graphos-factory-core validate` never reports a body it did not compare as a
pass. Its status says why, and the two causes are treated differently:

| Status | Meaning | Effect |
|---|---|---|
| `unchecked` | nothing to compare against: the spec documents no shape for that operation and status (an error body, an undocumented request body), or the stub has no JSON body (204, redirect) | reported with its reason; per-operation evidence says `unchecked`, not `n/a` |
| `unmatched` | the oracle could not even find the operation or read the body: a fixture or unit entry names a method + path no inventory operation has, or one several operations match equally that nothing declares (below), the suite is not readable YAML, a body is not JSON | `validate` exits 1 and the conformance layer fails |
| `waived` | an `unchecked` or `unmatched` body the engineer has accepted | counted separately; lint keeps the waiver honest |

An `unmatched` result is a test asserting a request the spec does not
describe. Fix the matcher (a wrong path), the reader (a base path it did not
strip — `validate` strips the spec's server paths and `template.yaml`'s
`BASE_URL.test_default` path from unit-suite URLs), or the spec: an endpoint
the vendor exposes but does not document is added through a pinned-source
patch (`codify --source`), which also makes the inventory and the
selection see it. Silence was the Mailchimp finding: a base URL with a path
left every unit body `unchecked` and the layer looked green.

**Which operation a body is judged against.** A stub's or unit entry's
request path is matched against every operation's template, and the most
specific wins (`/users/me` over `/users/{id}`). Equally specific templates —
every bare `/{id}` node of a Graph-style API — are settled by what the test
declares. A stub declares only through its own file name: the case it is
named after declares by its name (`<case>` being `snake(graphql.name)`, or
`<case>_minimal`) and by the root field its document
`tests/cases/<case>.graphql` selects — so a variant named for its own case
(`campaign_not_found.json` beside `campaign_not_found.graphql`) is judged
against the operation that case calls. `x-cases` counts only when it lists
the stub's own name, as `fixtures` writes a stub it shares with further
cases. A unit entry declares by its `target`:
`Query.<field_prefix>_<graphql.name>`, or for an entity the type an
`entity: true` entry's root field returns. Without a declaration the body is
`unmatched`, its reason naming the candidates; it is never judged against
whichever operation came first, which is how a Campaign body with a
malformed `daily_budget` used to pass against Ad's shape.

A stub tagged into a case for one of its **nested** requests
(`ad_campaign.json`, `x-cases: ["ad"]`, answering the Campaign fetch beneath
`meta_ad`) declares nothing: the root field the case selects is not the
operation that stub answers, and reading it that way judged a Campaign body
against Ad's shape, where its defect passed. On a tied path such a stub is
`unmatched`, as are a stub whose case document selects both tied fields and
one `fixtures` writes for an `unreachable` recording
(`unreachable_<sub>_<n>.json`, `x-cases: []`, rewritten under that name).
Waive them: `codify --waive tests/fixtures/mappings/<stub>.json --status
unmatched --reason R`. The `unmatched` reason says so.

**Waivers.** "This gap is fine; ignore it from now on" is recorded, never
implied. `graphos-factory-core codify --waive TARGET --status unchecked|unmatched
--reason R [--context TEXT] [--decision D-id] [--until TEXT] [--expires YYYY-MM-DD]` writes
a `waivers:` entry in `selection.yaml` and no decision: `reason` carries the
why, `context` the prose, and `--decision` only attaches a real decision;
TARGET is one body
(`tests/fixtures/mappings/<case>.json` or
`tests/<suite>.connector.yaml#<entry name>`) or an operation key (every such
body of that operation). It refuses a gap `validate` does not currently
report. `status` is part of the waiver, so accepting an undocumented 404
body never hides a later unmatched URL on the same fixture. Lint reports a
waiver that matches nothing any more (`waiver-unused` — the gap closed, or
the target is misspelled) or has
expired (`waiver-expired`). A waiver is the right answer for an error body
the vendor does not document and the fixture recorded live; it is never the
answer to a body the oracle *rejected* — that is a fix or a spec patch.

**The decision log's own rules.** `override-undecided` and
`waiver-undecided` are retired: an override's or waiver's `decision:` is
optional, and `reason` is the required field that carries the why. One rule
arrives, `decision-without-alternative` (a warning): a `decisions.json`
record with neither a `question` nor `choices` — what `decisions migrate
--split` leaves standing when a record kept an `editorial` omit but never
named its alternative. Give the call its question and choices: a record
is never edited in place, so re-record it with them (`decisions add`) and
`decisions supersede` the old one.

## When the conformance oracle disagrees with your fixture

It will, and that is the point: fixtures are written by the same agent that
wrote the schema. A `null is not allowed` finding means the spec says
non-nullable and you wrote null. Three legitimate outcomes, in order:

1. you have a recorded sample proving the API sends null → FACTORY PATCH
   the spec (`nullable: true`) with the sample as evidence;
2. you only suspect it → omit the key from the fixture (GraphQL yields null
   either way), keep the schema field nullable, and record an open question
   in `memory.md` for the first live run;
3. the fixture was simply wrong → fix the fixture.

Never loosen the oracle to make a body pass.

**When rover and the oracle disagree about an absent key.** `rover connector
test` fails a case whose payload lacks a selected key, while the oracle
(inferred from recordings) rejects `null` for a key the API never sends as
null — so a body the API returns *without* `error` cannot be represented
honestly in a unit payload. Resolution, in order: use the type's empty value
(`""`, `[]`) and say so in the suite header; if no honest value exists (a
refused request whose body omits the id), drop the unit entry and prove that
path at e2e and live, where the recorded body is used as-is.
