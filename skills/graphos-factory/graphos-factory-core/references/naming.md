# Naming

Every name in a connector schema shares one namespace with every other
subgraph in the supergraph. The prefixes are what keep two connectors from
colliding, and they are mechanical — `graphos-factory-core lint` checks all of them.

## The four names of one service

For a service whose directory is `widget-co`:

| Name | Value | Where it appears |
|---|---|---|
| directory / subgraph | `widget-co` | directory, `supergraph.yaml` key, schema filename |
| source / service | `widget_co` | `@source(name:)`, `workspace.yaml` `service` |
| type prefix | `Widget_Co` | `type Widget_Co_Widget` |
| field prefix | `widget_co` | `Query.widget_co_listWidgets` |

**The other three derive from the directory.** Snake-case the directory
for the source and field prefix, and capitalise each part for the type
prefix: `widget-co` gives `widget_co`, `Widget_Co_` and `widget_co_`. The
table above follows that rule. A vendor's own casing (`GitHub_`, not
`Github_`) or a short source name (`gsc` for `google-search-console`) is
allowed; a target that derives the names itself says what it needs to
accept a different one.

**The directory may be snake_case** (`widget_co`) when a consumer needs
the schema file under that name — the AppWorld benchmark bundle reads
`<app>.graphql`, so `simple_note` rather than `simple-note`. The schema
filename is always `<directory>.graphql`. `workspace.yaml`'s `directory`
accepts kebab- or snake-case words (`^[a-z][a-z0-9_-]*$`), and the choice
changes nothing else: the rule snake-cases either form first, so
`widget_co` still derives `widget_co`, `Widget_Co_` and `widget_co_`, and
rover gives the same `WIDGET_CO`. A snake_case directory is not a licence
for a CamelCase type prefix.

**Multi-word names use snake_case, never camelCase.** `rover supergraph
compose` derives the `join__Graph` enum value from the subgraph name by
uppercasing and replacing hyphens with underscores — `widget-co` →
`WIDGET_CO`. `@source(name: "widgetCo")` still composes; it just leaves the
subgraph schema and the composed supergraph SDL disagreeing about the
service's name, in a way that is easy to miss in review and annoying to
unpick later.

## Types and fields

```graphql
type Widget_Co_Widget { ... }          # {TypePrefix}_{TypeName}, PascalCase after the prefix
scalar Widget_Co_JSON                  # the one opaque scalar, if any
enum Widget_Co_WidgetStatus { ... }

type Query {
  widget_co_listWidgets(...): [Widget_Co_Widget]   # {field_prefix}_{camelCase}
}
```

`Query`, `Mutation` and `Subscription` are the federation roots and are
never prefixed. Everything else is.

Nested types take the path that produced them, so the name says where it
came from: `Widget_Co_Widget_Owner`, not `Widget_Co_Owner2`. If two paths
genuinely produce the same shape, share one type and record that as a
decision in `decisions.json`.

An inline (non-`$ref`) request body becomes an input type named after the
operation's `graphql.name` — `{TypePrefix}_{OpName}Input`
(`Widget_Co_CreateWidgetInput`), never a placeholder (`Input`, `Input2`) — and
an inline array body's item type is `{TypePrefix}_{OpName}ItemInput`. A `$ref`
body keeps its component name.

## Field naming inside the selection

REST payloads are usually `snake_case`; GraphQL fields are `camelCase`. Do
the rename in the `@connect` selection, not by renaming the API's fields in
your head:

```graphql
selection: """
channelId: channel_id
postAt: post_at
nextCursor: response_metadata.next_cursor
"""
```

Two exceptions worth taking deliberately:

- **Keep the vendor's casing when it is the API's own vocabulary** — an
  enum whose values serialise straight back into a request body should keep
  the wire casing rather than gain a `->match` translation table in both
  directions. This rule settles it, so following it is not a decision:
  record it as a finding (`graphos-factory-core findings add --cites
  references/naming.md`) only when an instrument needs it, keep a decision
  in `decisions.json` for a departure from it, and apply it to the
  whole connector. `graphos-factory-core lint` checks the other direction
  (`wire-enum-drift`): an enum value the spec does not list for the
  parameter or property it maps to, or a listed value the enum lacks, is a
  warning unless the connector translates it with `->match`. The converse is
  checked too (`closed-enum-as-string`): a `String` argument or
  field over a spec vocabulary of two or more values, every one a valid
  GraphQL name — declared at every spec property a selected operation
  reaches the field through — is a warning until it is an enum in wire
  casing or a resolved decision names the slot in `affects`.
- **Keep a name that is already `camelCase` on the wire.** Renaming for
  symmetry costs a mapping and buys nothing.

A snake_case field on a prefixed type, or a root field whose name after the
prefix is snake_case, is a lint warning (`field-casing`); a doc comment on
the field saying why the wire name is kept is the recorded exception.

## Operation names and the semantic root

The field name comes from `selection.yaml`'s `graphql.name`, unprefixed;
the prefix is added on emit. Prefer the name a user of the API would use
(`listWidgets`, `widget`, `createWidget`) over the vendor's `operationId`,
which is frequently copy-pasted from a sibling endpoint and wrong.

**Query vs Mutation is semantic and is never derived from the HTTP method.**
A POST that searches is a `Query`; a GET that mints a token is a `Mutation`.
This matters beyond taste: a POST is a write until the user says so. The
inventory records every POST as `semantics: write`, because a write
mistaken for a read puts a side effect under `Query`, where callers,
caches and retries treat it as safe, while a read mistaken for a write only
changes the schema's root. A POST whose name carries a read verb (`renderMarkdown`,
`/schedules/preview`, `repoGetFileContentsPost`) carries a `read_hint`, and
`inventory list` marks it `[read?]`. Surface every hinted POST to the user
and ask which are reads **before** writing `root: query` for any of them;
`selection.yaml` must carry an explicit `graphql.root`, `graphos-factory-core
lint` fails when it does not, and `read-root-on-write` warns on every POST
selected as a `Query` until `decisions.json` records why.

## Renames and collisions

- Two operations may not map to the same field name — lint catches it.
- Within one type, two source fields may not rename to the same GraphQL
  name.
- When the API has an `id`-like field, expose it as `ID`, not `String`,
  and use it as the `@key` if the type becomes an entity.
