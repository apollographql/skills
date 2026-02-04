# Apollo MCP Server Troubleshooting

## Table of Contents

- [Debugging with MCP Inspector](#debugging-with-mcp-inspector)
- [Connection Issues](#connection-issues)
- [Authentication Problems](#authentication-problems)
- [Schema Issues](#schema-issues)
- [Tool Execution Errors](#tool-execution-errors)
- [Health Check](#health-check)

---

## Debugging with MCP Inspector

[MCP Inspector](https://modelcontextprotocol.io/docs/tools/inspector) is a debugging tool for MCP servers.

### Debug locally with rover dev

When running your MCP server locally with `rover dev`:

1. Start your MCP server:

```bash
rover dev --supergraph-config supergraph.yaml --mcp .apollo/mcp.local.yaml
```

2. In a new terminal, run MCP Inspector:

```bash
npx @modelcontextprotocol/inspector http://127.0.0.1:8000/mcp --transport http
```

3. Open the URL returned by Inspector in your browser, click **Connect**, then **List Tools** to see available tools.

### Debug with standalone binary

If running the MCP server as a standalone binary:

1. Create a config file with stdio transport:

```yaml
operations:
  source: local
  paths:
    - /path/to/operations/
schema:
  source: local
  path: /path/to/schema.graphql
transport:
  type: stdio
```

2. Run the MCP server with Inspector:

```bash
npx @modelcontextprotocol/inspector \
  apollo-mcp-server /path/to/config.yaml
```

### Inspector Features

- View available tools and their schemas
- Test tool invocations interactively
- Inspect request/response payloads
- Monitor server logs in real-time

---

## Connection Issues

### Server Won't Start

**Symptoms:** Server exits immediately or hangs

**Solutions:**

1. Check config file syntax:
```bash
# Validate YAML
npx yaml-lint config.yaml
```

2. Verify endpoint is reachable:
```bash
curl -I https://api.example.com/graphql
```

3. Enable debug logging:

   With rover dev:
   ```bash
   APOLLO_ROUTER_LOG=debug rover dev --supergraph-config supergraph.yaml --mcp config.yaml
   ```

   With standalone binary:
   ```bash
   APOLLO_MCP_LOG_LEVEL=debug apollo-mcp-server config.yaml
   ```

### Client Can't Connect

**Symptoms:** MCP client shows "server not found" or timeout

**Solutions:**

1. Verify the MCP server is running:

   With rover dev:
   ```bash
   # Check that rover dev is running and shows MCP server on port 8000
   rover dev --supergraph-config supergraph.yaml --mcp config.yaml
   ```

   With standalone binary via MCP client config:
   ```json
   {
     "mcpServers": {
       "graphql": {
         "command": "apollo-mcp-server",
         "args": ["/absolute/path/to/config.yaml"]
       }
     }
   }
   ```

2. For HTTP transport, verify the server is accessible:
```bash
curl http://127.0.0.1:8000/health
```

3. Check if the standalone binary is installed (if using standalone mode):
```bash
which apollo-mcp-server
```

---

## Authentication Problems

### 401 Unauthorized

**Symptoms:** All requests return 401

**Solutions:**

1. Verify API token is set:
```bash
echo $API_TOKEN  # Should not be empty
```

2. Check header configuration:
```yaml
headers:
  Authorization: "Bearer ${API_TOKEN}"  # Note: Bearer prefix required
```

3. Test token directly:
```bash
curl -H "Authorization: Bearer $API_TOKEN" https://api.example.com/graphql
```

### Token Security Best Practices

- **Never commit tokens** to version control
- Use environment variables or secrets management
- Rotate tokens regularly
- Use minimum required permissions

### OAuth Token Forwarding

For user-specific tokens:

```yaml
headers:
  Authorization:
    from: x-forwarded-authorization
```

**Security Warning:** Forwarding OAuth tokens exposes them to the MCP server. Ensure:
- Server runs in trusted environment
- Transport is encrypted (HTTPS)
- Tokens have minimal scope

---

## Schema Issues

### Schema Not Found

**Symptoms:** "Schema file not found" error

**Solutions:**

1. Check file path (use absolute paths):
```yaml
schema:
  source: local
  path: /absolute/path/to/schema.graphql
```

2. Verify file exists:
```bash
ls -la ./schema.graphql
```

### Schema Introspection Failed

**Symptoms:** Can't fetch schema from endpoint

**Solutions:**

1. Check if introspection is enabled on server:
```bash
curl -X POST https://api.example.com/graphql \
  -H "Content-Type: application/json" \
  -d '{"query": "{ __schema { types { name } } }"}'
```

2. Use local schema file instead:
```yaml
schema:
  source: local
  path: ./schema.graphql
```

### GraphOS Uplink Errors

**Symptoms:** "Failed to fetch schema from uplink"

**Solutions:**

1. Verify GraphOS credentials:
```bash
echo $APOLLO_KEY
echo $APOLLO_GRAPH_REF
```

2. Check graph reference format:
```yaml
graphos:
  graph_ref: my-graph@production  # Format: graph-id@variant
```

---

## Tool Execution Errors

### Operation Validation Failed

**Symptoms:** "Field X not found on type Y"

**Solutions:**

1. Ensure schema is up to date
2. Use `validate` tool before `execute`:
```
validate(operation: "query { user { id name } }")
```

### Mutation Blocked

**Symptoms:** "Mutations are disabled"

**Solutions:**

Check mutation mode in config:
```yaml
overrides:
  mutation_mode: all  # Or 'explicit' for confirmation
```

### Variable Type Mismatch

**Symptoms:** "Variable $id expected ID!, got String"

**Solutions:**

Ensure variable types match operation:
```graphql
# Operation expects ID!
query GetUser($id: ID!) { ... }

# Correct invocation
execute(variables: { id: "123" })  # String coerced to ID
```

---

## Health Check

For HTTP transport, health endpoints help diagnose issues.

### Endpoints

| Endpoint | Purpose |
|----------|---------|
| `/health` | Overall health status |
| `/health?live` | Liveness probe (is server running?) |
| `/health?ready` | Readiness probe (can server handle requests?) |

### Status Codes

| Code | Meaning |
|------|---------|
| 200 | Healthy |
| 503 | Unhealthy |

### Example Check

```bash
curl http://localhost:3000/health
# {"status": "healthy", "checks": {"schema": "ok", "endpoint": "ok"}}

curl http://localhost:3000/health?ready
# {"status": "ready"}
```

### Common Health Issues

**Schema check failing:**
- Schema file missing or invalid
- GraphOS uplink unreachable

**Endpoint check failing:**
- GraphQL endpoint unreachable
- Network/firewall issues
- Authentication problems

---

## Getting Help

If issues persist:

1. Enable debug logging:

   With rover dev:
   ```bash
   APOLLO_ROUTER_LOG=debug rover dev --supergraph-config supergraph.yaml --mcp config.yaml
   ```

   With standalone binary:
   ```bash
   APOLLO_MCP_LOG_LEVEL=debug apollo-mcp-server config.yaml
   ```

2. Check Apollo documentation: https://apollographql.com/docs/apollo-mcp-server

3. Report issues: https://github.com/apollographql/apollo-mcp-server/issues
