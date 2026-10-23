# Rover Persisted Queries Commands

Generate and publish persisted query manifests for safelisting and performance optimization. Alias: `rover pq`.

Requires a GraphOS Enterprise plan.

## persisted-queries generate

Generate a persisted query manifest (PQM) from `.graphql` operation files. Runs locally with no API key required.

```bash
# Print manifest to stdout
rover persisted-queries generate

# Write manifest to file
rover persisted-queries generate --manifest-path pqm.json
```

### File Discovery

```bash
rover persisted-queries generate \
  --root-dir ./client \
  --include "operations/**/*.graphql" \
  --exclude "operations/**/*.test.graphql"
```

### Manifest Format

The Apollo persisted query manifest format:

```json
{
  "format": "apollo-persisted-query-manifest",
  "version": 1,
  "operations": [
    {
      "id": "e5c9c9f2d1a0...",
      "name": "GetProduct",
      "type": "query",
      "body": "query GetProduct($id: ID!) { product(id: $id) { id name } }"
    }
  ]
}
```

Each entry includes:
- `id` — SHA-256 hash of the operation body
- `name` — operation name
- `type` — `query`, `mutation`, or `subscription`
- `body` — normalized operation body

The generator processes `@client` fields and directives (pruning unused variables), includes transitively referenced fragment definitions, and supports multiple operations per `.graphql` file.

### Options

| Option | Description |
|--------|-------------|
| `--manifest-path`, `-m` | Write manifest to file instead of stdout |
| `--include <PATTERN>` | Glob pattern for `.graphql` files. Repeatable |
| `--exclude <PATTERN>` | Glob pattern for files to exclude. Repeatable |
| `--root-dir <DIR>` | Root directory to scan from (default: cwd) |

## persisted-queries publish

Publish a PQM to a persisted query list (PQL) in GraphOS:

```bash
rover persisted-queries publish my-graph@my-variant \
  --manifest ./pqm.json
```

Alternatively, specify graph and list directly:

```bash
rover persisted-queries publish \
  --graph-id my_graph \
  --list-id dc4b4040-30fc-4bd1-94a3-5fc1c722acc9 \
  --manifest ./pqm.json
```

### Options

| Option | Description |
|--------|-------------|
| `--manifest <PATH>` | Path to the manifest file (required) |
| `--graph-id <ID>` | Graph ID (alternative to graph ref) |
| `--list-id <UUID>` | PQL UUID (alternative to graph ref) |
| `--for-client-name <NAME>` | Associate all operations with a client name |
| `--manifest-format <FORMAT>` | `apollo` (default) or `relay` |

### Publishing Behavior

- Publishing is additive. Existing entries remain in the PQL.
- If an operation with the same `id` and `clientName` but different details exists, the entire publish fails.
- All variants linked to the PQL are updated.

### Relay Support

Publish Relay-generated persisted queries with the `--manifest-format relay` flag:

```bash
rover persisted-queries publish my-graph@my-variant \
  --manifest ./persisted-queries.json \
  --manifest-format relay
```

## End-to-End Workflow

```bash
# 1. Extract operations from source code
rover client extract --out-dir graphql --overwrite

# 2. Generate manifest from extracted operations
rover persisted-queries generate --manifest-path pqm.json

# 3. Publish to GraphOS
rover persisted-queries publish my-graph@prod --manifest ./pqm.json
```
