# Apollo MCP Server Configuration Reference

## Table of Contents

- [Configuration File](#configuration-file)
- [Core Settings](#core-settings)
  - [endpoint](#endpoint)
  - [schema](#schema)
  - [operations](#operations)
- [Transport](#transport)
- [Headers](#headers)
- [Introspection](#introspection)
- [Overrides](#overrides)
- [GraphOS Integration](#graphos-integration)
- [Advanced Settings](#advanced-settings)
- [Environment Variables](#environment-variables)
- [Configuration Examples](#configuration-examples)

---

## Configuration File

Apollo MCP Server uses YAML configuration. Pass the config file path as an argument:

```bash
apollo-mcp-server ./path/to/config.yaml
```

---

## Core Settings

### endpoint

The GraphQL API endpoint URL.

```yaml
endpoint: https://api.example.com/graphql
```

**Environment variable override:**
```yaml
endpoint: ${GRAPHQL_ENDPOINT}
```

### schema

Schema source configuration. Four options available:

#### Local File

```yaml
schema:
  source: local
  path: ./schema.graphql
```

#### Multiple Files

```yaml
schema:
  source: local
  paths:
    - ./schemas/*.graphql
    - ./types/**/*.graphql
```

#### GraphOS Uplink

```yaml
schema:
  source: uplink
graphos:
  key: ${APOLLO_KEY}
  graph_ref: my-graph@production
```

#### Introspection

```yaml
schema:
  source: introspect
  # Uses the endpoint to fetch schema
```

### operations

Define which GraphQL operations become MCP tools.

#### Local Files

```yaml
operations:
  source: local
  paths:
    - ./operations/**/*.graphql
```

#### GraphOS Collection

```yaml
operations:
  source: collection
  id: abc123-collection-id
```

#### Persisted Query Manifest

```yaml
operations:
  source: manifest
  path: ./persisted-query-manifest.json
```

#### GraphOS Uplink

```yaml
operations:
  source: uplink
  # Fetches from GraphOS automatically
```

#### Introspection Only

```yaml
operations:
  source: introspect
  # No custom operations, only introspection tools
```

---

## Transport

Configure how the MCP server communicates.

### Stdio (Default)

Standard input/output for CLI integration:

```yaml
transport:
  type: stdio
```

### Streamable HTTP

HTTP server for network access:

```yaml
transport:
  type: streamable_http
  port: 3000
  host: localhost
```

---

## Headers

Configure HTTP headers for GraphQL requests.

### Static Headers

```yaml
headers:
  Authorization: "Bearer ${API_TOKEN}"
  X-API-Key: ${API_KEY}
  Content-Type: application/json
```

### Dynamic Header Passthrough

Forward headers from MCP client requests:

```yaml
headers:
  X-User-Token:
    from: x-forwarded-user-token
  X-Request-ID:
    from: x-request-id
```

### Combined

```yaml
headers:
  # Static
  Authorization: "Bearer ${API_TOKEN}"
  # Dynamic
  X-User-Context:
    from: x-user-context
```

---

## Introspection

Control built-in introspection tools. Each tool is configured separately:

```yaml
introspection:
  introspect:
    enabled: true
    minify: false
  search:
    enabled: true
    minify: false
  validate:
    enabled: true
  execute:
    enabled: true
```

### Disable Specific Tools

```yaml
introspection:
  introspect:
    enabled: true
  search:
    enabled: true
  validate:
    enabled: true
  execute:
    enabled: false  # Disable ad-hoc execution
```

---

## Overrides

Control mutation behavior and other global settings.

```yaml
overrides:
  mutation_mode: explicit  # all | explicit | none
```

### Mutation Modes

| Mode | Description |
|------|-------------|
| `all` | Execute mutations directly |
| `explicit` | Require user confirmation |
| `none` | Block all mutations (default) |

---

## GraphOS Integration

Connect to Apollo GraphOS for managed schemas and operations.

```yaml
graphos:
  key: ${APOLLO_KEY}
  graph_ref: my-graph@production
```

### Environment Variables

```bash
export APOLLO_KEY=service:my-graph:xxxxx
export APOLLO_GRAPH_REF=my-graph@production
```

### With Uplink Schema

```yaml
schema:
  source: uplink
graphos:
  key: ${APOLLO_KEY}
  graph_ref: ${APOLLO_GRAPH_REF}
```

---

## Advanced Settings

### Custom Scalars

Define how custom scalars are handled:

```yaml
scalars:
  DateTime:
    description: ISO 8601 date-time string
    example: "2024-01-15T10:30:00Z"
  JSON:
    description: Arbitrary JSON object
    example: '{"key": "value"}'
  UUID:
    description: UUID v4 string
    example: "550e8400-e29b-41d4-a716-446655440000"
```

### CORS (HTTP Transport)

```yaml
cors:
  origins:
    - http://localhost:3000
    - https://app.example.com
  methods:
    - GET
    - POST
  headers:
    - Content-Type
    - Authorization
```

### Health Check

```yaml
health_check:
  enabled: true
  path: /health
```

Endpoints:
- `/health` - Overall health
- `/health?live` - Liveness probe
- `/health?ready` - Readiness probe

### Telemetry

```yaml
telemetry:
  enabled: true
  service_name: graphql-mcp-server
  otlp_endpoint: http://localhost:4317
```

---

## Environment Variables

All settings support environment variable substitution with `${VAR_NAME}`.

### Apollo MCP Specific Variables

| Variable | Description |
|----------|-------------|
| `APOLLO_MCP_CONFIG` | Config file path |
| `APOLLO_MCP_ENDPOINT` | GraphQL endpoint |
| `APOLLO_MCP_LOG_LEVEL` | Logging level (debug, info, warn, error) |

### GraphOS Variables

| Variable | Description |
|----------|-------------|
| `APOLLO_KEY` | GraphOS API key |
| `APOLLO_GRAPH_REF` | Graph reference (graph-id@variant) |

---

## Configuration Examples

### Minimal Local Development

```yaml
endpoint: http://localhost:4000/graphql
schema:
  source: introspect
introspection:
  introspect:
    enabled: true
  search:
    enabled: true
  validate:
    enabled: true
  execute:
    enabled: true
overrides:
  mutation_mode: all
```

### Production with GraphOS

```yaml
endpoint: ${GRAPHQL_ENDPOINT}
schema:
  source: uplink
operations:
  source: manifest
  path: ./persisted-query-manifest.json
graphos:
  key: ${APOLLO_KEY}
  graph_ref: ${APOLLO_GRAPH_REF}
headers:
  Authorization: "Bearer ${API_TOKEN}"
introspection:
  introspect:
    enabled: false
  search:
    enabled: false
  validate:
    enabled: false
  execute:
    enabled: false
transport:
  type: streamable_http
  port: ${PORT:-3000}
health_check:
  enabled: true
```

### Team Development

```yaml
endpoint: https://dev-api.example.com/graphql
schema:
  source: local
  path: ./schema.graphql
operations:
  source: local
  paths:
    - ./operations/**/*.graphql
headers:
  Authorization: "Bearer ${DEV_API_TOKEN}"
introspection:
  introspect:
    enabled: true
    minify: true
  search:
    enabled: true
    minify: true
  validate:
    enabled: true
  execute:
    enabled: true
overrides:
  mutation_mode: explicit
```

### Read-Only Analytics

```yaml
endpoint: https://analytics.example.com/graphql
schema:
  source: local
  path: ./analytics-schema.graphql
operations:
  source: local
  paths:
    - ./queries/**/*.graphql  # Only queries, no mutations
introspection:
  introspect:
    enabled: true
  search:
    enabled: true
  validate:
    enabled: true
  execute:
    enabled: false
overrides:
  mutation_mode: none
```

### Multi-Environment

```yaml
endpoint: ${GRAPHQL_ENDPOINT}
schema:
  source: ${SCHEMA_SOURCE:-local}
  path: ${SCHEMA_PATH:-./schema.graphql}
operations:
  source: local
  paths:
    - ./operations/**/*.graphql
headers:
  Authorization: "Bearer ${API_TOKEN}"
introspection:
  introspect:
    enabled: ${INTROSPECTION_ENABLED:-false}
  search:
    enabled: ${INTROSPECTION_ENABLED:-false}
  validate:
    enabled: ${INTROSPECTION_ENABLED:-false}
  execute:
    enabled: ${INTROSPECTION_ENABLED:-false}
overrides:
  mutation_mode: ${MUTATION_MODE:-explicit}
```
