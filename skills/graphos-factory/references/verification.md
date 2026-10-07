# Verification: what the layers prove, and the check against the user's graph

## What the core layers prove

The core layers prove the subgraph on its own: it composes alone at the
workspace's pin, every connector maps the recorded responses the way the
cases demand, the requests it sends match the stubs, the responses match the
source's documented shapes, lint finds nothing blocking, and, when a live
target is configured, the real API answers. Each layer is blind to something;
`testing.md` in the core says what, and how to report a layer that was
skipped or not run. None of them sees the user's other subgraphs.

## `supergraph_check` is `not_run`

`evidence/latest.json` carries this target's own layer, `supergraph_check`,
and it is `not_run` by design. The compose layer composes this subgraph
alone, so a type or field another subgraph also defines, or a query the
combined graph cannot satisfy, does not show up there. A check against the
user's graph needs either their published supergraph (a GraphOS API key) or
their other subgraphs' schemas. The binary never touches the network, and you
never handle the user's `APOLLO_KEY`. Report the layer as not run, never as a
pass, and say the subgraph has not been checked against their graph.

### The hand-off

The user runs the check; you prepare it. `graphos-factory export . --out DIR`
writes the rendered schema to `DIR/<directory>.graphql` and prints the
commands. Give the user one of these:

- Against the published supergraph (needs their GraphOS credentials):

  ```bash
  rover subgraph check <graph>@<variant> --name <subgraph> --schema DIR/<directory>.graphql
  ```

- Offline, when they have their other subgraphs' SDL on disk: a
  `supergraph.yaml` at their `federation_version`, naming this subgraph's
  rendered file and each of theirs (absolute paths, or paths relative to the
  config file), then

  ```bash
  rover supergraph compose --config supergraph.yaml
  ```

Then:

- Report what they ran and its exact output as **theirs**, under their name
  and with the command, never as an evidence layer and never folded into
  `evidence/latest.json`.
- Until one of the two has passed, say plainly that the subgraph is
  unverified against their graph, whatever the core layers show.
- Expect the failure, when there is one, to be a shared-type or
  satisfiability error that only appears with their subgraphs
  (`INVALID_FIELD_SHARING`, `SATISFIABILITY_ERROR`). Read which type or field
  both subgraphs define before reaching for `@shareable`
  (federation-subgraph.md § Directives a connector subgraph may carry), and
  ask the user whether it is meant to be shared. When it is not, the fix is
  a name (`type_prefix`, `field_prefix`), not the directive. Record the fix
  as a decision.
- Publishing is theirs as well. Never run `rover subgraph publish` yourself.

## Open

Lint rules this target might add. Each needs a stated condition, a severity,
and a fixture that fails when the rule is reverted; none exists yet.

- An entity whose `@key` differs from the owning subgraph's key. This needs
  the owner's schema, which the workspace does not have.
- `@shareable` missing on a field another subgraph defines. Not knowable
  without the other subgraphs' schemas.
- An `@external` field no `@requires` or `@provides` uses.
- A `@requires` whose fields no connector in this subgraph can fetch.
- A `@provides` naming a field the connector response does not carry.
- Whether the core's `entity-*` rules and these share one family, and which
  become warnings when the other subgraphs are unavailable.

Severities and messages of core rules can already be adjusted per target
through the core's `rule_overrides`, and every finding records whether the
core or this target raised it.
