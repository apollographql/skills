# Verification: what the layers prove, and the check against the user's graph

## What the core layers prove

The core layers prove the subgraph on its own: it composes alone at the
workspace's pin, every connector maps the recorded responses the way the
cases demand, the requests it sends match the stubs, the responses match the
source's documented shapes, lint finds nothing blocking, and, when a live
target is configured, the real API answers. Each layer is blind to something;
`testing.md` in the core says what, and how to report a layer that was
skipped or not run. None of them sees the user's other subgraphs.

## `supergraph_check`: the check against the user's graph

`evidence/latest.json` carries this target's own layer, `supergraph_check`,
under `target_evidence_layers`. The compose layer composes this subgraph
alone, so a type or field another subgraph also defines, or a query the
combined graph cannot satisfy, does not show up there. `supergraph_check`
runs `scripts/supergraph-check.sh`, which renders the schema into a
temporary directory and runs

```bash
rover subgraph check <graph>@<variant> --name <directory> --schema <rendered copy> --format json
```

GraphOS composes the subgraph with the variant's other subgraphs and runs
the variant's checks: operations against recorded traffic, and lint,
custom, proposal or downstream checks when the graph has them configured.
Nothing is published; a check changes no variant. The binary never touches
the network: the script runs rover, the way the live layer's script calls
the API.

What it sends: the schema rendered with `<SERVICE>_BASE_URL` when set, else
the test default. Composition does not read the host, so either checks the
same thing. `AUTH_EXPR` is always the test default, a `{$env.NAME}`
expression, so a `<SERVICE>_AUTH_EXPR` override never reaches GraphOS. A
base URL carrying userinfo, or a query parameter named like a credential
(`token`, `key`, `secret`, `password`, `auth`, `signature`, `credential`),
is not sent (`not_run`).

### What it needs, and who supplies it

A key, which is the user's, and a graph ref given for the run.

- `APOLLO_KEY`: their GraphOS API key, in the environment your commands
  inherit (their shell profile, or the shell they start you from). It is
  theirs: never ask them to paste it to you, never set it, never print it.
  A key stored only in a rover profile does not count.
- The graph ref, `<graph>@<variant>`, chosen one of two ways:
  - **Explicit (the default).** Ask once per session which graph and
    variant to check against, saying what the check does: it sends the
    rendered schema, with the production host when one is set, to GraphOS,
    which keeps it, and publishes nothing. On an answer, set
    `GRAPHOS_FACTORY_GRAPH_REF=<graph>@<variant>` on the commands you run
    (a prefix on `evidence`, as with `APOLLO_ELV2_LICENSE`). `details.mode`
    records `explicit`.
  - **Automatic, the user's switch.** A user who wants every run checked
    sets `GRAPHOS_FACTORY_SUPERGRAPH_CHECK=auto` in their shell profile,
    beside `APOLLO_GRAPH_REF`; the layer then checks against
    `$APOLLO_GRAPH_REF` without being asked, and `details.mode` records
    `auto`. Never set `auto` for them. Any other value of the switch is
    refused, `not_run`.

  An explicit `GRAPHOS_FACTORY_GRAPH_REF` wins when both are present.
  `APOLLO_GRAPH_REF` alone never starts a check: shell profiles export it
  for other tools, and a check sends the schema to GraphOS. A graph ref of
  another shape (no `@variant`, a space, a leading `-`) is refused,
  `not_run`.

Until a key and a graph ref are both there, the layer is `not_run`, and its
reason says what to set. Neither value is written to the workspace:
`latest.json` records the graph ref and the mode, never the key, and the
script removes the key from anything rover echoes.

### Reading the result

- `pass`: the subgraph composes with the variant, and every check rover ran
  passed. `details` records the graph ref, rover's version, the subgraph
  name, `composition: pass`, each check task's status, the operation
  check's `checked` and `failing_changes` counts, and the Studio URL. Report
  it as checked against that variant at that time. The variant moves, and
  a publish composes but runs no operation, lint or custom check, so tell
  the user to re-run the check before they publish.
- `fail`: composition failed (`build error [CODE]: message` findings, for
  example `INVALID_FIELD_SHARING` or `SATISFIABILITY_ERROR`), or it
  composed and a check failed (`operations [CODE]: description`, `lint
  [RULE] ...`). `export` refuses the workspace with these errors. Read
  which type or field both subgraphs define before reaching for
  `@shareable` (federation-subgraph.md § Directives a connector subgraph
  may carry), and ask the user whether it is meant to be shared. When it is
  not, the fix is a name (`type_prefix`, `field_prefix`), not the
  directive. Record the fix as a decision. A failing operation check is the
  user's call: show them the change and the Studio URL.
- `not_run`: no graph ref for the run, no key, an unknown switch value,
  a graph ref that is not `<graph>@<variant>`,
  the base URL carries a credential, or rover
  could not run the check (no such graph or variant, a refused key, no
  network), with rover's message as the reason. Report it as not checked
  against their graph, never as a pass.
- `skipped`: rover, jq or the script is not installed.

The layer does not gate `evidence`'s exit code; `export` refuses a `fail`
and lists `not_run` and `skipped` as not verified.

### When the user would rather run it themselves

`graphos-factory export . --out DIR` writes the rendered schema to
`DIR/<directory>.graphql` and prints the `rover subgraph check` command.
Offline, when they have their other subgraphs' SDL on disk, a
`supergraph.yaml` at their `federation_version`, naming this subgraph's
rendered file and each of theirs (absolute paths, or paths relative to the
config file), then `rover supergraph compose --config supergraph.yaml`.
Report what they ran and its exact output as **theirs**, under their name
and with the command, never as an evidence layer and never folded into
`evidence/latest.json`. Publishing is theirs as well: never run
`rover subgraph publish` yourself.

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
