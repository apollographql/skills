# The Apollo Connectors language

What `@source` and `@connect` can express, and the shapes that recur in every
connector. The mapping language that goes *inside* them (`selection`, `body`,
`queryParams`, the methods, the null operators) is
[mapping-language.md](mapping-language.md).

The hosted GraphOS MCP server's `ApolloConnectorsSpec` tool has worked
examples worth reading, but it is written for `connect/v0.3` and
federation 2.12. Some of its rules (every literal needs `$( )`, a bare-brace
body does not compose) hold only at v0.3, and its `rover connector run` step
is not evidence ([testing.md](testing.md)). Where it disagrees with this
file, this file wins.

## Linking the spec

```graphql
extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.15", import: ["@key", "@shareable", "@tag"])
  @link(url: "https://specs.apollo.dev/connect/v0.4", import: ["@source", "@connect"])
```

That is the target: `connect/v0.4`, composed at `federation_version: =2.15.2`,
served by Apollo Router 2.17. Since Router 2.18.0, v0.4 is no longer a
preview version (Router 2.16.0 and later need no opt-in for it). Never link `connect/v0.5` unless the user asks for it
([v0.5](#v05-preview-do-not-link)). A workspace created before the move may still
link `federation/v2.12` and `connect/v0.3` at `federation_version: =2.12.0`
until someone moves the pin
([mapping-language.md](mapping-language.md#moving-a-workspace-from-v03-to-v04)),
and a workspace can keep an older `federation/` link than its pin by recording
it as `federation_spec_version`.

The connect version and the federation version are both pinned in
`.factory/workspace.yaml`; `graphos-factory-core lint` fails when the schema drifts
from either pin, and `graphos-factory-core render` fails when `supergraph.yaml` and
`workspace.yaml` disagree. The `federation/` link can be no newer than
`federation_version`, and a newer one fails composition in one of two ways: at
2.12.0, `INTERNAL_ERROR` with `Unexpected federation version: 2.15`; at
2.14.0, `Unknown directive "@source"`, naming the connect directive when the
fault is the federation link. The same `Unknown directive "@source"` appears
at 2.12.0 with `federation/v2.12` and `connect/v0.4`, where the connect link is
the cause. A federation pin is part of the test, not incidental: the same
schema can compose at 2.12 and fail at 2.15 with a named build error the older
composer masked. Quote the pin whenever you
quote a compose result.

## `@source`

One per schema. The core's layers render one `@source`, and a target may
make that a hard limit for its deployment (its contract reference says
why), so treat it as one, not a style preference.

```graphql
@source(
  name: "widget_co"
  http: {
    baseURL: "{{BASE_URL}}"
    headers: [
      { name: "Authorization", value: "Bearer {{AUTH_EXPR}}" }
      { name: "User-Agent", value: "widget-co-connector" }
    ]
  }
  errors: {
    message: "$($.error.message ?? 'Widget Co request failed')"
    extensions: """
    httpStatus: $status
    """
  }
)
```

`errors` maps a non-2xx body into the GraphQL error. The path above
(`$.error.message`) is this one API's documented error body, not a
template — take the actual path from what the API's spec documents for
its error responses, never copy a path from another connector or from a
different API's convention (`.detail` is FastAPI's default; plenty of APIs
use it, plenty don't). [schema-authoring.md § Errors](schema-authoring.md#errors)
says how: read the selected operations' `errors[]` in
`.factory/inventory.json`, follow each `shape_ref` into `shapes`, and write
the path that shape actually carries. Give the message expression a `??`
fallback: most APIs document a JSON error body for some statuses and
nothing at all for others (401, 408, 429 are the usual bare ones), and
without a fallback those produce an empty message.

## `@connect`

On a root field:

```graphql
type Query {
  widget_co_listWidgets(limit: Int, cursor: String): Widget_Co_WidgetList
    @connect(
      source: "widget_co"
      http: {
        GET: "/widgets"
        queryParams: """
        limit: $args.limit
        cursor: $args.cursor
        """
      }
      selection: """
      widgets {
        id
        createdAt: created_at
      }
      nextCursor: page_info.next_cursor
      """
    )
}
```

- **Methods**: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, each taking the URI
  template as its value. Path variables interpolate expressions:
  `GET: "/widgets/{$args.id}"`.
- **`queryParams`** is mapping entries separated by whitespace, not GraphQL
  — one per line in every pilot, and several on one line
  (`a: $args.a b: $args.b`) is the same block to the router and
  to the lint rules and `scaffold` that read it. A null-valued
  entry is omitted from the request.
- **`headers`** is a GraphQL list of `{ name, value }` objects, the form the
  `@source` example above uses; a value may interpolate an expression
  (`headers: [{ name: "From", value: "{$args.from}" }]`).
- **`body`** builds the request payload, usually a literal object whose keys
  are the API's wire names:

  ```graphql
  body: """
  {
    channel: $args.channel,
    text: $args.text,
    thread_ts: $args.threadTs
  }
  """
  ```

  At v0.3 the braces must be wrapped as `$({ … })`; the wrapped form is valid
  at both versions.

  **A null argument is sent, not dropped, unless the member guards it.** An
  argument left out leaves its key out; an explicit `null` is sent as JSON
  `null` (`title: $args.title`) or, through `->map({ id: @ })->first`, as
  `{id: null}` (measured on the router, pagerduty and gitea). `$args.x?`
  drops the key when the value is null or absent and nothing else: an empty
  string, an empty list, `false` and `0` go through, and a null nested inside
  an object the argument keeps stays. Write `$args.x?->map(…)->first` to drop
  a wrapped member on a null too. Use it where the source description does
  not allow a null at that key.

- **`selection`** maps the response into the field's type. It is a shape,
  not a query: `alias: source_path` renames, nesting descends, and a field
  named identically on both sides is written once. Every field of the
  return type must be reachable in the selection or compose fails.
- **A method on a leaf must be aliased.** `size: size->jsonStringify` maps a
  64-bit number onto a `String` field and composes; the bare
  `size->jsonStringify` is rejected with `INVALID_SELECTION: SubSelection
  cannot contain multiple elements if it contains an anonymous
  NamedSelection` (rover 0.41.0, connect v0.3) — the name a method produces
  is anonymous, so the selection has to give it one. It applies to every
  method, and to a subselection too: deck-of-cards writes
  `piles: piles->entries { … }`, never `piles->entries { … }`. A method inside
  `queryParams` or `body` is a different position and needs no alias
  (`cards: $args.cards->joinNotNull(",")` is the entry's own key).
- **A method does not skip a `null`; `?->` and `->match` do.**
  `size->jsonStringify` on a JSON `null` produces the four-character string
  `"null"`, not `null`. Every form, run through Apollo Router 2.17 with a
  `{ "size": null }` body (the same at connect v0.3 and v0.4):

  | Written | null body | `27` body |
  |---|---|---|
  | `size->jsonStringify` | `"null"` | `"27"` |
  | `size?->jsonStringify` | key omitted from the mapped object | `"27"` |
  | `$(size?->jsonStringify ?? null)` | `null` | `"27"` |
  | `size->match([null, null], [@, @->jsonStringify])` | `null` | `"27"` |

  Both null-preserving forms resolve their path **relative to the enclosing
  subselection**, not to the response root. Prefer the `->match` form:
  `reconcile` reads `alias: path->method(…)` as a mapping of `path`, but does
  not read a `$(…)` expression block that way, so a `$(…)`-wrapped leaf is
  reported as `renamed by the selection but the connector does not map it`
  and counted in `selection says all fields; N not mapped`.

## Expression variables

| Variable | Available in | Notes |
|---|---|---|
| `$args` | root-field connectors, and a field-level connector's own declared arguments | the field's arguments; a relationship field (§ Relationship fields) declares only the per-call credential argument its by-id root field declares, and none under source-level auth |
| `$this` | connectors on a non-root type | the parent object, so sibling fields are reachable; for an entity, the key fields it references become the key |
| `$batch` | batch connectors | the collected keys |
| `$config` | anywhere | values the router config supplies |
| `$env` | anywhere | process environment |
| `$context` | anywhere | request context, e.g. the caller's own credentials |
| `$status`, `$` | `selection`, and `errors` on `@connect` or `@source` | HTTP status and the response body |

`rover connector test` injects `$args`, `$this`, `$batch`, `$config` and
`$context` — but **not** `$env`. That is why `scripts/unit.sh` rewrites
static `{$env.NAME}` to `{$config.NAME}` in a temporary copy of the schema
and the suites supply `config.common.variables.$config` (`unit.sh` fails,
before rover runs, a suite with cases that lacks one, naming it). Exporting the
variable into rover's process does not help. Only a real router run proves
`$env` or `$context` injection.

## Entities

A type-level `@connect` plus `@key` makes a type resolvable on its own, so
another subgraph can reference it:

```graphql
type Widget_Co_Widget
  @key(fields: "id")
  @connect(
    source: "widget_co"
    http: { GET: "/widgets/{$this.id}" }
    selection: "id name"
  ) {
  id: ID!
  name: String
}
```

`@key` is what makes the type an entity. **The connector's own key is derived
from the variables it references** (`Connector::resolvable_key`): `$this` for
a field-level or type-level connector, `$batch` for a batch one, `$args` for
`@connect(entity: true)` on a `Query` field. That derived key decides which
`@key` the connector can resolve, not whether the federation key exists. The
example's connector resolves `id` because the URI interpolates `$this.id`.

Validation runs in one direction only, which is what makes this worth knowing:

- A hand-written `@key` that **no** connector can resolve fails loudly, with
  `MISSING_ENTITY_CONNECTOR`. Writing `@key` commits you to resolving it.
- A type-level `@connect` **without** `@key` is silent. It composes to a
  keyless type no other subgraph can reference (one that tries fails with
  `INVALID_FIELD_SHARING`): it looks like it worked and buys nothing.

Lint checks every `@key` type: it needs a lookup by each
resolvable key, one full key wherever a connector's selection embeds it,
something that returns it, and a connector mapping each of its fields. A
`@key(fields: "id", resolvable: false)` stub, which references another
subgraph's entity, needs no lookup and no field connectors. The embedding is
read through the selection, so `pet { id: pet_id }` carries `id`.

Only make a type an entity when a decision records why in `decisions.json`
(`graphos-factory-core decisions`); entities widen the supergraph's contract.

### At v0.4, a `Query` connector can hijack entity resolution

Suppose an entity has a type-level `@connect` that resolves it from `$this`
or `$batch`,
and a `Query` field `@connect` (mapping from `$args`, without
`entity: true`) also returns that type. At v0.4 the router may resolve
references to the entity through the `Query` connector. `$args` is empty
there, so the request goes out without its parameters and fails, usually as
a `400` reported as `CONNECTOR_FETCH`. v0.3 does not do this, so changing
only the `@link` to v0.4 can break a schema that worked.

The fix ([router#9853](https://github.com/apollographql/router/pull/9853))
is not in a release yet; Router 2.18.0 does not have it. Whether a given
schema misroutes is up to the query planner, so a passing run does not
prove it is safe. An e2e case whose stub for the entity's own connector is
`x-required` catches it ([testing.md](testing.md)).
[Finding a `$batch` candidate](#finding-a-batch-candidate) has a case where
it happened.

## Relationship fields

A response property that carries another resource's id (`album_id` on a
song, `owner_id` on a widget) becomes a field on the type that carries it,
resolved by that resource's GET-by-id operation through a **field-level**
connector keyed by `$this`:

```graphql
type Widget_Co_Widget {
  id: ID!
  owner_id: ID
  """
  The Widget_Co_Owner referenced by `owner_id`, fetched by the router through get:/owners/{ownerId}, one request per Widget_Co_Widget that selects it; select this instead of calling Query.widget_co_owner per item.
  """
  owner: Widget_Co_Owner
    @connect(
      source: "widget_co"
      http: { GET: "/owners/{$this.owner_id}" }
      isSuccess: "$($this.owner_id ?! 0)->match([null, true], [@, $status->gte(200)->and($status->lt(300))])"
      selection: """
      $($this.owner_id ?! 0)->match([null, null], [@, $ {
        id login
      }])
      """
    )
}
```

(`owner_id` is nullable, so the field carries the null guard below; with
`owner_id: ID!` it is the plain `selection: """id login"""` and no
`isSuccess`.)

What it is and is not:

- **No `@key`, no `entity: true`, no type-level `@connect`.** The field is
  ordinary; only the connector's key is `$this` (`resolvable_key`, § Entities).
  Nothing about the type becomes referenceable from another subgraph, and no
  decision is needed to add one. `$this.<fk>` names the host's GraphQL
  field (`owner_id`, or `ownerId` when the schema camelCases it), so the
  host must declare the foreign key it reads.
- **Up to one request per parent.** The router calls the by-id operation
  for each parent object that selects the field; nothing is batched. That
  is up to one request per parent (50 songs selecting `album` is up to 50
  requests; the router may deduplicate identical representations). Say so
  in the field's doc comment, as the printed text does. When the fan-out is
  the problem, the `$batch` entity form below is the answer, and that one
  needs a decision.
- **The credential mirrors the by-id root field's.** A relationship field
  authenticates exactly the way its by-id operation's own root connector
  does, and `link-credential` is the lint error for any difference. When
  that connector authenticates only through `{{AUTH_EXPR}}` on the one
  `@source`, as above, the field declares no argument and no header — a
  `headers:` block, a `{$args.…}` or a credential-named argument on it
  would open a second credential path. When the root connector carries a
  per-call credential — an argument interpolated into a header or a query
  parameter, as every AppWorld service does, since it has no global
  credential and a type-level `@connect` sees only `$this` — the field
  declares the same argument (same name, same type, same nullability) and
  sends it the same way:

  ```graphql
  owner(access_token: String!): Widget_Co_Owner
    @connect(
      source: "widget_co"
      http: { GET: "/owners/{$this.owner_id}", headers: [{ name: "Authorization", value: "Bearer {$args.access_token}" }] }
      selection: """id login"""
    )
  ```

  when `Query.widget_co_owner(ownerId: ID!, access_token: String!)` sends
  `Bearer {$args.access_token}`. A missing, renamed, retyped or re-slotted
  argument fails authentication at runtime and is the lint error. The
  value may be an expression over the argument rather than a bare
  `{$args.<a>}` — an optional token sent with the null-preserving form
  `{$args.access_token->match([null, null], [@, $(['Bearer', @])->joinNotNull(' ')])}`
  is still the credential — and the field then declares the argument as
  nullable as the root does and sends the same expression verbatim. `links
  apply` refuses (`no-root-field`) a query credential it cannot copy
  exactly: one sent through a `queryParams` entry that is not exactly
  `$args.<a>`, or a URI pair that also reads an argument that is no
  credential. Write that field by hand, and note that `link-credential`
  compares a query credential by parameter name only. A query
  parameter is a credential when its name reads as one in whole words
  (`access_token`, `x-api-key`, `private_token`, `client_secret` — never
  `pageToken`, `sort_key` or `csrf_token`). `links apply --dry-run` prints
  whichever form applies. Either way the field adds no `@source(`: a
  header on a field-level `@connect` is not a source.
- **The selection is the by-id operation's, verbatim.** Copy the root
  field's `selection` unchanged so both fetch the same shape; reconcile
  compares both against the same operation. The root connector's static
  settings come along too — a static query pair on its URI
  (`?format=full`), every header that reads no `$args` (`Accept`) and
  every `queryParams` entry that reads none (`format: $("full")`) — so both
  reads fetch the same representation; an optional argument that is not
  the credential does not, nor does a constant `Authorization` header,
  which would open a second credential path.
- **A nullable foreign key carries the null guard.** Nothing
  in Connectors skips a field-level connector: for a parent whose fk is
  null the router still sends the GET, with an empty final segment
  (`GET /owners/`), once per distinct null parent. What answers it is
  whatever that path is — AppWorld answers 307 with an empty body, so
  every null parent failed with `CONNECTOR_FETCH` (Spotify
  `Spotify_QueueSong.album`: 6 of 7 queue songs; Splitwise
  `Splitwise_GroupsBalanceBreakdownEntry.group`: the "Non-Group Entries"
  row); a list endpoint answering 200 is worse, because the selection
  maps it into a record nobody referenced. So for an fk the host declares
  nullable, `links apply` prints two guards, and both are needed:
  `isSuccess` accepts any answer when `$this.<fk>` is null (otherwise the
  one `@source`'s `isSuccess`, or 2xx, decides, as before), and the
  selection maps to null when `$this.<fk>` is null, whatever the body
  holds. Under connect/v0.4 the selection goes inside the match arm
  (`[@, $ { … }]`, above); composition rejects the other form's nested
  objects there (`cannot find field`). Under connect/v0.3 it follows the
  match as a subselection (`…->match([null, null], [@, $]) { … }`), the
  only form v0.3 composes. `?! 0` reads the fk: `?!` supplies `0` only
  when `$this.<fk>` is absent, which the router never does (a null fk is
  carried as null), but `rover connector test` gives the response side no
  `$this` at all, and without the fallback every unit entry for the field
  would take the null branch. `links apply` refuses **`nullable-fk`** when
  the guard cannot be written: connect/v0.2 and earlier have no `?!`, and
  under connect/v0.3 a by-id selection holding a value that reads no
  response (`$("…")`, `$args`, `$this`, …) would survive a null parent as
  a record of nothing. A non-null fk (`owner_id: ID!`) prints no guard.
  Lint's `link-null-guard` warns on a relationship field whose nullable fk
  lacks either guard and names the missing half; re-print the field and
  paste its `isSuccess` and `selection`. Only make the fk non-null in the
  host type when the API guarantees it on every parent.
- **Only the GET-by-id template is a relationship field.** Reconcile and
  lint read a field-level `@connect` as one when it is a `GET` whose one
  `{$this.<fk>}` is the whole final path segment (a trailing `/` or an
  extension such as `.json` allowed). Any other field-level connector — a
  sub-resource read (`/repos/{$this.owner}/{$this.name}/issues`), a read
  past the id (`/x/{$this.id}/receipt`), a write — is listed under
  `field_connectors` and checked for nothing else.
- **It is a selection judgement, never a hand edit.** The `links:` entry in
  `selection.yaml` ([workspace-contract.md § `links`](workspace-contract.md#selectionyaml))
  is what makes the field expected: `graphos-factory-core selection draft`
  proposes one per `candidate_entity_link` fact with `confirmed: false`, you
  confirm it with the user, and `graphos-factory-core links apply . --dry-run`
  prints the field text above for you to paste into the host type. The
  crate never writes the schema. A field with no included entry is
  `links.remove` drift; a confirmed entry with no field is `links.add`.

`links apply` refuses a confirmed entry it cannot print, and names the
kind. Four of them only the authored schema can tell you:

- **`circular`** — the by-id selection, copied onto the host, selects back
  into a type already on its path, in practice the host (the album read
  copied onto `Spotify_Track.album` selects `songs { … }`, which are
  `Spotify_Track`s). The check walks only what that selection selects: a
  field it does not select never makes a link circular, even one with its
  own `@connect` such as the opposite link (`Widget.owner` and
  `Owner.favoriteWidget` both print, whichever is pasted first); a field it
  does select is walked even when it has its own connector, because rover
  rejects that re-entry too. The error rover reports depends on what is
  pasted (rover 0.41.0, supergraph plugin 2.15.2, on copies of the AppWorld
  amazon and spotify workspaces): the field with the null guard `links
  apply` prints for a nullable fk fails `GRAPH_QL_ERROR: No matching shape
  found for selection`; only the unguarded field fails `CIRCULAR_REFERENCE
  … type X appears more than once in …`. The refusal message names only
  the second. All 5 AppWorld refusals were correct. Amazon's 4
  (`[]>variations[]>product_id` onto `Amazon_Product_Variation.product`)
  are a child linking to its own parent: `Amazon_Product.variations` is
  the host itself, one shared type by workspace decision. Spotify's 1
  (`ShowPlaylistResponse` `songs[]>album_id` onto `Spotify_Track.album`)
  is a host reached through another parent: `Spotify_Track` is shared by
  `AlbumDetails.songs` and `PlaylistDetails.songs`. `links apply` keeps
  refusing it. What does not work:
  - **Trimming the copied selection** at the back-edge: a shared return
    type needs every field resolvable from each connector returning it, so
    composition fails `SATISFIABILITY_ERROR`.
  - **`@shareable`**: no change.
  - **The entity form** in one subgraph (`@key`, a type-level `@connect`,
    key stubs): `CIRCULAR_REFERENCE` and `GRAPH_QL_ERROR` both.
  - **`fields.exclude` of the back-edge** — what the refusal message
    suggests — composes, but drops the field from every reader of the
    shared type: on spotify `album.songs` from `showAlbum` and from 13
    album links; on amazon it removes the host itself. Take it only when
    no reader needs that field.

  **Only a type split composes and keeps the relationship.** Split the
  **target** when the host is the target's own child (amazon: `product:
  Amazon_VariationProduct`, whose `variations` is a new type with no link;
  composes exit 0, and live variation 198 resolved product 198, the same
  as curl). Split the **host** when it is reached through a different
  parent (spotify: `Spotify_PlaylistDetails.songs: [Spotify_PlaylistTrack]`,
  the new type carrying the link; composes exit 0, not run live). The
  AppWorld harness schema composes for the same reason: its generator
  mints one type per response
  (`Amazon_AmazonProductsByProductIdResponseVariationsItem`). A split is an
  authoring decision, not a `links apply` output: record it (`decide:`,
  `graphos-factory-core decisions add …` with declining the link as its
  alternative, D-id; it overrides any shared-type decision), paste the field by hand, and give it its own unit entry, e2e
  case, null-parent case and live case. Until those exist it is not
  validated. Otherwise decline the link (`include: false` with a
  `reason`).
- **`no-fk-field`** — the host type declares no field for the foreign key
  (its root field's selection left the property out), so `{$this.<fk>}`
  would read nothing and composition fails. Include the property in the
  selection and apply it before the link.
- **`nullable-fk`** — the host declares the fk nullable and the null
  guard cannot be written for this schema (connect/v0.2 or earlier, or a
  by-id selection holding a body-free value under connect/v0.3); the
  refusal states the empty-segment GET a null parent would send. Move the
  schema to connect/v0.4, or drop the value from the by-id selection.
- **`field-exists`** — the host already declares a field of the derived
  name, or an earlier entry in the same run prints that name on the same
  host for another relationship — through another operation, or keyed by
  another foreign key; the refusal names both. Set a distinct `field:` on
  one of the two entries (another camelCase name).

The rest are about the entry or the operation behind it: **`self`** (the
by-id operation returns the host type itself — a list item and its detail
read given one GraphQL type: decline the link or split the two types),
**`no-host`** (the entry's shape or path does not resolve — fix the entry —
or no included operation's root field returns a type for the shape yet)
**`target-refused`** (the entry is stale — see below — so the field is
not to be pasted; the refusal carries lint's `link-target-refused` reason
and remedy, and names the field to remove when it is already pasted)
and **`no-root-field`** (the operation is unknown, excluded or not a GET,
or no Query field carries a connector to it: include and apply the by-id
operation first — it is the field's provenance, and lint's
`link-operation-excluded` says the same). Several Query fields on one
`/{id}` path are settled by the root field the selection names for the
operation, or refused. An entry whose field is already there is
skipped as applied, and two entries whose shapes the schema gives one type
print that field once only when they are the same relationship — one
operation keyed by one foreign key.

**A confirmed link the current rules no longer back is stale.** The rules
that make a `candidate_entity_link` fact change — the inventory now
refuses a GET-by-id whose response does not carry the key its
path parameter names, or that returns a list — and a rebuilt inventory
drops the fact, or an old inventory keeps a fact whose target
`inventory links` now lists under refused targets. The `links:` entry
stays as it was. Lint's **`link-target-refused`** names each confirmed,
included entry whose by-id operation is refused (the reason is
`inventory links`' own) or that no fact at its shape, path and operation
backs: an **error** once the field is pasted — the schema serves a field
that cannot resolve (AppWorld splitwise: 35 pasted `person` fields
through `get:/splitwise/balance/person/{email}`, which reads the balance
with that person and answers 422 for the caller's own email) — and a
**warning** before. Reconcile reports the
entry as `links.change` drift (`~`, `stale: true`) with the reason, and
never as `links.add`. `links apply --dry-run` refuses it
**`target-refused`** with the same reason: it prints nothing
for the entry, pasted or not, and exits 1.

A stale link **raises a decision**: an open record for the
field with the refusal reason as its `context`, choices `keep` and `drop`,
and `affects: [Type.field]`. Reconcile and lint print the exact `decisions
add` command in their fix text; run it, name the record on the entry
(`decision: D-k7m2qx`, the id `add` printed), and settle it with the user (a host UI, if any, shows
the open record). While it is open the entry
stays drift, lint keeps reporting it and `links apply` keeps refusing it.
Then:

- **`drop`.** Set `include: false` on the entry with a `reason` that cites
  the decision (quote the refusal). If the field is pasted, remove only
  that field — its doc comment and `@connect` — from the host type, and
  only the unit entry (`target: "<Type>.<field>"`), e2e case and stubs you
  wrote for it, on the next apply. Edit; never regenerate the schema or the
  suite. Reconcile then reads in sync.
- **`keep`.** When the relationship is real and the rule is what misses it
  (gitea's `User` spells the key `login`, so `RepositoryMeta > owner ->
  get:/users/{username}` has no fact), resolve the decision `keep`. An
  entry whose `decision:` names its decision resolved `keep` in
  `.factory/decisions.json` draws no finding and no drift, and `links
  apply` prints it as it prints any other (gitea's D-0018); an `open`
  decision, an unknown id, a finding or a bare `reason:` does not keep it.
  The field still needs its unit entry and e2e case.

**Testing a relationship field (by hand, for now).** `scaffold`
drafts no test for a link field, and `evidence/latest.json` has no row for
it, so every layer can pass while a pasted field has never run. Lint's
`link-untested` warns on each relationship field that lacks a
unit entry targeting it or an e2e case selecting it on its host type,
naming the one missing or both, and `evidence` prints the same fields after
its layer table; `link-null-untested` and `link-live-unaccounted`
(below) cover the null-parent case and the live layer. A workspace with no suite still lacks the unit entry. A
fragment no operation spreads, a selection under a literal `@skip(if:
true)` or `@include(if: false)`, and a commented-out `target:` line are not
coverage. Write both tests by hand. In the workspace's
`tests/<svc>.connector.yaml`, add a unit entry with `target:
"<Type>.<field>"` and `variables: { $this: { <fkField>: <sample> } }` — the
host's GraphQL field the connector reads — plus `$args: { <credential>:
<sample> }` under per-call auth; `expect.connectorRequest` asserts the
method, the URL with the sample id and the credential header, and an
`apiResponseBody` / `connectorResponse` pair proves the mapping back:

```yaml
  - name: "Widget_Co_Widget.owner relationship field"
    target: "Widget_Co_Widget.owner"
    variables:
      $this:
        owner_id: "o-7"
    apiResponseBody: |
      {"id": "o-7", "login": "octo"}
    expect:
      connectorRequest:
        method: GET
        url: https://api.widgets.test/owners/o-7
        headers:
          authorization: Bearer test-token
      connectorResponse: |
        {"id": "o-7", "login": "octo"}
```

Then write one e2e case: a `tests/cases/<case>.graphql` that selects the
parent root field and, inside it, the new field (passing the credential
argument to the nested field under per-call auth), the parent's stub
carrying a foreign-key value, and a second WireMock mapping for the by-id GET
keyed on that value (`"urlPath": "/owners/o-7"`); `e2e.sh --generate`
writes its expected response — read it. Both forms ran green with rover and
the router on a copy of the AppWorld Spotify workspace (a
`Spotify_PlaylistReview.playlist` unit entry with `$this` and `$args`, a
`Spotify_LibrarySong.album` e2e case), and the gitea pilot carries one on
every CI run: `Gitea_RepositoryMeta.ownerUser`, with a unit entry, an e2e
case answered by the parent's and the by-id read's existing stubs (each
lists the case in `x-cases`; a second stub on the same request would be a
`fixture-collision`) and a live case whose `require` holds the fetched
record's key equal to the foreign key.

**A nullable fk needs a null-parent e2e case too.** The parent's
stub returns at least one item whose fk is `null` beside one that carries a
value, and a second mapping answers the empty-segment GET the null parent
produces (`"urlPath": "/owners/"`) the way the API does — measure it with
curl (AppWorld: `307`, `Location` without the slash, empty body). The
expected response has the field `null` on the null parent and no `errors`.
Without the guard this case fails with `CONNECTOR_FETCH`; without the
mapping it fails as an unmatched request, which is the same defect seen
from WireMock. The unit layer cannot carry this case: `rover connector
test` renders a null `$this.<fk>` as `/owners/null` and gives the response
side no `$this`, so the null parent is proven at e2e and live only. Live,
a `require:` that selects both kinds of parent says it: `[… |
select(.owner_id == null)] | length > 0 and all(.owner == null)`. Report a
confirmed link whose field has no unit and no e2e case, or whose nullable
fk has no null-parent e2e case, as **not validated**, whatever the evidence
file says. Lint's `link-null-untested` warns on a field that has
an e2e case but no null-parent one: no mapping answers `GET` (or `ANY`) on
the empty-segment path, as `urlPath` or `url` (a query string allowed),
while serving — by `x-cases`, `x-shared` or its file name — a case that
selects the field on its host type. Fixture paths are connector-relative,
so a base URL carrying a path (gitea's `/api/v1`) still stubs `/users/`.

**Live, a relationship field is a case or a `field:` exclusion.**
`evidence/latest.json` has no row for a link field, so
`live-unaccounted` cannot see one. When `tests/live.yaml` exists, lint's
`link-live-unaccounted` warns on every relationship field that no listed
case's `tests/live/<case>.graphql` selects on its host type and no
exclusion names:

```yaml
exclusions:
  - field: "Venmo_MessagePaymentCardId.paymentCard"
    reason: "its only parent is venmo_addPaymentCard, a write; no write is sent live"
```

Each entry names exactly one of `operation:` or `field:` (both or neither
is `live-exclusion-malformed`, and `live.sh` fails on it); a `field:` that
is no relationship field is `live-exclusion-unknown`. An operation
exclusion whose reason mentions the field does not exclude it. `live.sh`
prints `EXCLUDED FIELD: <Type>.<field> — <reason>`, and `evidence` names
the field under "relationship field(s) not validated" with that reason,
beside any `link-null-untested` or `link-live-unaccounted` finding. An
excluded field is never reported as passed live.

### When the entity form is right

The entity form (`@key` plus a type-level `@connect`, § Entities) is for
two cases: another subgraph must be able to reference the type, or the
fan-out of a relationship field has to be batched. Within one subgraph,
prefer a relationship field. Only make a type an entity when a decision
records why in `decisions.json` (`graphos-factory-core decisions`); entities
widen the supergraph's contract.

`list_context` is false on every fact: the inventory refuses a target whose
response is a list. When you find such a list-returning by-id read yourself
(the matched parameter's own operation already returns a list), write a `$batch` type-level connector instead of a
singular `$this` one — the backing shape is already a list, which is what
`$batch` needs instead of unwrapping one item at a time. Check the target
first: such a read can list a collection the key *owns* rather than name
the key's record — before list targets were refused, gitea's `RepositoryMeta > owner` hint
targeted `get:/packages/{owner}`, the owner's packages — and that is no
relationship at all. Point the `links:` entry's `operation` and
`parameter` at the record's own by-id read (`get:/users/{username}`), or
decline it:

```graphql
type Query {
  reviews: [Widget_Co_Review]
    @connect(
      source: "widget_co"
      http: { GET: "/reviews" }
      selection: "id rating product: { id: productId }"
    )
}

type Widget_Co_Product
  @key(fields: "id")
  @connect(
    source: "widget_co"
    http: { GET: "/products", queryParams: "id: $batch.id" }
    selection: "id name"
    batch: { maxSize: 50 }
  ) {
  id: ID!
  name: String
}
```

Each `Widget_Co_Review.product` resolves through `Widget_Co_Product`'s own
connector, called once per batch of `productId`s rather than once per
review.

The relationship field above is the default; this is its batched variant,
and because it is the entity form it needs the decision.

### Finding a `$batch` candidate

Do not guess whether a vendor has a bulk lookup. Run
`graphos-factory-core batch find .` on every build. For each keyed
type it lists the operations that return an array of the type, and whether
one takes a list of the type's key. It also says how the list is passed:

- `repeated`: `?id=1&id=2`, an array query parameter with explode on;
- `comma-separated`: `?ids=1,2`, an array with explode off, a path list, or
  a string parameter documented as comma-separated;
- `space-delimited` / `pipe-delimited`: `?ids=1%202` / `?ids=1|2`, a query
  array with `style: spaceDelimited` / `pipeDelimited`;
- `array`: a JSON array body property, such as Jira's `POST
  /rest/api/3/comment/list` with `{"ids": [...]}`.

It reports a maximum when the key parameter itself documents one (its
`maxItems` or its own description; never the operation's description, and
never a page size), which is the connector's `batch: { maxSize: N }`. The
verdicts are:

- `batchable`: write the type-level `$batch` connector against the reported
  operation.
- `partial-shape`: the only key-list lookups answer with a shape lacking
  some of the type's fields. A batch would fill the entity partly.
- `needs-scope`: the only key-list lookups need another parameter a
  type-level connector cannot supply, such as a path segment
  (`/userprofiles/{id}/…`) or a required filter.
- `style-conflict`: the array is declared repeated, but documented as
  comma-separated. Check which one the vendor accepts before writing either
  form.
- `paginated`: the only key-list lookups are paged lists. One request
  answers one page, so a batch larger than the page silently drops
  entities. Keep the `$this` connector unless the vendor documents that a
  key filter returns every match, and then set `maxSize` to the page size.
- `list-no-key-filter`: list operations exist, but none filters by the key.
  There is nothing to batch against, so a `$this` connector is correct.
- `none`: nothing returns an array of the type.

To batch a type:
1. Set `graphql.batch: true` on its entity operation in `selection.yaml`.
2. Paste the connector `batch find` then prints over the type's header, and
   audit it. Map the object fields it lists by hand, and keep `@key`. No
   instrument writes the schema. The draft's `selection` reads the lookup's
   wire shape: a field the schema renames is written `amenityCategory:
   amenity_category`. When a scalar field has no property of that name or
   of its snake/kebab form, there is no draft, and the note names the
   field; write that selection by hand from the type's other connectors.
   Fields with arguments or their own `@connect` stay out of it.
3. Run `graphos-factory-core scaffold . --op batch:<Shape>`. The case goes
   through a root field whose own connector selects the key alone under the
   reference (`amenities { id }`). A root that maps the entity's other
   fields lets the planner fill them there, so the lookup is never called;
   with no key-only root the case is skipped with that reason. The root stub
   returns references carrying the key alone. The lookup stub demands the
   exact deduplicated key list and is `x-required`
   ([testing.md](testing.md)). Run `e2e.sh --generate`, then the suite. The
   case fails unless the router makes that one request.

The draft is proven at e2e at `connect/v0.3` (federation 2.12.0, router
2.17.0). At `connect/v0.4` (federation 2.15.2, router 2.17.0) the same
scratch copy of the stay-listings fixture failed: the router resolved the references
through another Query connector on the type (`GET /listing/amenities`,
then `GET /amenities/listings` once that field was removed), not through
the `$batch` connector. The cause is a router bug, fixed on `dev` by
[apollographql/router#9853](https://github.com/apollographql/router/pull/9853)
and not yet in a release (Router 2.18.0 does not have it); see
[At v0.4, a `Query` connector can hijack entity resolution](#at-v04-a-query-connector-can-hijack-entity-resolution).
On this fixture a Mutation connector was used too: a read of
`userListings { id amenities { id } }` sent `POST /listings`. v0.3 is not
affected. Until the pinned router contains that commit, a `$batch` draft is
proven at v0.3 only; on v0.4 the `x-required` case catches the misroute.

To decline, set `graphql.batch: false` and record why in `decisions.json`;
lint's `batchable-entity-unbatched` errors until one of the two is done.

`--all-types` also reports unkeyed response types, to find entities worth
keying. `--check` exits 1 while a batchable keyed type has no `$batch`
connector; a schema that does not parse exits 2. It reads the schema's
type-level `@connect` directives, on a type or an `extend type`, so a
`$batch` in a description or comment does not count. The detector matches
on names: a key list named for something
else (`?filter[id]=`, `?q=id:1,2`) is missed, so read the vendor docs when
the verdict looks wrong.

## v0.3 vs v0.4

`v0.4` is the target. Apollo documents its floor as composition 2.14.1 and
Apollo Router 2.15.0; the graph the subgraph joins has to meet both, not
just the pin the layers run at. Commas, bare numbers, unwrapped operator
chains and bare-brace bodies compose at 2.15.1 and 2.15.2 but not at 2.14.0
([mapping-language.md](mapping-language.md#what-your-pin-decides)). It brings:

- **Abstract types**: unions and interfaces mapped from `oneOf` /
  `discriminator`, with a `...` spread of `->match` at a connector's own
  return type ([mapping-language.md](mapping-language.md#abstract-types)).
  On v0.3 a polymorphic payload is a documented JSON scalar
  ([schema-authoring.md](schema-authoring.md)).
- **A looser mapping grammar**: comma-separated selection lists, literals
  written bare after an alias (`kind: "Book"`), operator chains without `$( )`,
  bare-brace request bodies, and `...` spread.
- Not new methods. Methods arrive with router releases, not connect
  versions, but a breaking change to an existing method applies only from
  the connect version that introduced it
  ([mapping-language.md](mapping-language.md#which-methods-run)).

One piece of that grammar changes meaning silently: at v0.3 a quoted string,
`true`, `false` or `null` after an alias reads a property of that name, and at
v0.4 it is a literal. [mapping-language.md](mapping-language.md) has the
details and how to move a v0.3 workspace with `connect-migrate`.

## v0.5: preview, do not link

Router 2.18.0 (2026-09-30) added `connect/v0.5` as a preview spec version.
The router will not start with a schema that links it unless `router.yaml`
sets `connectors.preview_connect_v0_5: true`. Nothing here sets that or has
run a v0.5 schema, so stay on v0.4 unless the user asks for v0.5, and record
the decision.

Its main behaviour change: a response whose shape does not match the
field's type (an object where a list is declared, the reverse, or `null` for
a non-null field) is a `CONNECTORS_RESPONSE_SHAPE` error instead of a silent
`null`. At v0.4 those mismatches pass without an error, so a test has to
assert the mapped values, not just the absence of errors
([testing.md](testing.md)).

## What connectors cannot express

Record any of these as `unsupported` or `needs_review` in the inventory
rather than approximating them:

- A non-JSON response body (NDJSON, CSV, binary, SSE streams).
- Query parameters whose keys are open-ended (a `deepObject` or exploded
  object with `additionalProperties`). A `deepObject` that declares its
  properties is expressible by spelling each key, quoted:
  `"filter[status]": $args.status`. Passing a whole input object
  (`filter: $args.f`) composes but fails every request at runtime.
- Object-valued arguments in a `rover connector test` unit entry — see
  [testing.md](testing.md); the write still works at runtime, it just
  cannot be asserted at that layer.
- One `@source` per workspace. Connectors allow several, but the layers
  render one host and one credential, so anything needing a second host or a
  second credential is outside the workspace model; lint reports a second
  `@source`, as a warning or an error depending on the target.
