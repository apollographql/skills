# Export to a GraphOS graph

The subgraph reaches the user's graph in two steps. `graphos-factory export`
renders the validated schema with its production values and prints a
hand-off. The user then runs rover with their own GraphOS credentials. The
binary never contacts GraphOS and never reads a key, and neither do you:
the one rover call the skill makes, `supergraph_check`, runs from a script
with the key the user exported (verification.md).

## When to export

Export only after `validate`, when `.factory/evidence/latest.json` is
current: run `evidence` on the workspace as it is, change none of the files
its layers read, then export. Git is not required. Export again whenever
the schema changes and a new `evidence` run passes, and whenever the
production host changes. An exported file is a
build output, not part of the workspace: the workspace keeps
`{{BASE_URL}}` and `{{AUTH_EXPR}}`, and `template.yaml` keeps their local
test values for the layers.

Ask the user for the production base URL, including any path the API's
operations hang off (for a Swagger 2.0 source, its `basePath`). Do not guess
it from the description document's `servers` or `host`: a vendor's documented
host and the user's deployment are not always the same.

## The command

```bash
graphos-factory export . --out DIR --base-url https://api.example.com/v1 [--json]
```

- `DIR` must be outside the workspace. The rendered copy holds the
  production host, which the workspace does not record, and inside it the
  copy would be an untracked file beside the schema. `DIR` is created if
  missing, and the file is written as `DIR/<directory>.graphql`.
- The base URL comes from `--base-url`, else `<SERVICE>_BASE_URL`, else
  `template.yaml`'s test default. It must be an absolute `http` or `https`
  URL with a host: `localhost:3000/api` or a bare `127.0.0.1:3000/api` is
  refused. A base URL whose host is this machine is refused too, because
  the test default is for the local layers: `localhost`, a `.localhost`
  name, `host.docker.internal`, and a loopback or unspecified address,
  IPv4-mapped IPv6 included. A base URL carrying userinfo
  (`https://user:secret@host`) is refused and echoed with the userinfo
  replaced by `<redacted>`: GraphOS stores the published schema. Send the
  credential through `AUTH_EXPR`.
- `AUTH_EXPR` comes from `<SERVICE>_AUTH_EXPR`, else the test default, and
  must be a static `{$env.NAME}`. A literal value is refused without being
  echoed, because GraphOS stores the published schema and a credential in it
  would be published too. The router reads `NAME` from its own environment.
- Only the schema is rendered. The e2e router config under `tests/` is
  not part of an export.

Exit codes: 0 written, 1 refused or an error, 2 usage (no `--out`, or a flag
the command does not declare). `--json` prints the same facts as one object,
and a refusal as `{error, code, reasons, exit}`.

## The gate

`export` refuses a workspace that is not validated, and says why in the
terms `evidence` uses. There is no override.

- No `.factory/evidence/latest.json`.
- Evidence that is not for the workspace as it is now. `latest.json`
  records `inputs`: the SHA-256 of every file the layers read (the schema,
  `template.yaml`, `supergraph.yaml`, everything under `tests/`, and the
  `.factory` workspace, selection, inventory, context, sources lock and the
  documents it names, and the decision and finding logs), hashed before
  they ran. Export hashes the same files again and refuses each one that
  differs, by name: `<path> changed since evidence ran: re-run evidence`,
  or `added` or `removed`. A `README.md` or `memory.md` edit does not count;
  the layers never read either. No git is needed, so a workspace that is
  not a repository exports. Evidence written before `inputs` existed is
  checked against git instead, and the refusal says the evidence predates
  input hashing: a recorded `-dirty`, uncommitted changes now, or a recorded
  commit the workspace's files differ from is refused, and so is a
  workspace outside git. Re-running `evidence` records `inputs`. When
  `evidence` could not hash a file (a link under `tests/` that resolves
  outside the workspace), it records why instead, and export refuses with
  `evidence could not hash its inputs (<why>): fix that, then re-run
  evidence`: fix the file first, or the next run fails the same way.
- `compose`, `connector_unit`, `wiremock_e2e`, `conformance` or `lint` not
  `pass`. A `not_run` `connector_unit` is allowed: it is the zero-case run
  whose suites cite their decisions. It is then listed as not verified.
- `live` ran and failed. A `live` that did not run is not a refusal: it
  needs a credential the user may not have given. It is listed as not
  verified.
- A selected operation that an offline layer left `fail`, `unchecked` or
  `skipped`, or that has no executed evidence (no unit, e2e or live
  `pass`: conformance executes nothing).
- `supergraph_check` ran against the user's graph and failed: the
  subgraph does not compose with their variant, or a check rover ran
  failed. The refusal names the reason and each build error or failing
  change. Fix it (verification.md § Reading the result) and run `evidence`
  again. A `not_run` or `skipped` check is not a refusal; it is listed as
  not verified. Export reads the recorded result only: it does not compare
  the `graph_ref` the check ran against with the graph the user means to
  publish to now, so name the recorded graph ref when you hand off, and
  re-run `evidence` with the right one when they differ.
- A lint error on the files as they are now, which includes a selected
  operation with no entry in the evidence. An `auth-test-default` error is
  named by rule and file, with the value replaced by `<redacted>`: it may
  be the credential itself.

`write_body_proof` and `json_accounting` do not gate, as in `evidence`. Each
is listed as not verified when it is not `pass`.

When the gate passes, the hand-off's `gate:` line ends `evidence inputs
<digest> (N files) unchanged since it ran`, the first twelve hex digits of
`inputs.digest` (`--json`: `evidence_digest`, `evidence_files`, and
`evidence_checked: inputs`, or `commit` for older evidence).

When the gate refuses, fix what it names and run `evidence` again. Never
edit `latest.json`, and never render the schema another way to get around a
refusal.

## What the user runs

The hand-off prints both commands with `<GRAPH_REF>` (`graph@variant`) left
for the user, and `--name` set to the workspace's `directory`, which is the
subgraph name:

```bash
rover subgraph check <GRAPH_REF> --name <directory> --schema DIR/<directory>.graphql
rover subgraph publish <GRAPH_REF> --name <directory> --schema DIR/<directory>.graphql --routing-url http://localhost
```

`rover subgraph check` composes the subgraph with the variant's other
subgraphs and checks it against recorded operations. It is what the
`supergraph_check` layer runs when `APOLLO_KEY` is in the user's
environment and a graph ref was given for the run (verification.md § What
it needs); when that layer passed, the check is already in the evidence
(`details.graph_ref` and `details.mode` say against what, and how it was
chosen), and the user should run it again before a publish, since the
variant moves. When it did not run, recommend it before every publish. A first
publish needs a routing URL. A subgraph whose fields are all connectors is
never called at it, so `http://localhost` is a placeholder. Never run
either command by hand (the check runs only as the layer), and never ask
for or print the user's GraphOS key: rover reads the user's own
credentials.

## The router

- The router needs the version the workspace's `connect_spec` requires.
  `connect/v0.4` needs Apollo Router 2.15.0 or later, with no opt-in from
  2.16.0. v0.3 needs 2.8.0, v0.2 2.3.0, v0.1 2.0.0.
- The hand-off prints the workspace's own `federation_version` as the
  composition version the subgraph was validated at. It is not a floor:
  composition at another version was not run, and `rover subgraph check`
  composes at the variant's.
- The router process must carry every `$env` variable the rendered schema
  reads. The hand-off lists them.
- To move the host per environment without a new publish, the router's YAML
  overrides it. The source is keyed `<subgraph>.<source name>`:

```yaml
connectors:
  sources:
    <directory>.<source>:
      override_url: "${env.<SERVICE>_BASE_URL}"
```

## What an export does not verify

The hand-off lists each item. Report every one of them as not verified,
never as a pass.

- `supergraph_check`, when it did not pass: composition with the user's
  other subgraphs, with the layer's reason (no graph ref for the run, no
  key, rover could not run the check, rover not installed). A `pass` is not listed.
  `rover subgraph check` is that check.
- `live`, when it did not run: the subgraph was never called against the
  real API.
- A GraphOS cloud router. The e2e layer runs a self-hosted router, so a
  cloud router's version and its own limits were not exercised.
- Each relationship field lint leaves not validated, as `link field
  <Type.field>: <warning>` (`link-untested`, `link-null-untested`,
  `link-live-unaccounted`), and each one a live exclusion names
  (`live-excluded`). A link field without tests is reported, never
  refused.
- Anything else the gate allowed but did not see pass: a `not_run`
  `connector_unit`, or a non-gating layer that is not `pass`.

The export itself is not recorded in the evidence. `latest.json` stays the
offline record that CI re-checks, and a publish is the user's act on their
own graph.
