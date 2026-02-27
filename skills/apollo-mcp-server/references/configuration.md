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

The GraphQL API endpoint URL. Defaults to `http://localhost:4000/`.

```yaml
endpoint: https://api.example.com/graphql
```

### schema

Schema source configuration. Two options available:

#### Local File

```yaml
schema:
  source: local
  path: ./schema.graphql
```

#### GraphOS Uplink (Default)

`uplink` is the default schema source. When using uplink, you can omit the `schema` section entirely if `graphos` credentials are configured.

```yaml
schema:
  source: uplink
graphos:
  apollo_key: ${env.APOLLO_KEY}
  apollo_graph_ref: my-graph@production
```

### operations

Define which GraphQL operations become MCP tools. Defaults to `infer` (auto-discovers from schema).

#### Infer (Default)

```yaml
operations:
  source: infer
```

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
```

---

## Transport

Configure how the MCP server communicates.

### Streamable HTTP

HTTP server for network access and multi-client deployments:

```yaml
transport:
  type: streamable_http
```

Defaults: `address: 127.0.0.1`, `port: 8000`. The MCP endpoint is served at `http://127.0.0.1:8000/mcp`.

| Option | Default | Description |
|--------|---------|-------------|
| `address` | `127.0.0.1` | Bind address |
| `port` | `8000` | Listen port |
| `stateful_mode` | - | Session handling mode |

#### Host Validation

Controls which `Host` header values are accepted (streamable_http only):

```yaml
transport:
  type: streamable_http
  host_validation:
    enabled: true
    allowed_hosts:
      - "example.com"
      - "*.example.com"
```

#### Auth

OAuth-based authentication for streamable_http transport:

```yaml
transport:
  type: streamable_http
  auth:
    servers:
      - https://auth.example.com/.well-known/openid-configuration
    audiences:
      - https://api.example.com
    scopes:
      - read
      - write
    scope_mode: any  # any | all
```

### Stdio (Default)

Standard input/output for direct CLI integration. This is the default transport when no `transport` section is specified:

```yaml
transport:
  type: stdio
```

> **Note:** SSE transport was removed in v1.5.0. Use `streamable_http` instead.

---

## Headers

Configure HTTP headers for GraphQL requests.

### Static Headers

```yaml
headers:
  Authorization: "Bearer ${env.API_TOKEN}"
  X-API-Key: ${env.API_KEY}
```

### Dynamic Header Forwarding

Forward headers from MCP client requests to the upstream GraphQL API:

```yaml
forward_headers:
  - x-forwarded-user-token
  - x-request-id
```

### Combined

```yaml
headers:
  Authorization: "Bearer ${env.API_TOKEN}"
forward_headers:
  - x-user-context
  - x-request-id
```

---

## Introspection

Control built-in introspection tools. All tools are disabled by default.

```yaml
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
  apollo_key: ${env.APOLLO_KEY}
  apollo_graph_ref: my-graph@production
```

### With Uplink Schema

```yaml
graphos:
  apollo_key: ${env.APOLLO_KEY}
  apollo_graph_ref: ${env.APOLLO_GRAPH_REF}
```

---

## Advanced Settings

### Custom Scalars

Define how custom scalars are described to AI agents via an external JSON file:

```yaml
custom_scalars: ./scalars.json
```

```json
// scalars.json
{
  "DateTime": "ISO 8601 date-time string (e.g. 2024-01-15T10:30:00Z)",
  "JSON": "Arbitrary JSON object",
  "UUID": "UUID v4 string (e.g. 550e8400-e29b-41d4-a716-446655440000)"
}
```

### CORS (Streamable HTTP Transport)

```yaml
cors:
  allow_origins:
    - http://localhost:3000
    - https://app.example.com
  allow_methods:
    - GET
    - POST
  allow_headers:
    - Content-Type
    - Authorization
  allow_credentials: true
```

### Health Check

Health check is disabled by default. Applies to streamable_http transport only.

```yaml
health_check:
  enabled: true
  path: /health  # default
```

| Option | Default | Description |
|--------|---------|-------------|
| `enabled` | `false` | Enable health endpoint |
| `path` | `/health` | Health check path |

Endpoints:
- `GET /health` - Overall health: `{"status": "UP"}`
- `GET /health?live` - Liveness probe
- `GET /health?ready` - Readiness probe

### Logging

```yaml
logging:
  level: info  # debug | info | warn | error
  path: ./logs/mcp-server.log
  rotation: daily
```

### Telemetry

```yaml
telemetry:
  exporters:
    metrics:
      otlp:
        endpoint: http://localhost:4317
    tracing:
      otlp:
        endpoint: http://localhost:4317
  service_name: graphql-mcp-server
```

---

## Environment Variables

### Config File Expansion

Use `${env.VAR_NAME}` syntax inside YAML config files to reference environment variables:

```yaml
endpoint: ${env.GRAPHQL_ENDPOINT}
headers:
  Authorization: "Bearer ${env.API_TOKEN}"
graphos:
  apollo_key: ${env.APOLLO_KEY}
```

### Environment Variable Overrides

Any config option can be overridden via environment variables using the `APOLLO_MCP_` prefix with `__` (double underscore) as the nesting separator:

```bash
# Override transport type
export APOLLO_MCP_TRANSPORT__TYPE=streamable_http

# Override transport port
export APOLLO_MCP_TRANSPORT__PORT=9000

# Override logging level
export APOLLO_MCP_LOGGING__LEVEL=debug
```

### GraphOS Variables

| Variable | Description |
|----------|-------------|
| `APOLLO_KEY` | GraphOS API key |
| `APOLLO_GRAPH_REF` | Graph reference (graph@variant) |

---

## Configuration Examples

### Minimal Local Development

```yaml
schema:
  source: local
  path: ./schema.graphql
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
transport:
  type: streamable_http
endpoint: ${env.GRAPHQL_ENDPOINT}
operations:
  source: manifest
  path: ./persisted-query-manifest.json
graphos:
  apollo_key: ${env.APOLLO_KEY}
  apollo_graph_ref: ${env.APOLLO_GRAPH_REF}
headers:
  Authorization: "Bearer ${env.API_TOKEN}"
health_check:
  enabled: true
```

### Team Development

```yaml
transport:
  type: streamable_http
endpoint: https://dev-api.example.com/graphql
schema:
  source: local
  path: ./schema.graphql
operations:
  source: local
  paths:
    - ./operations/**/*.graphql
headers:
  Authorization: "Bearer ${env.DEV_API_TOKEN}"
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
    - ./queries/**/*.graphql
introspection:
  introspect:
    enabled: true
  search:
    enabled: true
  validate:
    enabled: true
```
