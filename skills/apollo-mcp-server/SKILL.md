---
name: apollo-mcp-server
description: >
  Guide for using Apollo MCP Server to connect AI agents with GraphQL APIs.
  Use this skill when: (1) setting up or configuring Apollo MCP Server,
  (2) defining MCP tools from GraphQL operations, (3) using introspection
  tools (introspect, search, validate, execute), (4) troubleshooting
  MCP server connectivity or tool execution issues, (5) customizing server
  behavior with Rhai scripting, (6) building MCP Apps with custom UI.
license: MIT
compatibility: Works with Claude Code, Claude Desktop, Cursor, Goose, Windsurf, Cline, OpenCode.
metadata:
  author: apollographql
  version: "1.2.0"
allowed-tools: Bash(rover:*) Bash(npx:*) Read Write Edit Glob Grep
---

# Apollo MCP Server Guide

Apollo MCP Server exposes GraphQL operations as MCP tools, enabling AI agents to interact with GraphQL APIs through the Model Context Protocol.

## Quick Start

### Option A: New project with Rover CLI (recommended)

Requires Rover CLI v0.37+ and Node.js v18+.

```bash
# 1. Initialize a new MCP project
rover init --mcp

# 2. Run the MCP server alongside your local graph
rover dev --supergraph-config supergraph.yaml --mcp .apollo/mcp.local.yaml
```

This starts a GraphQL server at `http://localhost:4000` and an MCP server at `http://127.0.0.1:8000`.

### Option B: Standalone binary

```bash
# Linux / MacOS
curl -sSL https://mcp.apollo.dev/download/nix/latest | sh

# Windows
iwr 'https://mcp.apollo.dev/download/win/latest' | iex
```

Create `config.yaml` in your project root:

```yaml
# config.yaml
transport:
  type: streamable_http
schema:
  source: local
  path: ./schema.graphql
operations:
  source: local
  paths:
    - ./operations/
introspection:
  introspect:
    enabled: true
  search:
    enabled: true
  validate:
    enabled: true
  execute:
    enabled: true
```

Start the server:
```bash
apollo-mcp-server ./config.yaml
```

The MCP endpoint is available at `http://127.0.0.1:8000/mcp` (streamable_http defaults: address `127.0.0.1`, port `8000`). The GraphQL endpoint defaults to `http://localhost:4000/` — override with the `endpoint` key if your API runs elsewhere.

### Connect to an MCP client

**Claude Desktop** (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "graphql-api": {
      "command": "npx",
      "args": ["mcp-remote", "http://127.0.0.1:8000/mcp"]
    }
  }
}
```

**Claude Code:**
```bash
claude mcp add graphql-api -- npx mcp-remote http://127.0.0.1:8000/mcp
```

**Stdio (client launches the server directly):**
```json
{
  "mcpServers": {
    "graphql-api": {
      "command": "./apollo-mcp-server",
      "args": ["./config.yaml"]
    }
  }
}
```

## Built-in Tools

Apollo MCP Server provides four introspection tools:

| Tool | Purpose | When to Use |
|------|---------|-------------|
| `introspect` | Explore schema types in detail | Need type definitions, fields, relationships |
| `search` | Find types in schema | Looking for specific types or fields |
| `validate` | Check operation validity | Before executing operations |
| `execute` | Run ad-hoc GraphQL operations | Testing or one-off queries |

## Defining Custom Tools

MCP tools are created from GraphQL operations. Three methods:

### 1. Operation Files (Recommended)

```yaml
operations:
  source: local
  paths:
    - ./operations/
```

Each file must contain exactly one named operation. Each operation becomes an MCP tool.

```graphql
# operations/GetUser.graphql
query GetUser($id: ID!) {
  user(id: $id) {
    id
    name
    email
  }
}
```

### 2. Operation Collections

```yaml
operations:
  source: collection
  id: your-collection-id
graphos:
  apollo_key: ${env.APOLLO_KEY}
  apollo_graph_ref: my-graph@current
```

Use GraphOS Studio to manage operations collaboratively.

### 3. Persisted Queries

```yaml
operations:
  source: manifest
  path: ./persisted-query-manifest.json
```

For production environments with pre-approved operations.

## Reference Files

Detailed documentation for specific topics:

- [Tools](references/tools.md) - Introspection tools and minify notation
- [Configuration](references/configuration.md) - All configuration options
- [Deployment](references/deployment.md) - Rover CLI, Docker, Apollo Runtime Container
- [Rhai Scripting](references/rhai-scripting.md) - Customize request lifecycle with scripts
- [MCP Apps](references/mcp-apps.md) - Build custom UI experiences
- [Troubleshooting](references/troubleshooting.md) - Common issues and solutions

## Key Rules

### Security

- **Never expose sensitive operations** without authentication
- Use `headers` configuration for API keys and tokens
- Disable introspection tools in production (they are disabled by default)
- Set `overrides.mutation_mode: explicit` to require confirmation for mutations
- Use GraphOS contract variants to control which schema types AI can access

### Authentication

```yaml
# Static header
headers:
  Authorization: "Bearer ${env.API_TOKEN}"

# Dynamic header forwarding
forward_headers:
  - x-forwarded-token

# OAuth (streamable_http transport)
transport:
  type: streamable_http
  auth:
    servers:
      - https://auth.example.com
    audiences:
      - https://api.example.com
    scopes:
      - read
      - write
    scope_mode: require_all  # require_all | require_any | disabled
```

### Token Optimization

Enable minification to reduce token usage:

```yaml
introspection:
  introspect:
    minify: true
  search:
    minify: true
```

Minified output uses compact notation:
- **T** = type, **I** = input, **E** = enum
- **s** = String, **i** = Int, **b** = Boolean, **f** = Float, **d** = ID
- **!** = required, **[]** = list

### Mutations

Control mutation behavior via the `overrides` section:

```yaml
overrides:
  mutation_mode: all       # Execute mutations directly
  # mutation_mode: explicit  # Require explicit confirmation
  # mutation_mode: none      # Block all mutations (default)
```

## Common Patterns

### GraphOS Cloud Schema

```yaml
# schema.source defaults to uplink — can be omitted when graphos is configured
graphos:
  apollo_key: ${env.APOLLO_KEY}
  apollo_graph_ref: my-graph@production
```

### Local Development

```yaml
transport:
  type: streamable_http
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

### Production Setup

```yaml
transport:
  type: streamable_http
endpoint: https://api.production.com/graphql
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

### Docker (standalone container)

```yaml
transport:
  type: streamable_http
  address: 0.0.0.0
  port: 8000
endpoint: ${env.GRAPHQL_ENDPOINT}
graphos:
  apollo_key: ${env.APOLLO_KEY}
  apollo_graph_ref: ${env.APOLLO_GRAPH_REF}
health_check:
  enabled: true
```

```bash
docker run \
  -p 8000:8000 \
  -v ./config.yaml:/config.yaml \
  -v $PWD/graphql:/data \
  ghcr.io/apollographql/apollo-mcp-server:latest /config.yaml
```

### Rhai Scripting

Customize request behavior without recompiling. Create `rhai/main.rhai` alongside your config:

```rhai
fn on_execute_graphql_operation(ctx) {
    let token = ctx.incoming_request.headers["authorization"];
    if token != "" {
        ctx.headers["x-forwarded-auth"] = token;
    }
}
```

See [Rhai Scripting](references/rhai-scripting.md) for lifecycle hooks and built-in functions.

## Ground Rules

- ALWAYS configure authentication before exposing to AI agents
- ALWAYS use `mutation_mode: explicit` or `mutation_mode: none` in shared environments
- NEVER expose introspection tools with write access to production data
- PREFER operation files over ad-hoc execute for predictable behavior
- PREFER streamable_http transport for remote and multi-client deployments
- PREFER the Apollo Runtime Container for production deployments
- USE stdio only when the MCP client launches the server process directly
- USE GraphOS Studio collections for team collaboration
- USE Rhai scripting for dynamic header forwarding and request routing
