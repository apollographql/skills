# Rover Connector Commands

Commands for working with Apollo Connectors, which bridge REST APIs into a GraphQL supergraph. These commands require Federation version 2.12.0 or later.

## Shared Options

All `rover connector` subcommands accept these options:

| Option | Description |
|--------|-------------|
| `--supergraph-config <PATH>` | Path to `supergraph.yaml`. Auto-detected if present in the current directory. |
| `--graph-ref <REF>` | GraphOS graph reference as baseline (like `rover dev`). |
| `--federation-version <VERSION>` | Federation version for composition. Defaults to latest 2.x. Must be >= 2.12.0. |

If a `supergraph.yaml` contains a single subgraph, its schema path is used as the default for commands that accept `--schema`.

## connector list

List all connectors defined in a subgraph schema.

```bash
# List connectors in a schema file
rover connector list --schema ./schema.graphql

# List connectors (auto-detected from single-subgraph supergraph.yaml)
rover connector list
```

**Options:**
| Option | Description |
|--------|-------------|
| `--schema <PATH>` | Path to the schema file. Optional if `supergraph.yaml` has one subgraph. |

**Output:** Each connector's ID (used by `connector run`) and the type or field it is attached to.

## connector run

Execute a single connector against a live REST endpoint to verify its request/response mapping.

```bash
# Run a connector on a field
rover connector run \
  --schema ./schema.graphql \
  --connector-id "Query.products" \
  --variables '{"$args": {"id": "123"}}'

# Run a connector on a type
rover connector run \
  --schema ./schema.graphql \
  --connector-id "Product" \
  --variables '{"$this": {"id": "456"}}'

# When multiple connectors exist on the same element, use an index
rover connector run \
  --schema ./schema.graphql \
  --connector-id "Query.search[1]" \
  --variables '{"$args": {"query": "test"}}'
```

**Options:**
| Option | Description |
|--------|-------------|
| `--schema <PATH>` | Path to the schema file. Optional if `supergraph.yaml` has one subgraph. |
| `-c, --connector-id <ID>` | Connector ID (required). Use `connector list` to find IDs. |
| `-v, --variables <JSON>` | JSON variables for the connector (required). Every top-level key must be `$args`, `$this`, `$batch` or `$config`. |

**Connector ID forms:**

| Form | Example | Meaning |
|------|---------|---------|
| `Type` | `Product` | Connector on the type itself |
| `Type.field` | `Query.products` | Connector on a specific field |
| `Type.field[N]` | `Query.search[1]` | Nth connector when multiple exist on one element |

**Output:** The HTTP request Rover sent (method, URI, headers), the raw response (status, body, headers), the mapped GraphQL data, and any mapping problems.

## connector test

Run test suites that validate connector behavior using recorded request/response fixtures.

```bash
# Run all tests in the default directory (tests/)
rover connector test

# Run tests from a specific file
rover connector test --file tests/products.connector.yml

# Run tests from a specific directory
rover connector test --directory integration-tests/

# Override the schema file
rover connector test --schema ./schema.graphql

# Generate a JUnit XML report
rover connector test --report junit-results.xml

# Continue running after failures
rover connector test --no-fail-fast
```

**Options:**
| Option | Description |
|--------|-------------|
| `-f, --file <PATH>` | Path to a single test suite file. |
| `-d, --directory <PATH>` | Directory of test suites (`*.connector.yml`). Defaults to `tests/`. |
| `--schema <PATH>` | Schema file override for all test suites. |
| `--no-fail-fast` | Log errors without failing the process. |
| `--report <PATH>` | Write JUnit XML report to this path. |
| `-q, --quiet` | Suppress test progress output. |
| `-v, --verbose` | Enable verbose logging. |

If neither `--file` nor `--directory` is provided, Rover looks for test files in `tests/`.

## connector analyze (macOS only)

Capture and analyze HTTP requests for use in generating connector schemas. Available on macOS only.

### analyze curl

Record a single HTTP request for analysis.

```bash
rover connector analyze curl https://api.example.com/products \
  -X GET \
  -H "Authorization: Bearer token"

# With request body
rover connector analyze curl https://api.example.com/products \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{"query": "test"}'

# Save to a custom analysis directory
rover connector analyze curl https://api.example.com/products \
  --analysis-dir ./my-analysis
```

**Options:**
| Option | Description |
|--------|-------------|
| `<URL>` | Endpoint URL (required). |
| `-X <METHOD>` | HTTP method (GET, POST, etc.). |
| `-H <HEADER>` | HTTP header in `Name: Value` format. Repeatable. |
| `-d <DATA>` | JSON request body. |
| `-t <SECONDS>` | Connection timeout. |
| `--analysis-dir <PATH>` | Directory to save analysis data. |

### analyze interactive

Start a local proxy server that captures HTTP traffic for analysis.

```bash
rover connector analyze interactive

# Use a custom port (default: 9999)
rover connector analyze interactive --port 8080
```

### analyze clean

Remove previously saved analysis snapshots.

```bash
rover connector analyze clean
```

## connector generate (macOS only)

Generate a GraphQL schema with connector directives from previously analyzed requests. Run `connector analyze` first to capture request/response data.

```bash
# Generate from default analysis directory
rover connector generate

# Custom output name (creates <name>.graphql)
rover connector generate --name products

# Custom directories
rover connector generate \
  --analysis-dir ./my-analysis \
  --output-dir ./generated
```

**Options:**
| Option | Description |
|--------|-------------|
| `-n, --name <NAME>` | Output file name (without extension). Defaults to `output`. |
| `--analysis-dir <PATH>` | Directory containing analysis data. Defaults to `./analysis/`. |
| `--output-dir <PATH>` | Directory for generated files. Defaults to `build/connectors/`. |

## Workflow

### Developing a connector from scratch (macOS)

```bash
# 1. Analyze your REST API endpoints
rover connector analyze curl https://api.example.com/users -X GET
rover connector analyze curl https://api.example.com/users/123 -X GET

# 2. Generate a connector schema
rover connector generate --name users

# 3. Review and edit the generated schema
# 4. List connectors to verify
rover connector list --schema ./build/connectors/users.graphql

# 5. Test a connector against the live API
rover connector run \
  --schema ./build/connectors/users.graphql \
  --connector-id "Query.users" \
  --variables '{}'
```

### Testing connectors in CI

```bash
# Run all connector tests with JUnit output
rover connector test --report test-results.xml

# Run tests without stopping on first failure
rover connector test --no-fail-fast --report test-results.xml
```
