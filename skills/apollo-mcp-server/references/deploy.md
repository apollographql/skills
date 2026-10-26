# Deployment

## Installation

### Installer script

```bash
# Linux / macOS
curl -sSL https://mcp.apollo.dev/download/nix/latest | sh

# Windows
iwr 'https://mcp.apollo.dev/download/win/latest' | iex
```

### Build from source

```bash
cargo install --locked apollo-mcp-server
```

`--locked` builds with the same dependency versions tested for the release.

## Deployment options

### Apollo GraphOS Operator (Kubernetes)

Use the [Apollo GraphOS Operator](https://www.apollographql.com/docs/apollo-operator/) to deploy Apollo MCP Server on Kubernetes. The operator manages the Deployment, Service, ConfigMap, and an ephemeral graph API key Secret.

Requirements:

- Apollo GraphOS Operator v1.5.0 or later
- Apollo GraphOS Developer, Standard, or Enterprise plan

The operator forces `transport.stateful_mode: false`, so no session-affinity configuration is needed. Its plain Kubernetes Service works without special load balancer setup.

Scale with `spec.replicas` on the `McpServer` resource, or attach a Kubernetes `HorizontalPodAutoscaler` directly to it. The operator exposes a `scale` subresource, so the `McpServer` itself can be the autoscaling target.

### Apollo Runtime Container (non-Kubernetes)

The all-in-one Apollo Runtime Container includes Apollo Router and Apollo MCP Server in a single image. Both port `4000` (GraphQL) and port `8000` (MCP) are exposed.

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

This fetches the schema from GraphOS, starts the router, and enables the MCP endpoint at `/mcp`. By default it uses GraphOS-managed persisted queries for MCP tools.

Benefits:

- Single container to deploy and monitor
- Co-located Router and MCP Server for optimized performance
- Scale both GraphQL and MCP together as one unit

### Standalone Apollo MCP Server container

Use the standalone container when you already have a GraphQL API running elsewhere.

The container expects schema and operation files in the `/data` directory and serves Streamable HTTP on port `8000`.

```yaml
# mcp_config.yaml
endpoint: https://your-graphql-api.example.com/
operations:
  source: local
  paths:
    - /data/operations/
schema:
  source: local
  path: /data/api.graphql
```

```bash
docker run \
  -it --rm \
  -p 8000:8000 \
  -v ./mcp_config.yaml:/config.yaml \
  -v ./data:/data \
  --pull always \
  ghcr.io/apollographql/apollo-mcp-server:latest /config.yaml
```

Scale Apollo MCP Server independently of your GraphQL API for fine-tuned resource allocation.

### Local development with `rover dev`

Use `rover dev` to develop locally with both GraphQL and MCP running together. See the [Rover CLI documentation](https://www.apollographql.com/docs/apollo-mcp-server/run#with-the-rover-cli).

## When to choose which option

| Scenario | Recommended option | Why |
|---|---|---|
| Kubernetes with GraphOS-managed graph | Apollo GraphOS Operator | Manages the full resource lifecycle automatically |
| New GraphQL + MCP deployment (non-K8s) | Apollo Runtime Container | Single container, optimized performance |
| GraphOS-managed graph (non-K8s) | Apollo Runtime Container | Automatic schema and persisted query sync |
| Adding MCP to an existing GraphQL API | Standalone container | Connects to your existing endpoint |
| Local development | `rover dev` | Runs both GraphQL and MCP locally |

## Load balancing and session affinity

Clients that negotiate MCP protocol `2026-07-28` or later are always sessionless and need no session affinity. Older protocol versions are stateful and require sticky sessions.

When an older client initializes a session, it receives a session identifier through the `mcp-session-id` header. Configure your load balancer to route all requests sharing the same `mcp-session-id` to the same backend instance.

Load balancers that support header-based session affinity:

- Nginx
- HAProxy
- Envoy / Istio

Cloud load balancers such as AWS ALB and Google Cloud Load Balancer do not support header-based session affinity.

### Stateless mode

Disable session state to allow horizontal scaling without session affinity, even for older protocol clients:

```yaml
transport:
  type: streamable_http
  stateful_mode: false
```

In stateless mode, each request is an independent HTTP POST with no session ID exchange. Unsolicited tool-change notifications are unavailable for older clients in this mode. Clients on `2026-07-28` or later are always sessionless regardless of this setting.

## Production checklist

After deploying, configure:

1. [Health checks](configuration.md#health-check) for liveness and readiness probes
2. [CORS](configuration.md#cors) for browser-based MCP clients
3. [Authentication](auth.md) for production security
4. [Telemetry](telemetry.md) for observability
