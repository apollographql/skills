---
name: apollo-mcp-server
description: >
  Guide for using Apollo MCP Server to connect AI agents with GraphQL APIs.
  Use this skill when: (1) setting up or configuring Apollo MCP Server,
  (2) defining MCP tools from GraphQL operations, (3) using introspection
  tools (introspect, search, validate, execute), (4) troubleshooting
  MCP server connectivity or tool execution issues.
license: MIT
compatibility: Works with Claude Code, Claude Desktop, Cursor.
metadata:
  author: apollographql
  version: "1.0.2"
allowed-tools: Bash(rover:*) Bash(curl:*) Bash(npx:*) Read Write Edit Glob Grep
---

# Apollo MCP Server Guide

Apollo MCP Server exposes GraphQL operations as MCP tools, enabling AI agents to interact with GraphQL APIs through the Model Context Protocol.

## Quick Start

### Step 1: Install

```bash
# Linux / MacOS
curl -sSL https://mcp.apollo.dev/download/nix/latest | sh


# Windows
iwr 'https://mcp.apollo.dev/download/win/v1.6.0' | iex
```

### Step 2: Configure

Create `config.yaml` in your project root:

```yaml
# config.yaml
endpoint: https://api.example.com/graphql
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

### Step 3: Connect

Add to your MCP client configuration:

**Claude Desktop (`claude_desktop_config.json`):**
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

**Claude Code (`.mcp.json`):**
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

```graphql
# operations/users.graphql
query GetUser($id: ID!) {
  user(id: $id) {
    id
    name
    email
  }
}

mutation CreateUser($input: CreateUserInput!) {
  createUser(input: $input) {
    id
    name
  }
}
```

Each named operation becomes an MCP tool.

### 2. Operation Collections

```yaml
operations:
  source: collection
  id: your-collection-id
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
- [Troubleshooting](references/troubleshooting.md) - Common issues and solutions

## Key Rules

### Security

- **Never expose sensitive operations** without authentication
- Use `headers` configuration for API keys and tokens
- Disable introspection tools in production (set `enabled: false` for each tool)
- Set `overrides.mutation_mode: explicit` to require confirmation for mutations

### Authentication

```yaml
# Static header
headers:
  Authorization: "Bearer ${APOLLO_API_KEY}"

# Dynamic header passthrough
headers:
  X-User-Token:
    from: x-forwarded-token
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
- **s** = String, **i** = Int, **b** = Boolean, **f** = Float
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
schema:
  source: uplink
graphos:
  apollo_key: ${APOLLO_KEY}
  apollo_graph_ref: my-graph@production
```

### Local Development

```yaml
endpoint: http://localhost:4000/graphql
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
endpoint: https://api.production.com/graphql
schema:
  source: uplink
operations:
  source: manifest
  path: ./persisted-query-manifest.json
introspection:
  introspect:
    enabled: false
  search:
    enabled: false
  validate:
    enabled: false
  execute:
    enabled: false
```

## Ground Rules

- ALWAYS configure authentication before exposing to AI agents
- ALWAYS use `mutation_mode: explicit` or `mutation_mode: none` in shared environments
- NEVER expose introspection tools with write access to production data
- PREFER operation files over ad-hoc execute for predictable behavior
- USE GraphOS Studio collections for team collaboration
