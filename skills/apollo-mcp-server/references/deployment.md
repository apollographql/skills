# Apollo MCP Server Deployment Reference

## Running the server

### With Rover CLI (recommended for local development)

Rover CLI v0.37+ can run the MCP server alongside your local graph using `rover dev`:

```bash
# Initialize a new project with MCP support
rover init --mcp

# Run the MCP server with your local graph
rover dev --supergraph-config supergraph.yaml --mcp .apollo/mcp.local.yaml
```

This starts both a GraphQL server at `http://localhost:4000` and an MCP server at `http://127.0.0.1:8000`.

### Standalone binary

Install the latest release:

```bash
# Linux / MacOS
curl -sSL https://mcp.apollo.dev/download/nix/latest | sh

# Windows
iwr 'https://mcp.apollo.dev/download/win/latest' | iex
```

Install a specific version (recommended for CI):

```bash
# Linux / MacOS
curl -sSL https://mcp.apollo.dev/download/nix/v1.12.0 | sh

# Windows
iwr 'https://mcp.apollo.dev/download/win/v1.12.0' | iex
```

Run with a config file:

```bash
apollo-mcp-server ./config.yaml
```

The server watches the config file and restarts automatically when it changes.

CLI options:

| Option | Description |
|--------|-------------|
| `-h, --help` | Print help information |
| `-V, --version` | Print version information |

### With Docker (standalone container)

The standalone container image is `ghcr.io/apollographql/apollo-mcp-server`. The container defaults to:

- Working directory `/data` for schema and operation files
- Streamable HTTP transport on port 8000

```bash
docker run \
  -it --rm \
  --name apollo-mcp-server \
  -p 8000:8000 \
  -v ./config.yaml:/config.yaml \
  -v $PWD/graphql:/data \
  --pull always \
  ghcr.io/apollographql/apollo-mcp-server:latest /config.yaml
```

Pull a specific version:

```bash
docker image pull ghcr.io/apollographql/apollo-mcp-server:v1.12.0
```

### With the Apollo Runtime Container (recommended for production)

The Apollo Runtime Container runs both Apollo Router (GraphQL) and Apollo MCP Server in a single container. This is the recommended option for most production deployments.

```bash
docker run \
  -p 4000:4000 \
  -p 8000:8000 \
  --env APOLLO_GRAPH_REF="<your-graph-ref>" \
  --env APOLLO_KEY="<your-graph-api-key>" \
  --env MCP_ENABLE=1 \
  -v /path/to/config:/config/mcp_config.yaml \
  --rm \
  ghcr.io/apollographql/apollo-runtime:latest
```

This fetches your schema from GraphOS and uses GraphOS-managed persisted queries for MCP tools.

## Choosing a deployment option

| Scenario | Option | Why |
|----------|--------|-----|
| Local development | `rover dev` | Runs GraphQL + MCP together, fast iteration |
| Existing GraphQL API | Standalone container | Connect to your existing endpoint |
| New GraphQL + MCP deployment | Apollo Runtime Container | Single container, simpler operations |
| GraphOS-managed graph | Apollo Runtime Container | Automatic schema/query sync, unified telemetry |
| Kubernetes / orchestrated | Apollo Runtime Container | Fewer moving parts, simpler networking |

## Production considerations

### Session affinity (sticky sessions)

MCP is a stateful protocol. When an MCP client initializes a session it receives a `mcp-session-id` header unique to that server instance. Configure your load balancer to route all requests with the same `mcp-session-id` to the same backend.

Most cloud load balancers (AWS ALB, GCP LB) don't support header-based session affinity. Use Nginx, HAProxy, or Envoy/Istio for proper session routing.

### Stateless mode

To enable horizontal scaling without sticky sessions, run the server in stateless mode. Each request is handled independently — no session ID is passed between client and server.

```yaml
transport:
  type: streamable_http
  stateful_mode: false
```

Note: only use stateless mode if your MCP client doesn't depend on session state.

### Required environment variables

| Variable | Description |
|----------|-------------|
| `APOLLO_KEY` | GraphOS API key |
| `APOLLO_GRAPH_REF` | Graph reference (`graph@variant`) |
| `APOLLO_MCP_TRANSPORT__PORT` | MCP server port (default: `8000`) |
| `APOLLO_ROUTER_PORT` | Router port, Apollo Runtime Container only (default: `4000`) |

### Post-deployment checklist

After deploying, configure:

1. [Health checks](configuration.md#health-check) for monitoring and readiness probes
2. CORS settings if browser clients need access
3. [Authorization](../SKILL.md#authentication) for production security
