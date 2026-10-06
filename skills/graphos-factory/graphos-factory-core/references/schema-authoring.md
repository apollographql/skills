# Schema authoring

Each policy here is stated once, with its reason, so that thirty operations
authored across three sessions come out looking like one service. When you
depart from one, the departure goes in `decisions.json` as a tracked
decision (`graphos-factory-core decisions`) — that is what makes it
reviewable instead of drift. Applying a policy as written is not a
decision: it is recorded only as a finding (`graphos-factory-core findings add
--cites …`), and only when an instrument reads its `omits` or `affects`
(workspace-contract.md rule 3).

## Envelopes

Most list endpoints wrap their payload: `{ "widgets": [...], "page_info": {...} }`.
Two honest choices:

1. **Flatten** when the envelope carries nothing but the list: the field
   returns `[Widget_Co_Widget]` and the selection descends into the key.
2. **Keep the envelope** when it carries pagination or totals the caller
   needs: the field returns `Widget_Co_WidgetList` with `widgets` and
   `nextCursor`.

Pick one per connector and apply it everywhere. Mixed envelopes are the most
common way a hand-authored connector starts feeling arbitrary.

**Which key the payload sits under is a judgement, and it is written down.**
It lives in `selection.yaml`, per operation, never in `inventory.json`:

```yaml
"get:/lists":
  include: true
  response:
    envelope: lists      # or null: the field returns the whole body
    confirmed: true
```

`graphos-factory-core selection draft` proposes one per included operation and
marks it `confirmed: false`; the same run drafts one `links:` entry per
`candidate_entity_link` fact, `confirmed: false` too (§ Cycles and depth).
**Confirm every block with the user before you apply.** Until you do, `reconcile` names it as still the tool's draft and
lint warns (`response-envelope-unconfirmed`); an operation with no block at
all falls back to the suggestion and `reconcile` says which one it used
(`no-response-envelope`).

The proposal comes from facts the inventory records about the response
shape — `root_property_count`, `array_root_properties`,
`link_root_properties`, `sole_root_property`, `total_items_property`,
`cursor_root_properties`, `root_is_array` — and one rule: a root object earns
an envelope when it has exactly one non-link property, or when exactly one
non-link property is an array *and* a sibling names a total or carries a next
cursor, or when that array has exactly one other non-link property (a status
flag). Anything else is a resource that happens to embed a list, and
flattening to that list would drop the rest of the payload. Read the facts,
not the proposal, when you disagree with it — they are checkable against the
document in seconds. Then write the answer you want into `selection.yaml`;
never "correct" the inventory, which is built, never edited.

`envelope` must name a root property of the operation's response shape:
`reconcile` and lint both refuse one that names nothing (`unknown-envelope`),
because a typo would otherwise flatten the field to a type with no fields.

**`envelope` names the wrapper key for the instruments; it does not decide
flatten or keep.** The instruments read it to find where the payload sits:
reconcile's coverage delta (`envelope_for`), scaffold's stub bodies and the
sparse-fieldsets check.
Whether the field flattens to the list or keeps a wrapper type is the
authoring choice above, made in the schema. pagerduty's `get:/incidents`
records `envelope: "incidents"`, and `pagerduty_listIncidents` still returns
`Pagerduty_IncidentList`, which keeps `limit`, `offset`, `more` and `total`
beside `incidents`. gitea's `searchRepos` does the same with `envelope:
"data"` and `Gitea_RepositorySearchResult { ok, data }`. The same
`envelope` value serves both choices.

**A flattened list needs `$.`.** When the field really returns `[Type]`,
write `$.webhook_endpoints { ... }`, not `webhook_endpoints { ... }`. A single
key with a sub-selection keeps the key ([mapping-language.md § The
single-key rule](mapping-language.md#the-single-key-rule)), so the bare form
selects `{ webhook_endpoints: [...] }` into a list type and compose fails with
`SELECTED_FIELD_NOT_FOUND`.

## Pagination

Connectors have no pagination primitive, and synthesising a Relay
`Connection` buys nothing at the Federation level. Mirror the REST shape:

```graphql
widget_co_listWidgets(limit: Int, cursor: String): Widget_Co_WidgetList
```

with `nextCursor: page_info.next_cursor` in the selection. An inventory
operation that declares a paging parameter carries a `pagination` block
naming the request parameter, the size parameter and the response path
detected for *that* operation; an operation with no block is not paginated; `api.pagination` summarises the whole API — the
style most operations carry, with `counts` per style — and can disagree with
an operation (PagerDuty is offset-paged at the API level, `{cursor: 2,
offset: 16, unknown: 2}`, cursor-paged on its two audit endpoints). Read the
operation's block; `selection.yaml`'s
per-operation `pagination` block is what actually gets exposed. Expose the cursor and the page size and
nothing else — `offset` *and* `cursor` on the same field is a bug the caller
will find at runtime. Graph-API paging (Meta: `{ data[], paging: { cursors:
{ before, after }, next } }`) records `response: paging.cursors.after` and
keeps the URL as `next_url: paging.next`: map `nextCursor` to the cursor, not
to the URL.

A list that takes no paging parameter but returns a link to the next page is
`style: next_link`. Salesforce SOQL's `nextRecordsUrl` and OData's
`@odata.nextLink` are examples. The block records the link's path as
`next_url`. When the document declares exactly one GET that fetches the linked
page (the list's path plus one parameter ending in locator, cursor, token,
page or next, and returning the same link), it records that GET as
`next_operation`, e.g. Salesforce's
`get:/services/data/v67.0/query/{queryLocator}`. Expose the link as `nextUrl`
and the follow-up as its own field taking the locator. The caller pages by
calling the follow-up, not by passing a cursor back to the list. Salesforce's
link is a relative path whose last segment is the locator: from
`/services/data/v67.0/query/01g…-2000` the caller passes
`queryLocator: "01g…-2000"`, and the `nextUrl` doc comment says so. An
absolute link with no `next_operation`, such as OData's `@odata.nextLink`,
has nothing in the inventory to follow it: expose it as `nextUrl` only and
record the missing follow-up with `graphos-factory-core decisions`.

When the inventory's size parameter carries `default` or `maximum`, the
pagination argument's doc comment must state both, e.g. `"Page size (provider
default: 20, maximum: 100)."`. When the source declares no bound, the doc
comment must say so explicitly, e.g. `"(default unknown; no documented
maximum)."`. Numeric page limits map to `Int`, never `String`. This is the
page-size case of the general rule in [§ Argument constraints](#argument-constraints);
the page-size wording above is what the `pagination-bounds-*` lint rules read,
so keep it.
When that default or maximum lies outside GraphQL `Int` (int64's
`9223372036854775807` is how some specs write "no limit"), no `Int` argument
can reach it: state `no practical maximum` (or `no practical default`) in
place of the number, e.g. `"Page size (provider default: 5; no practical
maximum)."`. `pagination-bounds-undocumented` accepts the phrase for a bound
outside `Int` only.

For page-indexed pagination (`pagination.style: "page"` in the inventory), the
page-index argument's doc comment must state the offset formula:
`"0-based page index (records skipped = page_index * page_limit)."` or the
1-based variant `"(records skipped = (page_number - 1) * page_limit)."`. The
doc comment must say: when the page size changes mid-iteration, restart at page
index 0 (or 1 for 1-based)—continuing at the old index skips records. When the
inventory declares a `maximum` inside `Int` on the size parameter, the description should
note values above it are rejected, so an agent hitting a rejection knows the
supported bound without probing.

### Paginated list operation descriptions

The operation description must state the result is one page, not the complete
collection, e.g. `"Retrieves one page of widgets. Iterate through all pages to
get the complete collection."` The stop condition: iterate until an empty or
short page; OR when the inventory's response facts name a completion signal
(`total_items_property`, `cursor_root_properties`, or `pagination.response`
cursor path), tell the caller to use it—e.g. `"Use the total field to know when
all records have been fetched, or iterate until a short or empty page."` The
restart-at-index-0 rule belongs on the page-index argument's doc comment, not
repeated in the operation description.

The `Returns:` line that [§ Descriptions](#descriptions) requires is appended
**after** the one-page/stop-condition sentence above, never in place of it.

## Sparse fieldsets

Some APIs return only the fields a GET names in a query parameter (Graph's
`fields=id,name,business{name}`). When a selected GET's inventory operation
has a **string** query parameter with the workspace's sparse name
(`workspace.yaml` `sparse_fieldsets: {param: fields}`; `fields` when
absent), the root field declares it and forwards it:

```graphql
meta_ads_campaign(
  campaignId: ID!
  """The Graph API fields to return, comma-joined. Defaults to every field this type exposes; pass fewer to narrow the response."""
  fields: String = "daily_budget,id,name,objective,status"
): Meta_Ads_Campaign
  @connect(source: "meta_ads", http: { GET: "/{$args.campaignId}", queryParams: "fields: $args.fields" }, selection: "…")
```

**The default is derived, not chosen.** It is the sorted, comma-joined
**wire** names (never the GraphQL renames) that the connector's own
`selection:` reads from the entity the operation returns:

- **a node GET** (the response is the entity object): its selected
  top-level fields.
- **a paged edge** (a pagination fact, and `data` the only array root): the
  selected fields of the `data[]` item. The page wrapper (the `data` key
  itself, and every key the pagination fact reads, such as `paging`) is
  left out. Meta's own SDKs send exactly the item fields on an edge.
- **an expansion boundary** (a property carrying `x-expansion`, a
  relationship to another node): the selected children render as a group,
  `business{name}`, recursively (`business{primary_page{name}}`), whenever
  they go beyond the boundary's **verified** default projection. Inside that
  projection (`business { name }` under a verified `["id","name"]`) no group
  is needed. An `unverified` default always groups. An embedded value with
  no annotation is requested whole.

**When the default cannot be derived**, do not guess. That covers upstream
aliases (`name.as(x)`), paging modifiers (`campaigns.limit(10){name}`),
edges requested as expansions, a page selecting a key beside its items, a
list response with no pagination fact (`{data: [...]}`, `{results: [...],
count}`, `{data: [...], meta: {...}}`: any response whose suggested
envelope names an array root; neither a node nor a recognised page), and a
selected path with no single wire name. Scaffold's stubs for a list keep
the wrapper and narrow its items. Record the literal instead, in a
resolved decision that names the operation and carries the literal
verbatim. Choosing the literal is a call — how many, which fields, inline
or not — so it carries the alternatives you weighed:

```
graphos-factory-core decisions add . --title "Ad account reads ten campaign names inline" \
  --question "What fields default does get:/act_{ad_account_id} send?" \
  --choice 'inline:ten campaign names inline' --choice 'ids:campaign ids only' \
  --resolved --chosen inline --note "callers list an account's campaigns by name" \
  --decision 'Send `campaigns.limit(10){name},id` as the fields default for get:/act_{ad_account_id}.'
```

A literal a reference settles instead (the vendor documents the one
projection that works) may be a current finding (`findings add --cites …`)
naming the operation the same way; the rule reads both.

Both halves match exactly. The operation key must appear whole in the
decision's text or as an `affects` entry: a decision about
`get:/act_{ad_account_id}/campaigns` does not name
`get:/act_{ad_account_id}`. The literal must be a whole **backtick span** in
the resolution (`` `id` ``, not the bare word; a fenced block counts too),
and an empty default is never excused.

**A decision adds; it never subtracts.** When the default *is* derivable, a
recorded literal passes only if it requests every field of the derived
list, compared as a tree. Order, whitespace and `.modifier(…)` suffixes do
not count: `id,campaigns.limit(5){name}` keeps `campaigns{name},id`, and
`business{id,name,extra}` keeps a derived bare `business`. A literal may
add a paging modifier, a wider group or an edge the connector does not
map. A literal that drops a mapped field (`business` for a derived
`business{name}`) fails the rule, because the source would stop sending
that field and the schema would resolve it null.

**A `fields` parameter that means something else** (the fields a search
looks in, Google's `items(id)` partial-response syntax) is not a sparse
fieldset. Turn the rule off with `sparse_fieldsets: {enabled: false}` in
`workspace.yaml` and record why in `decisions.json`. Lint then skips the
argument, and scaffold treats it as an ordinary argument.

`lint`'s `sparse-fieldsets` rule (an error) checks four things: the
argument exists, it is `String`, its default equals the derived list or a
recorded literal that keeps it, and `queryParams` forwards `$args.<param>`. A literal
`fields: $("…")` in `queryParams` fails the rule, because the caller could
never narrow it. A non-string parameter gets an `info` finding and the rule
does not apply. Lint validates the **declared default and the forwarding**.
It cannot prove anything about a value a caller passes at run time; that
narrowing is the caller's, and the argument's description says so.

## Argument constraints

Any argument whose inventory entry carries `default`, `minimum`, `maximum` or
`enum` states them in its doc comment. The inventory records those four keys
for *every* parameter and request-body property, not only page-size ones, and
an argument that drops them leaves the caller — usually another agent — to
guess or to probe:

```graphql
  "Sort order (default asc, one of asc|desc)."
  sort: String
  "Search radius in metres (default 25, min 1, max 100)."
  radius: Int
```

An array-typed request-body property also carries `minItems`/`maxItems` when
the spec declares them; state them the same way:
`"Custodians to add (1 to 100)."` A query parameter's array bounds are not
recorded yet, so read those from the spec.

How to spell it, so two services read alike:

- Cap an enum list at 8 values, then `(+N more)`.
- Keep an empty-string default rather than omitting it: `q (default "")`.
- Spell an enum-typed default bare, like the listed values: `default asc`,
  not `default "asc"`.
- An argument typed as a GraphQL enum states its values too. The consumer
  reads the argument before it follows the type reference, and `one of
  closed|open|all` on the argument saves that hop. The enum type stays the
  machine-readable list — `wire-enum-drift` checks *it* against the
  spec and checks nothing about the prose, so when the spec's value set moves,
  fix both.
- An argument whose inventory entry carries none of the four gets no such
  sentence. Never invent a bound the source does not state; for page size
  specifically, say the gap out loud (§ Pagination).
- Spell an exclusive bound `exclusive min N` / `exclusive max N`. OpenAPI 3.1
  writes it as the number (`exclusiveMaximum: 100`); OpenAPI 3.0 and Swagger
  2.0 write a boolean that makes `minimum`/`maximum` exclusive
  (`maximum: 100, exclusiveMaximum: true`). The inventory keeps the form the
  source wrote, so read the boolean with its `maximum`: both spell
  `exclusive max 100`, never `max 100`.
- A default outside `Int` on an `Int` argument is spelled exactly `(default:
  unbounded: the source's 9223372036854775807 does not fit Int; omit the
  argument to accept it)`, with the source's number. The router never sends
  a default, so the value reaches coercion only if a caller copies it from
  the prose. This spelling is the one doc comment that clears `int-overflow`,
  and it clears the default only. A `minimum`/`maximum` outside `Int` takes
  the same shape (`max: unbounded: the source's … does not fit Int`), but on
  any argument except the page size it is still an `int-overflow` error:
  retype the argument (§ Scalar choice).
- A workspace written before crate 0.5.26 states the number, as
  this section then prescribed: `(default 9223372036854775807, min 0)`. That
  is still an `int-overflow` error, because a caller can copy the number.
  The finding quotes the clause (`default 9223372036854775807`) and gives
  the replacement with the number filled in; replace only that clause and
  keep the rest (`, min 0`). Adding `default: unbounded` beside the old
  clause does not clear the finding: the number is still there to copy.
  The same holds for `default: no upper bound`, the wording
  some 0.5.1 workspaces carry: the finding quotes it as the clause to
  replace, and while it sits beside `default: unbounded` the finding says
  to delete it. When a doc comment holds more than one legacy clause, the
  finding names each one.
- For a page-size argument use § Pagination's spelling (`"Page size (provider
  default: 20, maximum: 100)."`, or the explicit-gap wording): that is the
  wording the `pagination-bounds-*` lint rules read, and this section does not
  restate it.

**The omission sentence, a fifth trigger.** An optional
argument (no `!`) whose inventory `description` has a sentence saying what
happens when the argument is omitted keeps that sentence verbatim in its doc
comment. It is a source fact like any other: covered by the schema, or a
recorded decision says why not (source coverage). A sentence is one
when it contains, in any case:

- a default: `by default`, `defaults to`, `default to` (`will default to`),
  `default is`, `default value is`;
- a condition on absence: `if` or `when`, up to four words, then `not
  passed|provided|specified|given|set|supplied|sent|present|included`, or
  `omitted`, `absent`, `unset`, `left empty|blank|out` (`if not passed`, `If
  this parameter is not provided`, `when unset`);
- `if no …` (up to three words) `is|are
  passed|provided|specified|given|set|supplied|sent` (`If no card is given`);
- `unless (otherwise) specified|provided|set|given`, or `omit (it|this) to`.

`missing` is not a cue: "if the user is missing a role" is about something
else. Venmo's `payment_card_id` ("ID of the payment
card to use for the transaction. If not passed, Venmo balance will be used.")
is the case: the first-sentence trim drops the second sentence, and nothing
else in the schema can say that no card means paying from the balance.

```graphql
  "If not passed, Venmo balance will be used."
  paymentCardId: Int
  "Sort order (default asc, one of asc|desc). Ascending when omitted."
  sort: String
```

- It must be about this argument. A sentence that names another of the
  operation's parameters or body properties does not count, because it
  describes how two arguments interact. A name counts as named when it
  appears case-sensitively, `[]` dropped, with no letter, digit, `_` or `-`
  directly before or after it. PagerDuty's `since` has "Defaults to 2 weeks
  before until if an until is given.", which names `until`, so it does not
  count. A sentence that names only the argument itself still counts. Gitea's
  `order` (`ignored if "sort" is not specified`) names `sort`, so it does not
  count. For a key nested in the request body, the keys beside it count as
  its siblings too.
- Keep the first sentence that qualifies. A sentence ends at `.`, `!` or `?`
  followed by a space and something other than a lowercase letter (but not
  after `e.g.`, `i.e.` or `etc.`, and not inside parentheses or brackets:
  `Defaults to 10 (max. 100 per page).` is one sentence), at a blank line,
  and at a list item.
- Where it goes: after the clause, as a sentence of its own, separated by one
  space from the clause's period. Keep the source's final punctuation, and add
  a period when there is none: `(default asc, one of asc|desc). Ascending when
  omitted.` With no clause the sentence is the whole doc comment, or it
  follows the opt-in source sentence in the same way. Never cap it at 150
  characters and never paraphrase it.
- Write it once, never twice. When the omission sentence is the source's first
  sentence and the workspace opted in to the source sentence, part (1) of
  § Argument descriptions already carries it
  (`"include private repositories this user has access to (defaults to
  true)"`), and nothing is added after the clause. When the workspace has not
  opted in, write the sentence as described above.
- A `defaults to` sentence can repeat the clause's `default`. Keep both: the
  clause is the uniform spelling, and the sentence often says what no
  `default` key can (`Defaults to current time.`).
- Page-size and page-index arguments keep § Pagination's wording and get
  nothing else. A required argument gets no omission sentence, because the
  caller cannot omit it.

The clause is the default-on half of an argument's doc comment; whether a
source description goes in front of it — opt-in, one sentence — and what never
goes in one at all (the argument's type or requiredness) is
[§ Argument descriptions](#argument-descriptions).

**Never write `= literal` on an argument.** An SDL default is executable — the
router sends it when the caller omits the argument — and a consuming agent
reads a published default as "the value to use": a default of 5 against a
maximum of 20 produced four times more pagination calls than the API needed.
The provider's default belongs in the doc comment, which the rule above
guarantees is there. The one exception is a sparse-fieldsets argument
(§ Sparse fieldsets): its default is the fields list the connector maps, not
a provider default, and it must be declared.

What is checked mechanically: the page-size half of the rule above, by
`pagination-bounds-undocumented` and `pagination-bounds-unknown`; and, for
every other constrained argument, that it has a doc comment at all, by
`argument-constraints-undocumented` (a warning), whose message
spells the clause. Whether an existing doc comment states the clause, and the
`= literal` ban everywhere, are applied by hand.
The same rule also reads what an optional argument's doc comment says:
when the omission sentence above is missing, whether or not the
argument has a doc comment, the rule warns and quotes the sentence. The
sentence counts as present when, without its final period, it appears in the
doc comment after both are whitespace-normalised and compared
case-insensitively. `source-coverage --check` also fails on the
same sentence, and a resolved `behaviour` waiver silences both the check and
this warning.
Both halves trace an argument to its source entry through a `queryParams`
key, an aligned path segment, a header whose value is the argument
(`{ name: "From", value: "{$args.from}" }`), and a body key, flat or nested
in object literals, `$({ … })` included, through methods such as
`->map(…)->first`. An argument sub-selection (`$args.input { … }`)
or a deeper path (`$args.input.x`) sends an input type's fields: their doc
comments are not read, so write their omission sentences by hand.
The only lint rule that reads an SDL default is `sparse-fieldsets`, on its
own argument. `int-overflow` reads one clause, `default: unbounded`, on an
`Int` argument whose source default lies outside `Int`, and
quotes a `default N` clause stating that number, or a `default: no upper
bound` clause, as the text to replace.

## Nullability

Be conservative. A field is non-null (`!`) only when the API is documented
non-null **and** you have seen it populated in a recorded sample or a live
probe. A mapped field the payload lacks yields `null` with no error — a
wrong `!` turns that silent null into a runtime error for the whole
response, and a spec that says non-null is not evidence: vendors ship
`summary: null` against a `required` declaration routinely.

Path parameters are the exception: their arguments are always `!`, because
the URI cannot be built without them.

## Scalar choice

GraphQL `Int` is a signed 32-bit integer. A source that declares a numeric
property or parameter `format: int64`, `uint64` or `uint32` is saying the
value may not fit — `uint32` is unsigned, so its upper half is past 2^31 too.
Past 2^31 the router nulls the field and reports a coercion error
rather than returning the number, and every offline layer stays green because
the recorded fixtures carry small values. The `int-overflow` lint
([testing.md](testing.md)) is an **error** on exactly this. Two fixes, and
there is no third — no doc comment silences the rule, because a sentence
beside a field does not change what the router coerces:

- **`ID`** for an identifier — a row id, a foreign key, or a resource's own
  number used to address it. `ID` accepts an integer literal as input, so
  `gitea_issue(index: 1)` in a test document keeps working when
  `index: Int!` becomes `index: ID!`, and the value is interpolated into the
  URL verbatim. This is the right answer for **an argument**.
  An **output** field is a different judgement: `ID` is for something a
  consumer passes back, not for a number it does arithmetic on, and this
  router hands an `ID`-typed numeric property back as a bare JSON number
  rather than a string — so an output that happens to be the same value as an
  `ID` argument still follows the magnitude rule below. The gitea pilot is the
  worked example: `gitea_issue(index: ID!)` and `Gitea_Issue.number: String`
  are the same number in the two positions.
- **`String` mapped with `path->match([null, null], [@, @->jsonStringify])`**
  for everything else — a magnitude (bytes, kilobytes, seconds, money in
  minor units) and an unbounded counter alike.

  The null guard is not decoration. A bare `path->jsonStringify` turns a JSON
  `null` into the four-character string `"null"`, which a nullable `String`
  field happily carries: the same silent wrong answer `int-overflow` exists to
  prevent. `->match([null, null], …)` hands back `null`;
  `$(path?->jsonStringify ?? null)` does too, but `reconcile` does not read a
  `$(…)` expression block as a mapping of its path and reports every such leaf
  as unmapped, so prefer the `->match` form.
  `.github/scripts/null-mapping-probe.sh` pins both halves against rover.

  The mapping must be **aliased**: `size: size->match(…)` composes, a bare
  `size->match(…)` does not
  ([connectors-language.md](connectors-language.md)).

  A converted field's doc comment says so, e.g. `"Size in kilobytes. int64 in
  the API; String keeps the value exact and a null stays null."` — otherwise
  the next reader sees a `String` holding digits and takes it for an
  oversight.

A declared `minimum`/`maximum` is the source's own word and beats the format
hint: an `int64` property bounded inside `Int` is not a finding, and a bound
outside `Int` is one whatever the format says. This is why *Numeric page
limits map to `Int`, never `String`* (§ Pagination) does not contradict this
section — a pagination size parameter is a small number by construction and is
exempt from `int-overflow` outright. An `exclusiveMinimum`/`exclusiveMaximum`
counts as the bound it is, and a `default` outside `Int` is a finding too
(§ Argument constraints has the one spelling that clears a default on an
argument).

An `ID` argument mapped into a JSON body is not re-typed to a string. The
router sends the literal the caller wrote: `milestone: 1` reaches the body as
the number `1`, and `serviceId: "PSVC001"` as a string. This was measured at
e2e on Router 2.17.0 (the gitea pilot's `create_issue`, the pagerduty pilot's
`create_incident`). `rover connector test` sends every `$args` scalar as a
string (the gitea pilot's `.factory/memory.md`), so a numeric id in a body is
proven at e2e only. Check what type the source wants, and record the choice.

Every numeric predicate over a converted field has to be restated. In jq,
`.count >= 1` on a JSON string compares as a string and is true for every
value the API will ever send — a green assertion proving nothing. Pipe it
through `tonumber`, which fails loudly on anything that is not a number
(the gitea pilot's `tests/live.yaml`).

## Enums

Map a closed enum to a GraphQL enum when the values are valid GraphQL names
and the set is genuinely closed. Otherwise use `String`:

- `x-extensible-enum` (Zalando's convention) means an **open** enum. `String`
  is the correct mapping; a closed GraphQL enum silently rejects values the
  API will send.
- Values that are not valid GraphQL names (leading digits, hyphens, dots)
  need a `->match` translation in both directions. That is real complexity;
  take it only when the enum is load-bearing, and note it as a decision in
  `decisions.json`.
- Keeping the vendor's own casing avoids the translation entirely when the
  values serialise straight back into request bodies.

`graphos-factory-core lint` checks the first sentence (`closed-enum-as-string`):
a selected argument or response leaf typed `String` while the
source's `enum` is all strings and every value is a valid GraphQL name is a
warning until it is an enum in wire casing or the reason it is not is on
record. Keeping `String` over a valid enum is a call (the enum is the
alternative), so the reason is a **resolved** decision whose `affects`
names the slot — `Type.field` for a leaf (`Pagerduty_Reference.type`), the
prefixed root field with the argument in parentheses for an argument
(`gitea_listIssues(state)`, `Query.gitea_listIssues(state)`, or several at
once, `gitea_listIssues(state, type)`):

```
graphos-factory-core decisions add . --title "…" --question "…" \
  --choice 'string:keep String' --choice 'enum:an enum in wire casing' \
  --resolved --chosen string --decision "…" --affects "Pagerduty_Reference.type"
```

When the source itself settles it (the vendor documents the vocabulary as
open), a current finding with the same `--affects` counts too
(`findings add --cites …`). An `open` decision is a pending question and does not count. Two conditions
keep the rule quiet where an enum would be wrong or empty, and neither needs
a decision. A **one-value** `enum` is a constant discriminator
(`Pagerduty_Service.type` is always `service`), and a one-member GraphQL enum
documents nothing the field does not already say, so the rule wants two or
more values. A field that **several selected operations reach** —
`Pagerduty_Reference.type`, one type for ten reference slots, where the spec
enumerates the vocabulary at only one of them — is judged on every spec
property that reaches it and fires only when all of them declare such an
enum, then proposes the union of their values; an enum built from one slot
would fail coercion on the others. A reach the spec does not document — an
operation with no response shape, or a parent object absent from it — counts
as declaring none. The second sentence is not a finding
either: a vocabulary with a leading digit or a hyphen (`2`–`10`,
`in-progress`) is `String` by this rule, and a slot the connector maps with
`->match` is the mapping's to spell. The gitea pilot's
`Gitea_ObjectFormatName` (`sha1 | sha256`, reached by two operations that
both declare it) is the worked conversion; the pagerduty pilot's five `type`
fields are the worked silence — one shared reference type and two one-value
constants, no finding and no decision.

## Cycles and depth

REST payloads embed each other; GraphQL types can reference each other
freely, so a cycle in the shape is not itself a problem. Depth is: a
`max_depth` of 6 in `selection.yaml` is the default because deeper nesting
almost always means the API embedded an unrelated resource. At the limit,
stop and expose the nested resource's id, with its own operation if one
exists. Say so in the type's doc comment.

The inventory flags exactly this pattern for you: a property whose name
and type family match the trailing path parameter of a canonical GET-by-id
operation whose response is one record carrying that key carries a
`candidate_entity_link` fact, wherever it sits in the
response shape — a top-level property, a list item (`[]>album_id`), or a
nested object or list (`songs[]>album_id`, `owner>account_id`).
`graphos-factory-core inventory links .` prints every fact flat, with the
operations that return the host shape and whether the by-id operation is
selected, then the GET-by-id operations it refused as targets and why — a
read keyed by an email that returns a balance (AppWorld splitwise) is one:
it is not the record the email names, so no property gets a hint for it;
`inventory list` shows the same as `links:` lines under each
operation. It is a hint, never a finding. Route it through the selection,
not the schema: `graphos-factory-core selection draft .` writes one `links:`
entry per fact with `confirmed: false`; agree each with the user; a
confirmed one is applied as a relationship field on the host type —
`graphos-factory-core links apply . --dry-run` prints the field-level `@connect`
keyed by `$this` for you to paste ([connectors-language.md § Relationship
fields](connectors-language.md#relationship-fields)); no `@key` and no
decision are involved. Decline one with `include: false` and a `reason` on
its entry; a service-wide "no relationship fields" is one decision in
`decisions.json`, with wiring them as its alternative (`graphos-factory-core
decisions add . --question … --choice … --resolved …`), the way gitea's
D-0013 did it. The entity form (`@key`, a type-level or `$batch`
connector) is the exception for cross-subgraph references and batching,
and that one does need a decision.

## The opaque JSON policy

> Untyped beats unreachable, but typed beats untyped.

Emit `Widget_Co_JSON` only when the shape cannot be typed honestly:

- polymorphism the connector cannot type. At `connect/v0.3` that is every
  `oneOf`/`anyOf`. At v0.4 a `oneOf` of objects is a union, or an interface
  when its members share fields
  ([mapping-language.md § Abstract types](mapping-language.md#abstract-types)).
  It stays JSON only when:
  - no wire value tells the members apart;
  - a member is not an object;
  - the value sits under another type's field, and no key can re-fetch it
    through a connector of its own;
- a genuinely free-form object — `type: object` with a description and no
  properties is a real and common shape meaning "arbitrary JSON here", not
  a defective spec;
- `additionalProperties`-only maps.

Every JSON-scalar field carries a doc comment saying **why**: a reader of
the schema, and any policy your supergraph attaches to `@tag`, learns
nothing about a field typed JSON except from that comment, and a field
nobody can describe is a field nobody can use with confidence. `graphos-factory-core
lint` fails on an undocumented one under the default `opaque_json_policy:
forbid`; `allow_with_reason` relaxes it, and typed fields are still the
rule.

The doc comment is for a human; `graphos-factory-core spans json-accounting .
[--check]` is the machine check. It enumerates every field the *rendered*
SDL still types as the scalar — including a field nested inside another
object type and one wrapped in a list at any depth (`[Widget_Co_JSON]`,
`[Widget_Co_JSON!]!`, …) — and matches each, keyed `"<TypeName>.<fieldName>"`,
against a `json_reasons` entry on a **resolved** `.factory/decisions.json`
record (`graphos-factory-core decisions add --json-reason 'Type.field|reason'`;
never a `selection.yaml` field or a schema doc comment — the decisions-only
rule, because reasons recorded in the schema confused the model reading it), for a reason from a closed vocabulary: `free-form-object`,
`recursive`, `vendor-undocumented`, `polymorphic-without-discriminator`,
`depth-cap`.
`defaults.fields: all` decides which fields are *selected*; it never counts
as a reason for one that is still typed JSON.

**Reasons are re-checked every run, not recorded once and trusted
forever.** Each is a predicate over the current `.factory/inventory.json`
shape at the field's own path (the type's bare shape name, then the
property matching the field name or its snake_case wire form) —
`recursive` means the `$ref` chain loops back to itself; `free-form-object`
means `type: object` with no declared `properties`; `vendor-undocumented`
means no shape is recorded there at all; `polymorphic-without-
discriminator` means a `oneOf`/`anyOf` with no `discriminator`;
`depth-cap` means the workspace cut the field at its stated depth: its type
sits at `defaults.max_depth` on some path from a root field (6 when unset),
or the shape is a recursion, and the inventory has a structured shape
beyond the cut. A holding `depth-cap` outranks `recoverable`, because
re-typing the field would undo the cut the reason states. A field
with no matching entry, or an entry whose `reason` is outside the closed
list, is `unaccounted`; a recorded reason whose predicate no longer holds
is `stale` — the field moved, the recorded claim did not, usually because
the vendor now documents something different. A field the inventory has
since made fully typed is `recoverable` regardless of what reason (if any)
is on file — that overrides the other three, because a reason that used
to be true is moot once the source has caught up, and the fix is to
re-type the field, not to re-justify it. A recorded reason on a type
whose shape cannot be located at all (not by name, not through its root
field's operation, not through a parent's property) is `unresolved`: an
open finding, never accounted or stale. `--check` fails closed on
anything but `accounted`.

What is never acceptable: a typed guess that drops payload data. If you
type four of a payload's nine keys, the other five are unreachable through
this schema and no test will ever tell you.

## Errors

Map errors once, on the `@source`, with a `??` fallback in the message
expression — several statuses on every API have no JSON body at all. When
you write a test that asserts an error mapping, `tests/router.yaml` needs
`include_subgraph_errors: { all: true }` or the snapshot shows only
`Subgraph errors redacted` and the assertion proves nothing.

**Take the message path from the inventory, never guess it.** Read the
selected operations' `errors[]` in `.factory/inventory.json`; each entry
names a `status` and either a `shape_ref` or `null`. Follow every non-null
`shape_ref` into `shapes` and write the path the documented body actually
carries — `$.message` for `{message: string}`, `$.error.message` for
`{error: {message: string}}`, and so on for whatever shape is there. When
different statuses on the same `@source` document different bodies, chain
their paths with `??` in declared order; a status whose `shape_ref` is
`null` documents no body at all, which is why the chain still ends in a
string fallback. In older inventories, an error body written inline in the spec
— not a `$ref` — was silently dropped from the inventory (`shape_ref:
null`) even though the body was fully documented; a path copied from
another API's convention (`.detail` is FastAPI's default, not necessarily
this API's) is the failure that produced. `graphos-factory-core lint`'s
`error-path-unresolved` checks this mechanically: every `$.` path in an
`errors` block — each side of a `??`, and each `->first`/`->last` step into
an array item, checked separately — must resolve in at least one
documented error shape for the operations the block covers, or it warns.
It is silent when no shape is documented at all, and a free-form body
(opaque JSON, no properties) counts as resolving.

## Descriptions

Every root field and every type gets a doc comment. Prefer the vendor's own
summary over a paraphrase; it is what the API's users already know, and it
is what an MCP client shows to a model choosing between tools. A spec with no
summaries (every Google discovery-derived one) gives the operation's
`description` instead. `lint`'s `undocumented-root-field` (an error)
fails a selected root field with no doc comment while that text exists, and
quotes it. Where the
connector deliberately differs from the API (an excluded field, a flattened
envelope, a renamed operation), say so in the doc comment as well as in
`decisions.json` — the README's "Limitations & exclusions" section is
generated from those decisions (the resolved records). An argument carrying a
`default`, `minimum`, `maximum` or `enum` in the inventory states it in its own
doc comment — see [§ Argument constraints](#argument-constraints) for the
general rule and § Pagination for the page-size case.

**A service that mints its own credential states the rule on the login root
field**. App-level facts a consumer needs go on the
credential-minting root field's doc comment, before its Returns line, and on
the token type's description. Never put them in a schema description (a
description on the `schema` definition): the composed supergraph keeps only
one, so a consumer of any other service never sees it. Never put them in a
`#` comment either: that is not SDL and never reaches a consumer. The facts
are: which operation mints the credential; that every secured operation
takes it as an argument, named (`access_token`); and which account property
is the username, when the account-creation shape in the inventory determines
it. Take the username fact from the inventory shape; never invent it. A
service whose credential lives on `@source` and in the README (all three
pilots) is unchanged. § Argument descriptions' credential bullet names both
homes — the source directive and README for a forwarded credential, the
login root field for a self-minted one — and either way the rule is stated
once, not on every argument.
`credential-source-undocumented` warns when two or more selected root fields
take a credential-named argument, a selected root returns a type declaring
it, and that root's doc comment does not name it before the Returns line
([testing.md](testing.md) has the name list).

### Object field descriptions

The rule above covers root fields and types; it says nothing about
object-type fields (`properties`), and the gap shows: across the three
pilots only 54 of 395 object fields carry a doc comment (14%), even though
the inventory already holds far more source material than that — gitea's
`inventory.json` alone carries a `description` on 732 of 1334 properties
(55%). `COPY_KEYS` (`crate/src/openapi.rs`) copies `description` verbatim
from the OpenAPI/Swagger document onto every property already; the gap is
guidance, not missing data.

**Opt-in per service.** Unlike Pagination and the rule above,
this is not on by default: a workspace adopts it explicitly, recorded as a
resolved decision in `decisions.json` (`graphos-factory-core decisions`, never
hand-edited — [workspace-contract.md](workspace-contract.md)). The trade is
unmeasured — bigger schema text, a larger context budget for every
consumer, against filling a real documentation gap — and unlike the
Returns-line rule, which shipped only once the apollo-conn-gen
benchmark had measured the turn it closes, there is no bundled evidence yet
that this helps. Its effect is to be measured per service, not
asserted.

Once a workspace opts in:

- A field whose inventory property carries a non-empty `description` gets a
  doc comment using that text, trimmed to one sentence — cut at the first
  sentence boundary. A source with no sentence boundary (one long run-on)
  is capped at roughly 150 characters and closed with `…` rather than cut
  mid-word. `created_at` sourced from `"The time the issue was created.
  Read-only; set by the server on POST and never revised."` becomes `"The
  time the issue was created."`; `html_url` sourced from a run-on such as
  `"The fully qualified URL that resolves to this issue in the web UI,
  suitable for use in a notification or chat message so the reader lands on
  the exact issue without reconstructing the path from the id and repo
  name"` becomes `"The fully qualified URL that resolves to this issue in
  the web UI, suitable for use in a notification or chat message so the
  reader lands on the exact…"`.
  Never paraphrase, and never invent a description the source does not
  contain.
- A field with no source description gets none — this is opt-in enrichment
  of what the inventory already states, not a mandate to describe every
  field.
- A field that already carries a doc comment is never touched. This rule
  fills gaps; it does not relitigate existing curation.

### Argument descriptions

Root-field arguments have the same gap and the same source material as
object fields — the inventory copies every parameter's and request-body
property's `description` verbatim — with one difference: this surface
already carries a default-on rule, the constraint clause of
[§ Argument constraints](#argument-constraints), and a lint-read
wording for page-size arguments (§ Pagination). What it did not have was a
rule for the rest, and the gap was measured: an authoring run with
no rule for this surface produced 1,565 argument doc comments where the
previous run had produced 0 — 691 of them verbatim OpenAPI parameter text,
367 a per-argument "requires access_token" sentence — and the schemas'
description text grew from 28 KB to 229 KB. A documentation surface with no
rule fills with vendor text.

**Opt-in per service for the source sentence, the same mechanism
and the same reasoning as Object field descriptions above.** The constraint
clause stays default-on because a benchmark measured what its
absence costs. The source sentence has no such measurement behind it, its
cost side is the usual one — bigger schema text, a larger context
budget for every consumer, vendor prose of uneven quality — and in the run
above it was 691 lines nobody asked for. A workspace adopts it as a resolved
decision in `decisions.json` (`graphos-factory-core decisions`, never
hand-edited); promotion to default-on waits on a measured comparison, not on
this rule.

An argument's doc comment is composed of at most three parts, in this order,
and nothing else:

1. **The source sentence — opt-in.** The inventory parameter's (or
   request-body property's) `description`, trimmed exactly as Object field
   descriptions trims: cut at the first sentence boundary, a run-on with none
   capped at roughly 150 characters and closed with `…`. Verbatim — the
   source's own casing, wording and punctuation, never paraphrased, never
   invented. No `description` in the inventory, no sentence. Written as a
   single-line `"…"` string, never a `"""` block (why, under part 3).
2. **The constraint clause — default-on.** § Argument constraints,
   unchanged: `(default asc, one of asc|desc)`.
   The omission sentence of § Argument constraints is also
   default-on, and comes verbatim after the clause:
   `(default asc, one of asc|desc). Ascending when omitted.` When it is the
   source's first sentence and part (1) is opted in, part (1) carries it and
   it is not repeated.
3. **Page-size and page-index wording.** A page-size or page-index argument
   keeps § Pagination's wording and gets nothing else — **the source
   sentence is not added to it**, opted in or not.
   `pagination-bounds-undocumented` accepts any standalone number in the
   argument's doc comment that equals the inventory bound, and
   `pagination-bounds-unknown` accepts `no documented`, `unknown`, `not
   specified` or `no bound` anywhere in it (`lint_pagination`,
   `crate/src/lint.rs`); a source sentence that happens to carry a number or
   one of those phrases satisfies the rule without the schema saying what
   the rule wants said. The mechanism is measured, not a gitea case:
   Gitea's whole two-sentence `order` description — the second
   sentence ends `ignored if "sort" is not specified.` — placed on a
   page-size argument silences the gap warning; the one-sentence trim this
   rule would actually produce carries no such phrase and leaves lint where
   it was. The exclusion guards against a source whose *first* sentence
   carries a bound number or a gap phrase. The single-line form under part
   (1) guards the same rule from the other side: `arg_doc_comment` reads the
   doc comment leftmost-first, so a `"""` block on the page-size argument
   makes it read from the first earlier `"""` block in the argument list
   onward, and a source sentence on *any* earlier argument then satisfies
   the rule (also measured).

When (1) and (2) both apply, spell them as the source sentence without its
final period, then the clause in parentheses, one period — the constraint-clause
spelling with the source sentence in front:

```graphql
  "Sort order (default asc, one of asc|desc)."
  sort: String
  "owner of the repo"
  owner: String!
```

No doc comment when none of the three applies.

- **Never restate type or requiredness.** The SDL already says both:
  `String!` is the whole of "a required string". Two tests, applied to the
  source sentence as much as to anything hand-written. *Requiredness* is
  never written in any form — `Required.`, `Required argument`,
  `(required)`, `Optional.` — and is cut from a source sentence wherever it
  appears (a cut, not a rewording; a sentence that is only this is dropped).
  *Type* is judged by what the text adds to the declaration and the
  argument's own name, not by which words it contains: a sentence that only
  names the type — a bare `string` or `integer`, `the ID of …`, `list of …
  ids` — is dropped, not trimmed, so `"milestone id"` on `milestone: ID` and
  `"list of label ids"` on `labels: [ID!]` get no doc comment; `"search
  string"` on `q: String` stays verbatim, because `q` alone does not say the
  value is a search term.
- **A credential the connector forwards** (`access_token`, an API-key
  argument) gets parts (1)–(3) like any other argument and nothing more. No
  per-argument "Requires access_token" sentence: where the credential comes
  from is stated once — on the source directive and in the README, or, for a
  credential the service mints itself, on the login root field
  (§ Descriptions) — not on every argument that carries it.
- **An argument that already carries a doc comment keeps it.** As with
  object fields, this rule fills gaps; it does not relitigate existing
  curation. The two rules above that are not opt-in still apply to it: a
  restatement of type or requiredness is removed, and a constraint the
  inventory carries is still owed (§ Argument constraints).

Nothing new is checked mechanically. `pagination-bounds-*` read a page-size
argument's doc comment (§ Pagination says what) — and, when that doc comment
is a `"""` block and an earlier argument carries one too, everything from
the earlier block onward, which is why part (1) is a single-line string; no
rule counts argument doc comments, measures their length or reads them for
type words. Review by reading the schema.
`argument-constraints-undocumented` also checks that part (2)'s
omission sentence appears in the doc comment (§ Argument constraints).

### Returned field names

A root field's doc comment **ends with the names its response type exposes**,
so an agent that has chosen the operation can write the selection set without
spending a turn introspecting the return type. Spell the names as the schema
spells them (GraphQL-visible, post-alias) in declaration order, comma
separated:

- **Object response** — `Returns: id, name, createdAt.` — the order the type
  declares, not alphabetical.
- **List response** — `Returns a list of items with: id, name, createdAt.`
- **Envelope response** — an object whose one object-list field carries the
  payload and whose other fields are paging plumbing or a status flag (the
  shapes [§ Envelopes](#envelopes) recognises): write both lines.
  `Returns: incidents, limit, offset, more, total.` then ``Each item in
  `incidents` has: id, incidentNumber, title, …`` The envelope's own names do
  not answer the question the line exists to answer, so naming them alone is
  not enough. The payload field stays a bare name in the first line: the
  second line is its expansion, and the brace form below would name the item
  fields twice.
- **Scalar, union or opaque-JSON response** — no line at all. `gitea_version:
  String` gets none. Never guess a shape the schema does not state.

**An object-typed entry renders one level deep, and a small leaf-only
object inside it one more**. A field whose
type is an object, or a list of objects, carries that type's field names in
braces — `teams { id, type, summary, self, htmlUrl }` — in the nested type's
declaration order, comma separated, capped at **6** and closed with
`(+N more)` inside the braces: `owner { id, login, loginName, sourceId,
fullName, email (+16 more) }`. Inside the braces, an object field whose
type has **at most 6 fields, every one a leaf** (scalar, enum or opaque-JSON
scalar), gets braces of its own: `cards { code, value, suit, image,
images { svg, png } }`, and on a splitwise-shaped type `shares { debtor {
name, email }, debtAmount }`. A second-level type with any object-typed field,
or more than 6 fields, stays a bare name — `piles { name, remaining, cards }`,
because a card carries `images` — and nesting stops there. A second-level
brace group is one entry toward the nested 6; its own list needs no cap,
because it is at most 6 by definition. Scalars, enums and opaque-JSON fields
are names only, at every level. A bare name for an object field reads as a leaf, and a
consuming agent acts on that reading: in one AppWorld run a text message's
flat `sender, receiver` produced selection errors in 13 tasks, and flat
reference types invite guesses such as `first_name`
([lessons.md](lessons.md)).

Cap the outer list at 14 entries and close it with `(+N more)`. The 14 are the
first 14 in declaration order, never a hand-picked "interesting" subset — a
reviewer checks the line by reading the type top to bottom, and a subset
nobody can re-derive is a judgement with no audit. A brace group is one entry
toward the 14, whatever it holds; the nested cap of 6 is counted inside the
braces and separately. Wrap between entries and keep a brace group on one
line where it fits: the breaks are cosmetic inside a `"""` block, but a group
split across lines is harder to check against the type.

One shape still leaves the introspection turn in place, and it is not a reason
to widen the rule. A **very wide type**: the cap leaves most of it unnamed —
Gitea's `Gitea_Repository` has 46 fields, so `gitea_repo` ends `(+32 more)`,
and the nested cap does the same one level down (`owner { … (+16 more) }` on
the 22-field `Gitea_User`). The **resource that merely embeds a list** — not
an envelope, because [§ Envelopes](#envelopes) wants exactly one other
non-link property — was the rule's second limit until the brace form closed
it: `piles { name, remaining, cards }` names the item type's fields where a
bare `piles` did not. What stays unnamed is a second-level type that is not
small and leaf-only (the `Card` fields under `cards` inside `piles`), and
everything below the second level, by design.

The line is the last thing in the doc comment. On a paginated operation it goes
**after** the one-page/stop-condition sentence (§ Paginated list operation
descriptions), never instead of it: `list-completion-missing` looks for a
pagination keyword anywhere in the description, so a `Returns:` line that names
an envelope's `total` field satisfies the rule by itself and would hide a
missing stop condition.

Root fields only. Nested types keep their own doc comments — the turn this
removes is on the operation the agent has already picked, and a `Returns:` line
on every nested type would collide with the entity-type descriptions for no
measured gain. Whether the line pays for itself is an eval question, not
something this rule asserts.

`returns-line-nesting` (warn) reads each selected root field's
Returns line against the SDL: a name the type does not declare, a bare
object-typed entry at the first level (the envelope's payload field in the
first line excepted), a bare small leaf-only object at the second level, and
braces on a second-level type that is too wide or nests. It does not check
the order, the caps or the `(+N more)` arithmetic, and a doc comment with no
Returns line is not its business.

## Which operation a root field serves

`reconcile`, `lock` and `source-coverage` find a root field's operation
from its `@connect` method and path: the literal path, else the one
operation whose template matches once parameter names are erased. Where
several do — a Graph-style API serves every node at a bare `/{id}`, so
`GET /{$args.campaignId}` matches `get:/{campaign_id}` and `get:/{ad_id}`
alike — the field is attributed to the operation whose selection entry
names it: `<field_prefix>_<graphql.name>` under `graphql.root`. Keep the
field name exactly that. An included entry's claim wins; an excluded
entry's `graphql` block still names its field until `apply` removes it,
which is how reconcile knows what to remove. A type-level `@connect` (an
entity) on such a path is attributed to the entry marked
`graphql.entity: true` whose root field returns that type. A field or type
nothing declares, or one two entries of the same rank both claim, is a
`reconcile` selection error listing the candidates. For a root field,
`lock` also refuses to record it, `codify` refuses it, and `lock --check`
and `lint` (`unattributed-span`) report it as a tie to settle in the
selection, not a hand edit. The tool never picks one.

## Coverage: what the schema leaves on the wire

**Source coverage**: every fact the source offers is covered by
the schema, or a recorded decision says why not. A schema is finished when
that holds, not when every selected operation compiles. `graphos-factory-core
source-coverage . OP-KEY` reads one operation's request body and response out
of `inventory.json` and classifies each leaf. It was once `spans obligations`,
and that spelling still runs. It does **not** classify
path, query or header parameters, with one exception (the behaviour section,
below). Check the rest by hand against the operation's `parameters` in the
inventory: every one should be an argument, a fixed value in the connector's
URL, `queryParams` or `headers`, or a recorded decision.

| Class | Meaning |
|---|---|
| `mapped` | a schema field reads or writes it, including as a later operand of a `??`/`?!` chain in the selection (`title: name ?? label`) |
| `consumed` | no field, but a connector expression reads it (an error path, a `??` fallback in `isSuccess`/`errors`) — response side |
| `omitted-decided` | an `omits` entry on a **resolved** `decisions.json` record or a current `findings.json` finding covers it, with a reason; one on an open or superseded record does not count, and the row stays `unaccounted` with a note naming the decision |
| `unaccounted` | nothing does — the schema silently drops it |
| `unresolved` | the tool could not tell: an inventory shape it cannot resolve, a dropped spec construct, or a connector expression outside the grammars it parses (a request-side `->match`, a request-body expression) |
| `unverified-default` | an expansion boundary whose default projection is not verified: one row for the relationship, its children not enumerated — response side |
| `transport-expansion-missing` | the schema maps a boundary child the request never asks for, so the source never sends it — response side, not counted as offered |

Run it per operation while authoring, and again with `--check` (non-zero
when anything is `unaccounted`, `unresolved`, `unverified-default` **or
`transport-expansion-missing`**, naming which on stderr) before `lock`.
**Zero of all four in both directions is the completion bar**:
`--check` fails closed, because an unresolved path is not known
to be handled. An `omits` record does not clear an unresolved or an
unverified-default row.

**Behaviour facts.** A third section, `behaviour`, appears when
an optional argument's source says what omitting it does (the omission
sentence of § Argument constraints, "If not passed, Venmo balance will be
used."). One row per such argument:

| Class | Meaning |
|---|---|
| `documented` | the argument's doc comment carries the sentence |
| `waived` | a `behaviour` omit on a **resolved** decision or a current finding records why it does not |
| `unaccounted` | neither — `--check` fails on it (`behaviour unaccounted N`) |

The row's path is the source the argument reaches — `query:NAME`,
`path:NAME`, `header:NAME` or `body:KEY.PATH` — and the row names the
carrying argument (`Query.shop_pay(paymentCardId)`) and quotes the sentence.
Fix an `unaccounted` row by writing the sentence into the doc comment, or
record why not. When the sentence is not about omitting this argument (a
"by default" about a server setting), the source settles it: a finding.

```
graphos-factory-core findings add . --title T --body TEXT --cites REF \
  --omit 'get:/x|behaviour|query:sort|not-applicable'
```

When you chose not to state it, that is a call with stating it as the
alternative: a decision.

```
graphos-factory-core decisions add . --title T --question Q \
  --choice 'omit:leave the sentence out' --choice 'state:state it' \
  --resolved --chosen omit --decision TEXT \
  --omit 'get:/x|behaviour|query:sort|editorial'
```

`not-applicable` and `editorial` are the two reasons for a `behaviour` omit;
`consumed` is a wire reason and is refused, and `findings add` refuses
`editorial`. The waiver clears the sentence, not the constraint clause. It
covers exactly the one source it names, and only on a resolved decision or
a current finding. An argument sent through an input type
(`$args.input { … }`, `$args.input.x`) has no row yet: the trace stops at the
argument, so write those sentences by hand.

**Do not make an optional source parameter required to get past this.** `!`
on an argument whose source parameter or body key is optional is the lint
error `argument-required-optional-in-source`: the caller could no
longer leave it out, so the source's omission behaviour would be unreachable.
Make it optional, or, when it must be required, record why with the
decision form of the `behaviour` waiver above (`--omit 'get:/x|behaviour|query:x|editorial'`).

**A bare `$` selection** returns the whole response, and the
classifier reads it that way: `selection: "$"` on a `[String]` field over
a root array of strings maps `[]`, and over an object or an array of
objects maps every row beneath it as `mapped (json)`. `$ { … }` walks its
sub-selection from the root, and a method on the bare `$` (`$->first`)
leaves every row `unresolved`. Record no `omits` entry for a root row a
bare `$` returns; one recorded before 0.5.67 still resolves, but the row
now reads `mapped` first.

**Every selected operation at once.** With no OP-KEY,
`graphos-factory-core source-coverage . [--json] [--check]` runs the same
classifier on every operation `selection.yaml` includes (`include: true`),
in inventory order. Do not loop over `inventory list`: it pages, and it
lists operations the selection leaves out, which need no coverage.

- Text: one line per operation with both directions' counts (and
  `unverified-default` / `transport-expansion-missing` when nonzero),
  `FAIL` on each that misses the bar, a totals line, and `N of M selected
  operations fail the bar`. It prints no rows; run the single-key form on
  a failing operation to see them.
- `--json`: `{"operations": [...], "totals": {...}, "failing": [...]}`.
  Each entry of `operations` is byte for byte the object `source-coverage .
  OP-KEY --json` prints. `totals` holds `selected`, `passing`, `failing`,
  `errors` and the summed `response` and `request` counts; `failing` lists
  the operation keys.
- `--check`: exits 1 when any selected operation fails, with one
  `source-coverage --check: OP fails — …` line per failing operation and a
  count line on stderr.
- An operation the classifier cannot build a report for (a selected key
  missing from `inventory.json`) is listed with its error (`{"op_key",
  "error"}` in `--json`), counted failing, named with its error on stderr,
  and makes the run exit 1 with or without `--check`. A selection that
  includes no operation, or a workspace with no `selection.yaml`, exits 1:
  nothing checked is not a pass.

**Stale omits.** An `omits` entry on a resolved decision or a
current finding can outlive the reason for it: the schema now maps the path, a classifier
upgrade now reads a `->match` it once reported `unresolved`, the envelope
now reads the path (for an `editorial` entry), or a refreshed source no
longer offers the path or the operation. Such an entry is **stale**:
`source-coverage` counts it per direction as `stale-omit N` (JSON
`stale_omit`, only when nonzero), lists it after that direction's rows as
`stale omit: D-id omits `path` (direction) on OP, but …` (JSON
`stale_omits`: `decision`, `operation`, `direction`, `path`, `why` —
`mapped`, `consumed`, `not-offered` or `no-operation` — `message`, `fix`),
and with no OP-KEY lists every stale entry in the workspace, on any
operation, selected or not. It is **not part of the bar**: a stale entry
leaves no offered path unaccounted, so `--check` does not fail on it.
`lint` warns `stale-omit` on each, naming the decision and the row. Fix it
through the log, never by hand: `graphos-factory-core decisions supersede .
--id D-id`, then record any of its omits that still apply on a new
resolved decision (for a finding, `graphos-factory-core findings supersede .
--id F-id` and a new finding). An entry is only reported when staleness is known: a
row it covers that is `unresolved` or `unverified-default` counts as
needing it.

**Expansion boundaries.** A response property whose inventory
node carries `x-expansion` is a relationship to another node, and the walk
stops there instead of unfolding the target's graph:

- **unexpanded, verified default:** it offers exactly the default leaves
  (`business.id`), mapped or omitted like any leaf;
- **unexpanded, `unverified`:** it offers one `unverified-default` row.
  Nothing in the workspace clears it; verify the default (a raw probe of the
  unexpanded field, or version-specific documentation), record it with its
  evidence where the source document is generated, and refresh;
- **expanded on the wire** (the fields default or literal carries
  `business{…}`): it offers what the expression requests, so a requested
  child you do not map is `unaccounted`.

To expose a child beyond the default, put the group in the fields default
(§ Sparse fieldsets). Mapping the child without it is
`transport-expansion-missing`. An operation with no fields parameter (any
POST) cannot ask at all: expose such a child only when a resolved decision
names the operation and records the path, as a backtick span
(`` `owner.name` ``), as what the source is verified to send. A GET that
takes and sends the fields parameter gets no such exemption; its fix is the
group in the default.

**The classifier reads the forms this skill recommends**:
- `map->entries` over a dictionary maps the dictionary's row;
- `field->match([from, to], …)` on a scalar maps `field`, as value translation
  (over an object or array, without a sub-selection, it stays unresolved:
  an arm can send any part of the value);
- `field->map(@->match(…))` over an array of scalars maps `field`, the same
  translation applied to each element; anything else inside the
  map, or a method after it, stays unresolved. In a request body it is still
  unresolved, as every request-side `->match` is;
- a nested object literal in a request body is read key by key;
- an argument sub-selection (`key: $args.x { wire: field }`) is read wire
  key by wire key;
- a request body that is one `$args.<name>` expression, with or without a
  sub-selection (`body: "$args.input"`, `$args.input { Wire: field }`), is
  classified at the request root; a body that follows that
  expression with `key: expr` pairs is not, so write one form or the other;
- a deeper argument path (`$args.a.b`) forwards the field it names;
- a `...` spread of `disc->match(…)` arms, the abstract-type form
  ([mapping-language.md § Abstract types](mapping-language.md#abstract-types)),
  maps the discriminator and each arm's fields. Any other spread leaves every
  path under its object that the selection does not otherwise map
  `unresolved`.

An `unresolved` row names the construct the classifier does not read, for
example `request expression not parsed: ->map->first` or `selection method
not parsed: ->entries->first`. Such a row still comes from the classifier's
grammar, not from the inventory. Never hand-edit `inventory.json` to make
one go away: it is facts, and `lint` reports an edit to it
(`unacknowledged-inventory-edit`). Instead:
- keep the idiom;
- record a finding naming the operation, the unresolved paths, and the
  grammar that leaves them unresolved (`findings add --cites …`: the
  classifier's grammar settles it, nobody chose it);
- report the operation as not verified by this layer (e2e and conformance
  still prove it), never as done.

Only a dropped spec construct or a depth-limit marker points at the source
document. That is fixed in the pinned working copy (`codify --source`),
never in `inventory.json`.

An `unaccounted` leaf is not a lint nit: it is a field the source returns
that no caller can ever see, and nobody decided that.

Clearing one has exactly two honest endings — map the field, or record why
you did not. Leaving it off on your own judgement is a decision, with
exposing it as the alternative:

```bash
graphos-factory-core decisions add . --title "Drop the internal audit block from candidate reads" \
  --question "Expose results.auditTrail on post:/candidate.info?" \
  --choice 'omit:leave it off' --choice 'expose:map it as a field' \
  --resolved --chosen omit --note "Internal-only; no caller has asked for it." \
  --omit 'post:/candidate.info|response|results.auditTrail|editorial'
```

A path an expression reads is a fact, not a call — a finding:

```bash
graphos-factory-core findings add . --title "success is read by the @source error mapping" \
  --body "The errors block reads success on every operation; it is not a field." \
  --cites "references/schema-authoring.md § Errors" \
  --omit 'post:/candidate.info|response|success|consumed'
```

`--omit operation|direction|path|reason` is repeatable on both; `direction` is
`response` or `request`, `reason` is `editorial` (deliberately not exposed;
a decision only — `findings add` refuses it)
or `consumed` (used by an expression, not surfaced as a field). An omit on
a parent path covers its children, and never matches by type name — it is a
path on one operation. `.` is the root path, the whole direction: it is the
only way to record an EmptyResponse 204, whose one offered row sits at the
empty root (`--omit 'delete:/ecommerce/stores/{store_id}|response|.|editorial'`). The classifier reads these records back, so the same
record that justifies the gap is what closes it. Never widen
an omit to silence a leaf you have not actually considered; that converts a
finding into a lie the next `--check` will not catch.

## Writes

A write operation gets the same care as a read plus two things: an explicit
`graphql.root: mutation` in `selection.yaml`, and a hand-authored WireMock
case, because the unit layer cannot assert an object-valued argument at all
([testing.md](testing.md)). A tag an operation needs (`tags: [beta]`) is
set in `selection.yaml` at selection time, not later.

### Copy and update workflows

A copy or clone operation reads one object and creates another. The caller
must explicitly carry over any field affecting behavior or presentation —
provider defaults for omitted optional fields are not "the source object's
values". Identifying behavior-affecting fields: booleans and enums on the
read shape that are also writable on the create or update request shape
(e.g. `pinned`, `archived`, `starred`, `visibility`, `status`, `locked`,
`draft`); `readOnly: true` marks fields the API never accepts on write.
When the source metadata's description names the field's effect, surface it
in the doc comment. Copy and clone descriptions must: (1) state they create
a new object from a source; (2) list behavior-affecting fields to carry over
explicitly, warning that omitted fields take provider defaults; (3) when the
operation takes a full input object, warn unset keys default and do not
mirror. Example: a synthetic notes API — GET /notes/{id} returns `{ id,
title, content, pinned, archived, color, created_at }`, POST /notes accepts
`{ title, content, pinned?, archived?, color? }`. The copy operation's
description: "Creates a note. To copy an existing note, read it first and
pass its title, content, pinned, archived, and color values. Fields omitted
from the request take provider defaults (e.g. pinned: false), not the source
note's values." The e2e case for a copy flow must demand the preserved field
in the outbound body — see [testing.md](testing.md).
