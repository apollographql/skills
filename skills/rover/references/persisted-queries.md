# Rover Persisted Queries Commands

Commands for generating and publishing persisted query manifests to Apollo GraphOS. The `rover persisted-queries` command group is also available under the alias `rover pq`.

## What Are Persisted Queries?

Persisted queries (also called registered operations) let clients send a pre-registered operation ID instead of the full query text. The router looks up the ID and executes only operations it recognizes.

**Benefits:**
- **Security** - The router rejects unknown operations, preventing arbitrary queries
- **Performance** - Smaller request payloads (a hash instead of a full query string)
- **Visibility** - All operations in production are known and registered in GraphOS

## persisted-queries generate

Generate a persisted query manifest from `.graphql` files in your project.

```bash
# Scan current directory for .graphql files
rover pq generate --include "src/**/*.graphql"

# Write manifest to a file
rover pq generate --include "src/**/*.graphql" --manifest-path ./pq-manifest.json

# Exclude generated files
rover pq generate \
  --include "src/**/*.graphql" \
  --exclude "src/__generated__/**"

# Scan a specific directory
rover pq generate --include "**/*.graphql" --root-dir ./my-app

# Preserve comments above operations in the manifest
rover pq generate --include "src/**/*.graphql" --preserve-comments
```

**Options:**
| Option | Description |
|--------|-------------|
| `--include <PATTERN>` | Glob patterns for files to include (repeatable) |
| `--exclude <PATTERN>` | Glob patterns for files to exclude (repeatable) |
| `--root-dir <DIR>` | Root directory to scan (default: current directory) |
| `--manifest-path, -m <FILE>` | Write manifest to this file instead of stdout |
| `--preserve-comments` | Keep comment blocks preceding operations in the manifest body |

**Manifest format (Apollo):**

```json
{
  "format": "apollo-persisted-query-manifest",
  "version": 1,
  "operations": [
    {
      "id": "sha256-hash-of-the-operation-body",
      "body": "query GetUser($id: ID!) {\n  user(id: $id) {\n    id\n    name\n  }\n}",
      "name": "GetUser",
      "type": "query"
    }
  ]
}
```

All operations must be named. Anonymous operations cause an error.

## persisted-queries publish

Publish a persisted query manifest to a graph in Apollo GraphOS.

```bash
# Publish using a graph ref (list must be linked to the variant)
rover pq publish my-graph@production \
  --manifest ./pq-manifest.json

# Publish using explicit graph ID and list ID
rover pq publish \
  --graph-id my-graph \
  --list-id my-list-id \
  --manifest ./pq-manifest.json

# Publish a Relay-format manifest
rover pq publish my-graph@production \
  --manifest ./relay-manifest.json \
  --manifest-format relay

# Override the client name for all operations
rover pq publish my-graph@production \
  --manifest ./pq-manifest.json \
  --for-client-name my-web-app

# Read manifest from stdin
cat pq-manifest.json | rover pq publish my-graph@production --manifest -
```

**Options:**
| Option | Description |
|--------|-------------|
| `<GRAPH_REF>` | Graph reference with a linked persisted query list |
| `--graph-id <ID>` | Graph ID (use with `--list-id` instead of a graph ref) |
| `--list-id <ID>` | Persisted query list ID (use with `--graph-id`) |
| `--manifest <PATH>` | Path to the manifest file, or `-` for stdin (required) |
| `--manifest-format <FORMAT>` | Manifest format: `apollo` (default) or `relay` |
| `--for-client-name <NAME>` | Override the `clientName` field in all operations |

**Identifying the target list:**
- Pass a `<GRAPH_REF>` if a persisted query list is linked to that variant.
- Pass `--graph-id` and `--list-id` together to target a specific list directly.
- You cannot combine a graph ref with `--graph-id` or `--list-id`.

## CI/CD Workflow

A typical pipeline generates the manifest from client source files and publishes it before deploying:

```bash
# 1. Generate the manifest
rover pq generate \
  --include "src/**/*.graphql" \
  --manifest-path ./pq-manifest.json

# 2. Publish to GraphOS
rover pq publish $APOLLO_GRAPH_REF \
  --manifest ./pq-manifest.json
```

### GitHub Actions Example

```yaml
steps:
  - name: Generate persisted query manifest
    run: |
      rover pq generate \
        --include "src/**/*.graphql" \
        --manifest-path ./pq-manifest.json

  - name: Publish persisted queries
    run: |
      rover pq publish $APOLLO_GRAPH_REF \
        --manifest ./pq-manifest.json
    env:
      APOLLO_KEY: ${{ secrets.APOLLO_KEY }}
      APOLLO_GRAPH_REF: my-graph@production
```

## Working with Relay

If your client uses [Relay](https://relay.dev/), generate the manifest using Relay's compiler, then publish it with the `--manifest-format relay` flag:

```bash
rover pq publish my-graph@production \
  --manifest ./relay-persisted-queries.json \
  --manifest-format relay
```

Use `--for-client-name` to tag operations with the client name (Relay manifests do not include one by default):

```bash
rover pq publish my-graph@production \
  --manifest ./relay-persisted-queries.json \
  --manifest-format relay \
  --for-client-name my-relay-app
```

## Extracting Operations from Source Files

If your operations are embedded in TypeScript/JavaScript source files (for example, as `gql` tagged template literals), extract them first with `rover client extract`:

```bash
# Extract .graphql files from source
rover client extract --include "src/**/*.{ts,tsx}" --out-dir ./graphql

# Generate manifest from the extracted files
rover pq generate --include "graphql/**/*.graphql" --manifest-path ./pq-manifest.json
```
