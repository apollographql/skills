# Router Configuration Reference

The Router is configured via a YAML file (`router.yaml`). This reference covers the most common configuration options.

## Basic Structure

```yaml
supergraph:
  listen: 127.0.0.1:4000
  introspection: true
  path: /graphql

sandbox:
  enabled: true

cors:
  origins:
    - "*"

headers:
  all:
    request:
      - propagate:
          matching: ".*"

telemetry:
  # ... telemetry config
```

## Supergraph Configuration

```yaml
supergraph:
  # Address to listen on
  listen: 127.0.0.1:4000

  # GraphQL endpoint path
  path: /graphql

  # Enable introspection queries
  introspection: true

  # Query planning options
  query_planning:
    # Enable query plan caching
    cache:
      in_memory:
        limit: 512
```

## Sandbox and Introspection

```yaml
# Apollo Sandbox (GraphQL IDE)
sandbox:
  enabled: true  # Disabled by default in production

# Introspection (required for Sandbox)
supergraph:
  introspection: true  # Disabled by default in production
```

For development mode, both are enabled automatically with `--dev`.

## CORS Configuration

```yaml
cors:
  # Allowed origins
  origins:
    - http://localhost:3000
    - https://studio.apollographql.com

  # Allow all origins (not recommended for production)
  # origins:
  #   - "*"

  # Allowed headers
  allow_headers:
    - Content-Type
    - Authorization
    - X-Custom-Header

  # Allowed methods (defaults are usually fine)
  methods:
    - GET
    - POST
    - OPTIONS

  # Allow credentials
  allow_credentials: true

  # Max age for preflight cache (seconds)
  max_age: 86400
```

## Subgraph Configuration

```yaml
# Override subgraph URLs (useful for local development)
override_subgraph_url:
  products: http://localhost:4001/graphql
  reviews: http://localhost:4002/graphql

# Subgraph-specific settings
traffic_shaping:
  all:
    timeout: 30s
  subgraphs:
    products:
      timeout: 60s  # Override for slow subgraph
```

## Traffic Shaping

```yaml
traffic_shaping:
  # Apply to all subgraphs
  all:
    # Request timeout
    timeout: 30s

    # Rate limiting
    global_rate_limit:
      capacity: 1000
      interval: 1s

  # Router-level settings
  router:
    timeout: 60s

  # Per-subgraph settings
  subgraphs:
    slow-service:
      timeout: 120s
```

## Authentication (JWT)

```yaml
authentication:
  router:
    jwt:
      jwks:
        - url: https://auth.example.com/.well-known/jwks.json
          issuer: https://auth.example.com/

authorization:
  require_authentication: false  # true = require JWT for all requests
```

## Response Caching

```yaml
# In-memory response caching
supergraph:
  cache:
    in_memory:
      limit: 100MB

# Redis-backed caching
supergraph:
  cache:
    redis:
      urls:
        - redis://localhost:6379
      ttl: 300s
```

## Persisted Queries (APQ)

```yaml
apq:
  enabled: true
  router:
    cache:
      in_memory:
        limit: 512
      # Or Redis
      # redis:
      #   urls:
      #     - redis://localhost:6379
```

## Limits and Security

```yaml
limits:
  # Maximum request body size
  http_max_request_bytes: 2000000  # 2MB

  # Query complexity limits
  max_depth: 15
  max_height: 200
  max_aliases: 30
  max_root_fields: 20
```

## Include Subgraph Errors

```yaml
# Control which subgraph errors are exposed to clients
include_subgraph_errors:
  all: true  # Include all subgraph errors (development)

  # Or selectively
  # all: false
  # subgraphs:
  #   products: true  # Only expose products errors
```

## Subscriptions

```yaml
subscription:
  enabled: true
  mode:
    # WebSocket-based subscriptions
    passthrough:
      all:
        path: /ws

    # Or callback-based
    # callback:
    #   public_url: https://router.example.com/callback
```

## Development vs Production

### Development Configuration

```yaml
# router.dev.yaml
supergraph:
  introspection: true

sandbox:
  enabled: true

include_subgraph_errors:
  all: true

telemetry:
  exporters:
    logging:
      stdout:
        enabled: true
        format: text
```

### Production Configuration

```yaml
# router.prod.yaml
supergraph:
  listen: 0.0.0.0:4000
  introspection: false

sandbox:
  enabled: false

include_subgraph_errors:
  all: false

cors:
  origins:
    - https://app.example.com

telemetry:
  exporters:
    tracing:
      otlp:
        enabled: true
        endpoint: http://collector:4317
```

## Environment Variable Expansion

Use environment variables in configuration:

```yaml
supergraph:
  listen: ${ROUTER_LISTEN_ADDRESS:-127.0.0.1:4000}

override_subgraph_url:
  products: ${PRODUCTS_URL}

authentication:
  router:
    jwt:
      jwks:
        - url: ${JWKS_URL}
```

## Configuration Validation

Validate configuration without starting the Router:

```bash
router config validate --config router.yaml
```
