# Rover Subgraph Preview Command

Preview how supergraph composition would change if you added, modified, or removed subgraphs, without publishing anything.

## Basic Usage

```bash
# Preview changes described in a YAML file
rover subgraph preview my-graph@production \
  --subgraph-changes changes.yaml

# Start the build and return immediately
rover subgraph preview my-graph@production \
  --subgraph-changes changes.yaml \
  --async

# Check the status of a previously started build
rover subgraph preview my-graph@production \
  --build-id abc123
```

## Subgraph Changes File

The `--subgraph-changes` flag takes a YAML file describing hypothetical subgraph modifications:

```yaml
subgraphs:
  # Add or update a subgraph
  products:
    routing_url: https://products.example.com/graphql
    schema:
      file: ./products.graphql

  # Use inline SDL instead of a file
  reviews:
    routing_url: https://reviews.example.com/graphql
    schema:
      sdl: |
        type Review @key(fields: "id") {
          id: ID!
          body: String
        }

  # Remove a subgraph
  legacy-service:
    remove: true
```

## Contract Filter Preview

Add contract filter flags to preview how a contract variant would look after the changes:

```bash
rover subgraph preview my-graph@production \
  --subgraph-changes changes.yaml \
  --include-tag public \
  --no-exclude-tags \
  --hide-unreachable-types
```

When using filter flags, all three pairs are required (same rules as `rover contract publish`):
- `--include-tag` or `--no-include-tags`
- `--exclude-tag` or `--no-exclude-tags`
- `--hide-unreachable-types` or `--no-hide-unreachable-types`

Omit all filter flags for a compose-only preview (no contract filtering).

## Options

| Option | Description |
|--------|-------------|
| `<GRAPH_REF>` | Graph reference (required) |
| `--subgraph-changes <FILE>` | YAML file describing subgraph changes |
| `--include-tag <TAG>` | Contract include tags (repeatable) |
| `--no-include-tags` | Empty include list |
| `--exclude-tag <TAG>` | Contract exclude tags (repeatable) |
| `--no-exclude-tags` | Empty exclude list |
| `--hide-unreachable-types` | Hide unreachable types in contract |
| `--no-hide-unreachable-types` | Keep unreachable types |
| `--async` | Return build ID immediately instead of polling |
| `--build-id <ID>` | Check status of a previous build |

## Workflow

```bash
# 1. Write a changes file describing what you want to test
cat > changes.yaml <<'EOF'
subgraphs:
  new-service:
    routing_url: https://new-service.example.com/graphql
    schema:
      file: ./new-service/schema.graphql
EOF

# 2. Preview the composition result
rover subgraph preview my-graph@production \
  --subgraph-changes changes.yaml

# 3. If the preview succeeds, publish for real
rover subgraph publish my-graph@production \
  --name new-service \
  --schema ./new-service/schema.graphql \
  --routing-url https://new-service.example.com/graphql
```
