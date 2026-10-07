# Cross-connector lessons

Vendor-independent things learned the hard way. **Append to this file when
you learn something that would apply to the next service too**; anything
specific to one vendor belongs in that workspace's `memory.md` instead.

Format: a heading naming the lesson, two or three lines of what happened,
and the rule it produced.

---

## Regeneration destroys iteration

A deterministic generator preserved hand edits only inside five
`# === CUSTOM ... ===` regions. Everything else was overwritten on every run, so engineers stopped
editing the schema and started editing the generator — which is how a
generator ends up carrying per-vendor special cases.

**Rule:** after the first commit, an `apply` is a reconciliation of the
delta, never a re-emission of the file. A hand edit is detected against
`applied.lock.yaml` and codified (`overrides`, with a reason and assertions)
before the next apply; it is never silently corrected.

## Policy that is inferred is policy nobody reviewed

Deriving an authorization decision from schema shape (grep for
`type Mutation` → enable writes) reads as a safe default, but no human ever
approved it and it moves silently when the schema moves: the decision flips
with no diff for anyone to review, while every check stays green.

**Rule:** decisions with a blast radius live in a committed file where they
appear in a diff — `selection.yaml`, `decisions.json`, a target's own config — not in
a heuristic.

## Config surfaces need executed verification too

When every layer of schema testing stops at the router, a configuration file
generated for something downstream has no executed coverage and can ship
broken with every check green.

**Rule:** anything generated that something else consumes — router config,
generated client or tool config, what a target hands on — needs a test that executes it, not one that
inspects it.

## Untyped beats unreachable

A typed guess that covers four of nine payload keys makes the other five
unreachable through the schema, and no test will ever report it. An opaque
JSON scalar is worse to consume and strictly more honest.

**Rule:** when a shape cannot be typed honestly, emit the JSON scalar *with
a documented reason*. Never narrow a payload silently.

## Green is not the same as proven

A passing suite is not evidence that tests exist; a passing case is not
evidence about the field you changed; a passing negative assertion is not
evidence unless something else could have accepted the input.

**Rule:** name what each green result actually proves before quoting it. If
a layer was skipped, say `skipped` and why — `evidence/latest.json` exists
so that this is mechanical.

## A toolchain pin is part of the test

The same schema composed clean at federation 2.12.0 and failed at 2.15.2
with a named build error the older composer masked behind an unrelated
parse failure.

**Rule:** quote the federation and connect pins with any compose result, and
prefer the strictest pin in active use before concluding a bug is gone.

## The prefix is derived, not chosen

`rover supergraph compose` derives `join__Graph` from the subgraph name by
uppercasing and replacing hyphens. A camelCase `@source` name composes fine
and leaves the subgraph and supergraph disagreeing about the service's name.

**Rule:** directory `foo-bar` → source `foo_bar` → types `Foo_Bar_*` →
fields `foo_bar_*`. Mechanically, every time.

## Specs are evidence, not truth

Fixtures derived from a spec are self-consistent with a *wrong* spec, so
every layer agrees and the API still rejects the request. Only real traffic
closes that gap.

**Rule:** patch the bundled spec in place with a `FACTORY PATCH` marker,
enumerate the patch in `sources.lock.yaml`, and attach the live evidence
that justified it. A patch without evidence is a guess.

## Read a diff as a multiset, not as a story

Rendered diffs realign lines: a pure deduplication showed as "six removed,
four added" where the four were alignment artifacts. Two people read the
same diff and reached confidently opposite conclusions.

**Rule:** when a change should only remove, assert the new file's lines are
a sub-multiset of the old. rover's assertion output prints `-` for
*expected* and `+` for *actual* — reading it the other way inverts the
result.

## The oracle should disagree with you

The first conformance run on the pagerduty pilot rejected 15 of 34 test
bodies — every one a null the fixture author (the same agent that wrote the
schema) had assumed was fine. None was a bug in the oracle. Half were
probably right about the API and wrong about the spec; without a recorded
sample there was no way to tell, which is exactly the gap a probe closes.

**Rule:** a green e2e suite over fixtures you wrote proves self-consistency,
not correctness. Run conformance before calling anything validated, and
treat its findings as questions for a live run, never as noise to silence.

## Scalar arguments make writes testable

The old generator's writes took input objects, which the unit framework cannot
express, so no generated artifact ever asserted a write's outbound body — and
its `type: "INCIDENT"` bug shipped. The pilot's writes take flat scalar
arguments, and both bodies (full and minimal) are asserted at unit and e2e.

**Rule:** when the wire body is a handful of fields plus constants, prefer
scalar arguments and let the connector assemble the body. The caller never
learns the discriminators, and the unit layer can see the body.

## Read a rover diff as `-` expected, `+` actual — and check the file, not the memory

Two readings of the same listOnCalls URI diff reached opposite conclusions
about `%3A` encoding; the truth was a third thing (the expectation is
URL-normalised, so neither spelling can match). Both wrong readings came
from reasoning about which line was which instead of changing one input
and re-running.

**Rule:** when a diff is ambiguous, change exactly one thing and run again.
One controlled run beats three confident readings.

## A base URL with a path breaks every layer that compares paths

`https://deckofcardsapi.com/api` was the first base URL with a path. The
router's `override_url` replaces the whole base, so WireMock saw `/deck/new/`
while stubs derived from recordings said `/api/deck/new/` — 23 of 23 e2e
cases "matched no stub". Then the conformance layer left 16 unit bodies
`unchecked` because their asserted URLs carried `/api` and inventory paths
did not. Two layers, one cause, found one at a time.

**Rule:** every comparison of a recorded or asserted URL against an
operation path strips the base URL's path first (`graphos-factory-core fixtures`,
`graphos-factory-core validate`). When adding a layer that compares paths, test it with a
base URL that has one.

The same outcome came back from a different cause: Gitea's Swagger
`basePath` is a template (`{{.SwaggerAppSubUrl}}/api/v1`), not a URL, so the
inventory records no server and there was no base path *to* strip; eleven
unit bodies went `unchecked` — silently, because `unchecked` did not fail
anything. `validate` now also strips the path of
`template.yaml`'s `BASE_URL.test_default`, which is the URL the unit suite
really builds; could-not-match is a failure (`unmatched`).

A third layer, from a third arrangement: Confluence's inventory server is
`…/wiki/api/v2`, its `BASE_URL` is `…/wiki`, and its connectors write
`/api/v2/...`. `reconcile` paired 0 of 211 connectors and reported them as
211 separate unmatched entries. It now stops at a total mismatch, prints the
server URL, `BASE_URL`, the target's default base URL and a connector
path, and exits 2. The fix is on the workspace side: keep the
prefix on one side only.

## The oracle must see what the reader saw

Swagger 2.0 and OpenAPI 3.0 ignore siblings of `$ref`, and so did the
reader — dropping go-swagger's `x-nullable: true` beside `$ref: Milestone`,
so the oracle rejected the null the API sends. And a response that *is* the
array (`[Issue]`, no envelope) was walked at one depth by `reconcile`'s path
resolver and another by its expectation, so every field read as unmapped.
Both were found by the first pilot whose spec had those shapes, not by
reading the code.

**Rule:** a new pilot is a test of the readers. When a spec shape appears
for the first time (a bare-array response, `nullable` beside `$ref`, a
templated `basePath`), expect an instrument to be wrong about it, and turn
the finding into a crate test before the workspace ships.

## A vocabulary belongs to the API, not to the sample that happened to show it

An enum closed over the two recordings of one operation rejected the third
value the API sends. Grouping suit and value paths in one hint then leaked
suits into values.

**Rule:** close enums over every sample at the hinted paths; group only paths
that genuinely share a vocabulary; and record a complete vocabulary on
purpose (draw the whole deck) before trusting any closed set.

## Probe the failures

Every interesting discrepancy on the no-spec pilot was in an error path: a
200 where the source says 400, a 500 with HTML where it says 404 JSON, an
unknown pile answered as a 200 with the pile simply absent. None of the
happy-path probes would have shaped the schema; the failures added
`success`/`error` to every result, made a key nullable, and justified the
error-mapping fallback.

**Rule:** a discovery pass is not done until it has recorded at least one
failure per resource — missing id, out-of-range argument, forbidden action.

## Drift no layer compares is drift nobody sees

Pilot A was green on every layer for a whole phase while its selection said
"all fields" for five operations whose connectors, correctly, mapped fewer.
Compose, unit, e2e, conformance and lint each compare the schema to
something — rover, a fixture, a spec, the contract — but none of them
compares it to `selection.yaml`. The first `graphos-factory-core reconcile` run did, and the
fix was to the selection, not the schema.

**Rule:** the artifact and the intent are two files; a layer that reads
both must exist and run on every apply, before and after the edit. Its
"clean" is the only statement that the schema still means what the user
chose.

## A validation run cannot judge its own previous output

`graphos-factory-core lint` checks that every selected operation appears in
`evidence/latest.json`; `graphos-factory-core evidence` runs lint *before* rewriting that
file. The first apply that added an operation failed its own evidence run
on the previous run's operation list — a self-inflicted red that looked
like a coverage gap.

**Rule:** when a runner both produces a file and invokes a checker of that
file, the checker must skip the file during the run (`--skip-evidence`) and
check it standalone afterwards. Name the flag after the reason so nobody
reaches for it elsewhere.

## Report, then edit, then report again

The reconcile report before the apply is the plan (three operations, by
name); the report after is the proof (clean, and the two customized
operations byte-for-byte). The `git diff` of the `apply:` commit is the
human-readable cross-check — four hunks, none inside a hand-edited field.
Without the second run, "I only touched those three" is a claim; with it,
it is an assertion a script made.

**Rule:** an `apply:` quotes both runs. A failed override assertion, a
`MODIFIED` pinned override, or a `changed since HEAD` span outside the delta
fails the apply regardless of how green the other layers are.

## A fence is a lock; an assertion is a contract

An early `customized:` list protected two hand-edited operations by
freezing their bytes. That answered "don't overwrite my edit" and created
three new problems: an edit nobody listed was invisible until the agent
"fixed" it; a listed operation could never be touched again, even when
the selection changed for it; and the list said nothing about *why*, so a
later agent had to guess. Its replacement is a per-span hash of
the schema as last applied (detection), `overrides` that carry a reason,
a decision and assertions about what must stay true (codification), and
`codify` to write all three at once.

**Rule:** record the intent, not the text. An assertion the agent can
check (`contains`, `tag`, `arg`, …) lets it keep editing the span; a byte
pin is a last resort and lint says so. The reason goes on the override
itself (`reason`, and `context` for the prose), because that is what the
next agent reads before touching the span. `codify` once also appended a
decision per run; it no longer does, since nothing read those records
back and they buried the real decisions (69 of Asana's 71 records).

## A supported API description may not contain the customer's field definitions

A generic query endpoint can be fully documented while the requested metrics,
custom objects, or content types live in tenant metadata. Technical support
and passing spec-derived fixtures do not prove customer-specific usefulness.

**Rule:** assess generic versus specialized intent before authoring. Reuse
supplied scope, discover authorized metadata, and persist missing inputs with
their resolution path. Separate build inputs from live-test access. See
[`customer-context.md`](customer-context.md).

## Capture local artifact provenance before parsing

A local metadata file can keep the same parsed value after a copier removes
its final LF. The raw SHA-256 already detects that change. Controlled capture
also preserves the source file, scope, lineage and refresh date.

**Rule:** capture only authorized, non-secret artifacts that are safe to commit
to the workspace. Calculate the hash and byte count before parsing. Mark
derived and transcribed artifacts, and link them to their raw inputs.

## Changing page size mid-iteration skips records

An agent fetched page 0 at default size 5, requested limit 100, got rejected,
retried page 1 at size 20, permanently skipping records 5-19.

**Rule:** after a page-size change restart at index 0; state the offset formula
in the argument description.

## First page treated as whole collection

Several agent executions read a successful first page of a paginated list,
acted on the records, and marked the task complete. Inspected failures were
missing records that existed on later pages, across four different record
types — the agent stopped after page 0 without iterating to completion.

**Rule:** paginated list descriptions must say the result is one page, not the
complete collection, and give the stop condition (empty or short page, or the
completion signal the inventory names—`total_items_property`,
`cursor_root_properties`, or `pagination.response` cursor path).

## Copied object lost its behavior state

An agent copied a note by reading it and creating a new one, but omitted
`pinned` from the create body. The API defaulted `pinned: false`, and the
state was silently lost. The e2e case passed because its matcher ignored extra
elements.

**Rule:** copy equals read plus explicit field carry-over; omitted optional
fields take provider defaults, not the source object's values. Copy-flow stubs
must demand the preserved field. See schema-authoring.md and testing.md.

## An int64 the schema typed Int

Gitea declares 155 numeric properties `format: int64`. The pilot's schema
typed 18 of the selected ones `Int`, and every layer was green: compose
type-checks the selection, not the range; the unit and e2e layers replay
recorded bodies whose counters are all 0 or 1; the conformance oracle compares
the body against the spec, where `int64` is what the spec *says*. Nothing
below the production router would ever have seen it — and there the failure is
a coercion error and a `null`, on a field the caller had every reason to trust.

The same spec is also the evidence for the fix: the nine id fields the pilot
already typed `ID` are `format: int64` too, and the rule passes over every one
of them.

The fix has its own version of the same trap. `size: size->jsonStringify`
turns a JSON `null` into the four-character string `"null"` and a nullable
`String` field carries it without complaint — the silent wrong answer again,
one layer further on. `size: size->match([null, null], [@, @->jsonStringify])`
hands back `null`. Nothing in the stack catches the difference, because every
recorded body carries a number; `.github/scripts/null-mapping-probe.sh` is a
standalone negative control that does.

And every assertion over a converted field has to be restated. `.number >= 2`
in a jq predicate does not fail when `number` becomes a string — it compares
as a string and is true for every value the API will ever send. `tonumber`
first.

**Rule:** `Int` is 32-bit. An `int64`/`uint64`/`uint32` slot is `ID` when it
is an argument that identifies something, and otherwise `String` mapped with
`->match([null, null], [@, @->jsonStringify])`. A declared `minimum`/`maximum`
inside `Int` settles it; a format hint alone does not, and a doc comment never
does. See schema-authoring.md § Scalar choice.

## Published SDL default read as the value to use

A generated schema published the provider's default as an executable SDL
default (`pageLimit: Int = 5`). Consuming agents read it as the value to use
rather than as the value the API assumes, and kept requesting pages of 5
against a maximum of 20 — four times the pagination calls the work needed.
Removing the default without documenting it was worse: task completion fell
from 89.5 to 54.4, because the published default had been the only page-size
signal in the schema.

**Rule:** never write `= literal` on an argument; state the provider's
`default`, `minimum`, `maximum` and `enum` in the argument's doc comment
instead. The two halves ship together — suppressing the default without the
prose removes the caller's only signal. See schema-authoring.md § Argument
constraints.

## Flat object names in a Returns line read as leaves

A Returns line listed a text message's `sender, receiver` as bare names
beside the scalars, and nothing on the line said they were objects. In one
AppWorld run that flat pair produced selection errors in 13 tasks (16 Sep
bundle: 1), and flat reference types invite guesses such as `first_name`.
Across that run, 75 of 364 Returns lines named 118 object fields with no
nesting marker. The line existed to remove an introspection turn and had put
a guess in its place.

**Rule:** an object-typed entry in a Returns line renders one level deep —
`teams { id, type, summary, self, htmlUrl }`, the nested type's fields in
declaration order, capped at 6 then `(+N more)` — so a reference type reads
as one and its real fields are on the line. One level only: an object inside
the braces is a bare name. See schema-authoring.md § Returned field names.

The one-level stop left the same trap one level down: splitwise's `shares {
debtor, debtAmount }` and spotify's `songs { …, artists }` named objects bare
inside the braces, and the 25 Sep bundle's 11 bare-selection errors came from
those spans. A second-level object whose type has at most 6 leaf fields now
gets its own braces, and `returns-line-nesting` checks the line.

## A closed vocabulary typed String

The AppWorld LLM arm (run 20260922) typed amazon's `duration`
(`monthly | yearly`) and file_system's `entry_type`
(`all | files | directories`) as `String`, with no recorded decision, and
nothing noticed: compose, the unit layer and the e2e layer all accept a string
where the API sends one, and `wire-enum-drift` reads only slots that *are*
enums. The consumer — an agent choosing an argument value — was left to guess
a vocabulary the spec states in full.

**Rule:** a spec `enum` of two or more values, every one a valid GraphQL
name, is a GraphQL enum in wire casing, or the reason it is not is a resolved
decision whose `affects` names the slot; `closed-enum-as-string`
warns until one of the two is true. It is quiet on its own for a one-value
constant and for a shared field whose reaching spec properties do not all
declare the enum — pagerduty's `type` fields are both — because a decision
there would be standing in for a rule; a reach the spec does not document
counts as declaring none. The smoke that found this could not see it at first
— the next lesson. See schema-authoring.md § Enums and testing.md.

## A documentation surface with no rule fills with vendor text

An authoring run had a rule for an argument's constraint clause,
a rule for object-field descriptions, and none for the rest of an
argument's doc comment. It produced 1,565 argument doc comments where the
previous run had produced 0: 691 verbatim OpenAPI parameter descriptions, 367
a per-argument "requires access_token" sentence copied from the authoring
brief, 308 the constraint clause and 140 the pagination wording — and the
schemas' description text grew from 28 KB to 229 KB. Nothing asked for the
first two; nothing forbade them either, and an agent fills a silent surface
with the text in front of it. (AppWorld run, LLM arm,
2026-09-22 — fix-list finding D1.)

**Rule:** an argument's doc comment is at most the source description cut to
one sentence (opt-in per service, recorded in `decisions.json`), the
constraint clause (schema-authoring.md), and § Pagination's wording on a page-size or page-index
argument — nothing else, and never the argument's type or requiredness, which
the SDL already states. A credential argument gets no per-argument sentence
about where the credential comes from. See schema-authoring.md § Argument
descriptions.

## A reader that assumed the layout

Three spec-facing rules — `wire-enum-drift`, `int-overflow`,
`closed-enum-as-string` — shared one reading of a connector's `queryParams`
and `body`, and it matched `key: $args.arg` at the start of a line. Every
pilot writes one pair per line, so every test and every pilot run was green.
The AppWorld LLM arm writes every block on one line: 275 of 275 in the 15 Sep
snapshot, 197 with two or more pairs, and the rules read the first pair of
such a `queryParams` and nothing of such a `body`. Measured on scratch copies
with the two G5 slots retyped to `String`: 0 findings from all three rules;
the same two blocks reflowed to one pair per line: 1 finding each. No layer
said so — compose accepts both layouts, the unit and e2e layers never read
the rules' inputs, and a rule that finds nothing looks like a clean schema.
The readers were changed to tokenise a block the way the mapping language does
(whitespace separates entries; brackets and string literals do not), and the
same slots now fire as written — `amazon.graphql:234 … argument duration …
closed enum of monthly, yearly` and `file-system.graphql:39 … argument
entry_type … all, files, directories` — and `scaffold` on the amazon write
drops its "not a flat list" note. Every multi-line block the pilots and the
suite write reads as before: the whole suite and `scaffold --dry-run` on the
three pilots are byte-identical across the change.

**Rule:** a reader of authored text takes the grammar's word for what
separates things, never the house style's. When a rule is quiet on a
workspace written in a style the pilots do not use, prove the rule can see
the input before believing the schema is clean: put a known defect in that
style and watch it fire.

## An inline error shape read as no shape at all

The inventory kept an error body's shape only when the spec pointed at it
with `$ref`; a body written inline (`{"type": "object", "properties":
{"message": ...}}` right there in the response) got `shape_ref: null` —
same information, different spelling, and the second form vanished. Every
one of AppWorld's Venmo (162) and Splitwise (195) error entries was written
inline, and both agent arms guessed `.detail` — FastAPI's default, not this
API's — against a spec that documented `{"message": ...}` on 401/422/409.

**Rule:** an inline schema is still a schema; register it under a
synthesized name the same way a fallback `{Op}Response`/`{Op}Request`
shape is, and take an error's message path from the shape the inventory
actually resolved, never from another API's convention. See
schema-authoring.md § Errors.

## A list argument on a plain query key goes out as the key repeated

**Seen on:** Databricks, connect v0.3, Apollo Router 2.17.

A `queryParams` line that is exactly `key: $args.list` sends
`key=a&key=b`, one pair per element, whether or not the key ends in `[]`.
The Databricks SDK sends the same, so the API expects it. scaffold used to
assert `key=a,b` and call it a guess. Three model-store cases then failed
e2e with "matched no loaded stub".

**Rule:** a plain list key is asserted with `hasExactly`, one matcher per
element. Only a line in the mapping language (`->joinNotNull(",")`) sends
one joined value, and only there is `equalTo "a,b"` right.

## A relationship hint that points at the record's own id is worse than no hint

**Seen on:** AppWorld Spotify and Amazon (the benchmark harness's
relationship-field script), the gitea pilot
(D-0013), binary 0.5.1–0.5.14.

The first `candidate_entity_link` heuristic excluded only the property's own
operation and then took the first path parameter with a matching name in
document order. On Spotify it found 6 of the 36 relationships a hand-wired
answer key contained and emitted 6 more that were noise: 5 on the record's
own id, 2 of those pointing at a DELETE. It never looked inside a list
response, where 24 of the 36 lived. gitea's 66 hints were all declined.

**Rule:** a foreign-key hint names a canonical GET-by-id target — `GET`, one
trailing path parameter, a response shape, no other required parameter
outside the headers (a required header is the credential) — never an
operation that returns the host's own shape, never a property named after
one of the host shape's own trailing path parameters, and never a bare
`id`/`name` parameter, and never an operation whose response is not one
record carrying the key its parameter names. Look wherever a response reaches, a list's
`items.$ref` component included: on a components-based spec that is where
the list items' foreign keys are (gitea: 5 of its 8 hints). Measure a
heuristic against a hand-wired answer key before trusting its count; a count
that goes down is not a heuristic that got better until the targets are
checked one by one.

## A list item and its detail read given one type cannot link to each other

**Seen on:** a copy of the AppWorld Spotify workspace with its 36 drafted
links confirmed, binary 0.5.24 (`links apply --dry-run`).

Three of the 36 were refused for reasons the heuristic cannot see. Where a
list item and its detail read are given one GraphQL type, the by-id
operation returns the host type itself and the link is `self` (2 of 36).
Where the by-id read's selection selects back into the host — the album read
copied onto `Spotify_Track.album` selects `songs { … }`, which are
`Spotify_Track`s — the link is `circular`, and pasting it anyway fails
composition with `CIRCULAR_REFERENCE` on `Spotify_Track.album.songs`.

**Rule:** before confirming a link, compare the by-id operation's return type
and selection with the host. The same type is `self`: decline the link
(`include: false` with a `reason`) or split the list item and the detail read
into two types. A by-id selection that reaches back into the host (`album {
songs { … } }`) is `circular`: decline the link, or split a type
(below). Excluding the field that selects back (`fields.exclude`) composes
but takes it from every reader of the shared type.

## A child cannot link to its own parent through one shared type

**Seen on:** copies of the AppWorld amazon and spotify workspaces, rover
0.41.0 with supergraph plugin 2.15.2.

All 5 `circular` refusals were correct. On amazon 4 of them were
`[]>variations[]>product_id` onto `Amazon_Product_Variation.product`: the
by-id product read selects `variations`, which are the host. Pasted with
the printed null guard, composition failed `GRAPH_QL_ERROR: No matching
shape found for selection`. Without the guard it failed
`CIRCULAR_REFERENCE`. Trimming the copied selection failed
`SATISFIABILITY_ERROR`. `@shareable` changed nothing. The entity form
failed both ways. Excluding `variations` would have removed the host.
Splitting the target (`product: Amazon_VariationProduct`, whose
`variations` is a new link-free type) composed. Live, variation 198
resolved product 198, the same as curl.

**Rule:** a link from a child to its own parent needs its own target type.
A link from a type reached through a second parent needs its own host type
(spotify: `Spotify_PlaylistDetails.songs: [Spotify_PlaylistTrack]`). Either
split is a recorded decision that overrides the shared-type one, pasted by
hand, with its own unit, e2e, null-parent and live cases
(connectors-language.md § Relationship fields).

## A GET keyed by an email returned a balance, not a person

**Seen on:** AppWorld splitwise, binary 0.5.47.

`get:/splitwise/balance/person/{email}` is shaped like a GET-by-id, so every
`email` property (35 of 56 hints) pointed at it, and `selection draft
--links` proposed a field named `person`. The response is the caller's
balance with that person — `direction`, `total`, `breakdown`, no `email` —
and on the caller's own email it answers 422 "You cannot check your balance
with yourself", so `Splitwise_User.person` could never resolve.

**Rule:** a link target is a read of the record its key names: its response
carries that key (same name, a name ending with it, or the record's `id`).
A read *about* the key — a balance, a count, a permission check — is not a
target, however its path is shaped. `inventory links` lists every GET-by-id
it refused and why; a relationship you still want through one is authored
by hand and reported as not validated. A list item linking to its own
detail read by the same id is not a self-link while the two have different
types — the detail carries fields the summary lacks; it is `self` only when
one type serves both.

## A hint's target can be a collection the key owns, not the key's record

**Seen on:** the gitea pilot, binary 0.5.45 (`inventory links`,
`selection draft --links`), 29 Sep 2026.

`RepositoryMeta > owner` — the owner's login on every issue — was hinted at
`get:/packages/{owner}` (`list_context: true`): a GET with one trailing path
parameter and a response shape, so it passes every test of the
link rule, and it lists the owner's packages. The owner's own record is
`get:/users/{username}`. The same pilot's other 7 hints were none of them
usable as drafted: 6 sit on shapes no included operation returns, and the
1 draft (`Organization > username`) is reached only through an excluded
property.

**Rule:** before confirming a link, read the target operation's summary and
response type: it must return the record the key names, one of it. A
`list_context` target that returns a collection *owned by* the key is no
relationship — write the entry against the record's by-id read (`operation`
and `parameter` are yours to set; lint checks only that the operation is an
included GET), or decline it. Never follow connectors-language's `$batch`
advice for such a hint.

Since 0.5.51 `inventory links` refuses both reads on this
pilot: `get:/packages/{owner}` because its response is a list, and
`get:/users/{username}` because Gitea's User spells its key `login`, so the
pilot has 0 facts. A relationship the rule refuses can still be a confirmed
judgement: lint and reconcile hold a `links:` entry to the included
operations, not to a fact, and say nothing when none backs it. Record why
in a decision (gitea's D-0018), and count it validated only through its own
hand-written unit, e2e (with the null-parent case for a nullable key) and
live cases.

## An auth rule in the schema description never reached the consumer

**Seen on:** AppWorld, 24–25 Sep 2026.

The composed supergraph keeps one schema description, so an app's auth rule
written there was invisible for 8 of the 9 apps. The login docs said only the
transport, and agents logged in with the email as username (Sonnet, 21 tasks)
or called operations with made-up tokens (Opus 4.6, 11 calls).

**Rule:** state the credential rule on the minting root field's doc comment,
before its Returns line (schema-authoring.md § Descriptions); lint's
`credential-source-undocumented` checks it.

## A bare quoted value flips meaning between connect versions

**Seen on:** Meta Ads, connect v0.3, 2026-09-25 (never committed).

`actionType: "action.type"` reads the property `action.type` at v0.3 and is
the string literal `"action.type"` at v0.4 ([mapping-language.md](mapping-language.md)).
Neither version errors. `source-coverage` reads the bare form as a literal,
which is right at v0.4, so at v0.3 it reports a field the connector does map
as unaccounted.

**Rule:** write a property whose name needs quoting as `$."action.type"`, and
a literal as `$("…")`. Both mean the same at every version.

## A null foreign key still sends the GET

**Seen on:** AppWorld Spotify and Splitwise, 2026-09-29.

A relationship field keyed by `{$this.albumId}` fired for every parent,
including the ones whose `albumId` was null: the router sent `GET
/spotify/albums/` and AppWorld answered 307, so `Spotify_QueueSong.album`
failed with `CONNECTOR_FETCH` for 6 of 7 queue songs and Splitwise's
"Non-Group Entries" row failed every live run. The live cases that passed
had hand-picked non-null parents. Nothing in Connectors skips the request;
a 200 from a list endpoint at that path would have been mapped into a
record instead.

**Rule:** a relationship field on a nullable fk carries the null guard that
`links apply` prints (`isSuccess` and the selection both read
`$($this.<fk> ?! 0)`), and it gets an e2e case with a null-fk parent beside
a set one, the empty-segment GET stubbed the way the API answers it.
`link-null-guard` warns when the guard is missing. The unit layer cannot
carry the null parent: rover's harness renders `/null` and gives the
response side no `$this` (testing.md).

## Two flags quoted into one argument relocked the workspace

**Seen on:** this repo's own pilots, 2026-09-30.

`graphos-factory-core lock <ws> '--check --provenance'` handed `lock` one flag
named `check --provenance`. The shared grammar took any flag it did not
know and the verb never asked for that one, so `lock` ran without `--check`,
wrote `.factory/applied.lock.yaml` and exited 0. `lock --chekc` did the same,
and `selection draft --force --dyr-run` rewrote the selection. A green exit
said nothing about what ran.

**Rule:** every verb declares its flags and dispatch refuses any other with
exit 2 before the verb runs, naming the flag and the accepted set. On exit
2, fix the spelling or split the argument; never drop the flag to get past
it — the flag that was refused is the one that made the call read-only.
## A renamed argument is not found by its wire name

**Seen on:** Granola, `page_size` on the wire, `pageSize` in the
schema.

`pagination-bounds-undocumented` looked the size argument up by the
inventory's parameter name, so every renamed size argument read as
undocumented, however complete its doc comment. **Rule:** an instrument that
starts from a wire name reaches the schema argument through the
connector's own mapping (`queryParams: "page_size: $args.pageSize"`), never
by assuming the two names match. The same goes for an element-wise
translation: `->map(@->match(…))` is `->match` applied to each element, and
reads as the field itself.

## Two branches minted the same decision id

**Seen on:** this repo's pilots and its own design-record numbering, the week of Sep 29.

`decisions add` numbered a new record one past the highest id, so two
branches that each added a decision both wrote `D-0021`. Git conflicted at
the end of the array, someone renumbered and relocked, and a merge that kept
both records went through silently. **Rule:** a new decision or finding is
its own file with a random id (`decisions add` does this); the numbered
records in `decisions.json` are never moved or extended. After a merge, run
`lint`: `decision-overlap` names two decisions added independently about the
same span, and `decisions link . --id <newer> --after|--amends <older>`
records which holds.
