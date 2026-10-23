# Rover Connector Commands

Commands for working with Apollo Connectors. Connectors integrate REST APIs into your federated graph.

Requires Federation v2.12.0 or later.

## connector run

Run a single connector request to test its behavior:

```bash
rover connector run \
  --supergraph-config supergraph.yaml \
  --subgraph products \
  --operation "query { product(id: \"1\") { name } }"
```

## connector test

Run automated tests for one or more connectors:

```bash
# Run all connector tests
rover connector test --supergraph-config supergraph.yaml

# Run tests for a specific subgraph
rover connector test \
  --supergraph-config supergraph.yaml \
  --subgraph products
```

## connector list

List all available connectors in the supergraph:

```bash
rover connector list --supergraph-config supergraph.yaml
```

## connector analyze (macOS only)

Analyze one or more API requests for use in generating a connector schema:

```bash
rover connector analyze \
  --supergraph-config supergraph.yaml \
  -- curl https://api.example.com/products
```

## connector generate (macOS only)

Generate a schema with connectors from previously analyzed data:

```bash
rover connector generate --supergraph-config supergraph.yaml
```

## Common Options

| Option | Description |
|--------|-------------|
| `--supergraph-config <PATH>` | Path to supergraph config file |
| `--graph-ref <REF>` | GraphOS variant for baseline |
| `--federation-version <VERSION>` | Federation version for composition |

## Usage with rover dev

Start a local development session with connectors:

```bash
# Start the dev session
rover dev --supergraph-config supergraph.yaml

# In another terminal, test a connector
rover connector run \
  --supergraph-config supergraph.yaml \
  --operation "query { products { name } }"
```

For complete connector documentation, see the Apollo Connectors docs.
