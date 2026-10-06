# Federation subgraph: versions, directives, composition

A subgraph this target builds joins a supergraph the user already runs. Their
router and their build pipeline decide what the schema may use. The layers
run one pinned toolchain, and a pass at that pin says nothing yet about the
user's graph. Read this before `init` and before adding any Federation
directive beyond what the core references describe.

## Versions: the user's graph decides, not the toolchain

Before `init`, ask the user for two versions, and record each answer as a
decision (`graphos-factory-core decisions add`, then `decisions resolve` with
what they said):

1. The Apollo Router version serving the supergraph. With several
   deployments, the oldest one counts.
2. The federation version the variant's build pipeline composes with (the
   `federation_version` of their composition, or the version GraphOS builds
   the variant at).

Pick the connect spec from Apollo's documented minimums
([version requirements](https://www.apollographql.com/docs/graphos/connectors/getting-started/version-requirements)):

| `connect/` | Apollo Router at least | build pipeline at least |
|---|---|---|
| `v0.4` | 2.15.0 | 2.14.1 |
| `v0.3` | 2.8 | 2.12 |
| `v0.2` | 2.3 | 2.11 |
| `v0.1` | 2.0 | 2.10 |

- Use the newest connect spec that both of the user's versions meet, and
  never `v0.5` (a preview: connectors-language.md § v0.5). Below Router
  2.16.0, `v0.4` was still a preview the router had to opt into
  (connectors-language.md § Linking the spec); ask whether their router
  configuration does.
- Link `federation/vX.Y` no newer than the version their pipeline composes
  with. A link older than the workspace's `federation_version` pin is
  recorded as `federation_spec_version` (workspace-contract.md).
- `init` writes `connect/v0.4` and `federation_version: "2.15.2"`, and the
  layers run Apollo Router 2.17.0 (`toolchain.sh`). When the user's router
  is older than 2.15.0 or their pipeline older than 2.14.1, do not ask them
  to upgrade production to fit one subgraph. Move the workspace to `v0.3`
  instead: run mapping-language.md § Moving a workspace from v0.3 to v0.4
  in reverse. Set `connect_spec: v0.3` and a `federation_version` no newer
  than their pipeline (`"2.12.0"` is the pin earlier workspaces used) in
  `.factory/workspace.yaml` and `supergraph.yaml`, link `connect/v0.3`, and
  rewrite what v0.3 reads differently or cannot parse: mapping-language.md
  § Literals (a quoted string, `true`, `false` or `null` after an alias reads
  a property at v0.3), § Abstract types (no unions or interfaces; a
  documented JSON scalar instead) and § What v0.3 lacks. Record the move as
  a decision, then compose and run the e2e layer.
- Below Router 2.8 or a pipeline below 2.12, nothing in this skill has been
  run. Say so and ask the user before going further.
- Every report names both sides: the pins the layers ran at (connect spec,
  `federation_version`, router 2.17.0) and the versions the user runs. Where
  they differ, the layers' result is evidence at the pin only. The subgraph
  is unverified on the user's versions, never a pass.

## Directives a connector subgraph may carry

Apply each of these only after the user has answered the question it raises
and you have recorded the answer as a decision. Never add one speculatively,
"in case".

Every directive the schema applies must be in the federation `@link`'s
`import` list. Compose rejects one that is not ("add "@inaccessible" to the
`import` argument of the @link"). Lint's `federation-drift` checks the import for the nine directives this
target allows (`@key`, `@shareable`, `@requires`, `@provides`, `@external`,
`@tag`, `@inaccessible`, `@listSize`, `@cost`); for any other directive the
compose layer is the check.

Measured at `federation_version` 2.15.2 with Apollo Router 2.17.0 and no
license: `@inaccessible`, `@listSize` and `@cost` compose, and the router
starts and serves them. `@authenticated` and `@requiresScopes` compose, but
the router refuses to start ("license violation, the router is using
features not available for your license").

- **`@inaccessible`** hides a field from clients while the router can still
  fetch it. Two uses:
  - Staging a new root field: ship it inaccessible, and remove the directive
    when the user says clients may use it.
  - Hiding a foreign-key field kept only so a relationship field can read it
    through `$this`. Measured: a field-level connector reading
    `$this.owner_id`, with `owner_id` inaccessible, resolves.

  An e2e or live case cannot select an inaccessible field (the router
  answers `GRAPHQL_VALIDATION_FAILED`, "Cannot query field"), so test it
  through the field that reads it.
- **`@shareable`**: only when the user's other subgraph defines the same
  type and field, and only after they name it. This subgraph's prefixed
  types never collide with another subgraph's, so the need is rare. Fields in
  an entity's `@key` are already shareable and need no directive.
- **`@listSize`** and **`@cost`**: only when the user's router enforces
  demand control
  ([demand control](https://www.apollographql.com/docs/graphos/routing/security/demand-control)),
  a feature tied to their plan (ask them to check theirs). On a list field
  whose size an argument sets, write
  `@listSize(slicingArguments: ["limit"])`. Add
  `requireOneSlicingArgument: false` when that argument is optional, because
  the default is `true` and the router would then reject a query that
  omits it. On a field returning an object that wraps the list, add
  `sizedFields: ["<list field>"]`. When the API fixes the page size, write
  `assumedSize:` instead. Take the values from the inventory, never a guess:
  the operation's `pagination.size_param` names the argument, and that
  parameter's `default` and `maximum` are the source's numbers (lint's
  `pagination-bounds-unknown` already warns when the source documents
  neither). With neither documented, ask the user for the number and record
  it. `@cost(weight:)` likewise: only a weight the user gives you.
- **`@authenticated`, `@requiresScopes`, `@policy`**: the router enforces
  them whichever subgraph carries them, and only with router authorization
  configured (JWT authentication or a coprocessor supplying the claims). The
  connector calls the vendor with one service credential, so every caller
  the supergraph lets through reads with that credential. Ask whether a field
  must require the router's authentication, and use only scope or policy
  names the router already checks. These are licensed router features: the
  user should check their plan, and the layers' unlicensed router does not
  start with them (above; `@policy` was not measured). A workspace carrying
  one cannot pass e2e or live today. Record the requirement as a decision,
  leave the directive out of the workspace schema, and tell the user it is a
  change they make in their own graph, outside what this skill validated.
- **`@tag`**: see § `@tag` and contracts.
- **`@key`** and the entity form are in connectors-language.md § Entities.
  `@requires` with `@external`, and `@provides`, only mean something across
  subgraphs, which this target does not build yet (§ Open).

### Never

- `@context` or `@fromContext`: connectors do not support them.
- `@cacheTag`, or any reliance on entity caching: the router's entity
  cache does not fully support connectors.
- `@connect` on a `Subscription` field: connectors serve `Query` and
  `Mutation` only.
- `@override` that moves a field from this connector subgraph back to a
  resolver subgraph. Connectors support `@override` only in the other
  direction.
- A `@provides` claiming fields the connector's response does not carry.

The connector-side list is Apollo's
[limitations](https://www.apollographql.com/docs/graphos/connectors/reference/limitations).

## `@tag` and contracts

`@tag` is permitted, and off by default: it exists for
[GraphOS Contracts](https://www.apollographql.com/docs/graphos/platform/schema-management/delivery/contracts/overview),
which include or exclude types and fields by tag name. Apply it only when
the user's supergraph uses contracts, with the names their contracts
already filter on, and record that as a decision. Never invent a tag: this
target imposes no tag names, so `unknown-tag` never fires, and a schema
that applies `@tag` imports it in the federation `@link` like any other
directive (`federation-drift` reports one applied without the import). The
choice is recorded in `selection.yaml` as the operation's `tags:` list,
and `reconcile` checks that list against the field's `@tag(name:)`
directives, so the two change together.

## Open

These are not answered yet. Do not promise them to the user and do not fake
them.

- **Cross-subgraph entities: not supported yet.** Apollo documents adding
  fields to another subgraph's entity by declaring the owner's type, with
  its exact name and `@key`, and a field-level `@connect` keyed by `$this`
  ([entities across subgraphs](https://www.apollographql.com/docs/graphos/connectors/entities/across-subgraphs)).
  In this skill that fails lint: `type-prefix` is an error on the
  unprefixed type, and its resolvable `@key` fails `entity-without-lookup`,
  which wants a by-id lookup this subgraph does not have. So types this subgraph does not own
  cannot be extended, and a `resolvable: false` stub must carry this
  subgraph's prefix today. A cross-subgraph join is done from the other
  subgraph's side, or deferred. The same holds for `@requires`/`@external`,
  `@provides` and `@interfaceObject` (which connectors support from
  `connect/v0.4` only), and for an `@override` migration of a field from a
  resolver subgraph into this one. A `links:` entry whose target type lives
  in another subgraph is open for the same reason.
- **Which operations become entities by default**: every GET-by-id the
  inventory finds, only those the user selects, or only those another
  selected type refers to. The `entity-*` lint rules assume this subgraph
  owns each entity it declares.
- **More than one `@source`.** Connectors allow several; the layers render
  one host and one credential, so this target reports a second `@source` as
  a warning (`multiple-sources`), its name differing from
  `workspace.service` a warning too (`source-name-secondary`), and turns
  `commented-source` off: unmodelled, not forbidden. The first source's
  name must still equal `workspace.service` (`source-name`, an error):
  `tests/router.yaml` keys the source by it, and a renamed one sends e2e
  to the real host. Modelling more than one would change the workspace's
  single `source` entry, the per-source variables and credential, and the
  fixtures that name a source.
- **The federation version.** Whether the pin should follow the user's
  graph instead of `init`'s default.
