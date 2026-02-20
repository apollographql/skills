# Response Caching (Router v2.6.0+)

Entity-level and root-field caching for subgraph responses, backed by Redis. Requires Router v2.6.0 or later.

## Overview

Response caching enables the router to cache origin responses and reuse them across queries:

- **Entity representations**: Cached independently per origin — each origin's contribution to an entity is cached separately and reusable across different queries
- **Root query fields**: Cached as complete units (the entire response for that root field)

### Scope

- **PUBLIC** (default): Data is identical for all users and shared in the cache
- **PRIVATE**: Data is user-specific; requires `private_id` configuration to cache per-user

### Mixed TTLs

When an origin response contains multiple entity representations, the router uses the minimum TTL across all representations. Client responses never claim to be fresher than their least-fresh component.

## Setup

### Minimal configuration

```yaml
response_cache:
  enabled: true
  subgraph:
    all:
      enabled: true
      ttl: 5m  # Required: fallback TTL when responses lack Cache-Control headers
      redis:
        urls: ["${env.CACHE_REDIS_URL:-redis://localhost:6379}"]
```

### Full annotated example

```yaml
response_cache:
  enabled: true
  debug: false  # Set true only in dev — exposes cache data to Apollo Sandbox
  invalidation:
    listen: 127.0.0.1:4000  # Bind to loopback — never expose publicly in production
    path: /invalidation
  subgraph:
    all:
      enabled: true
      ttl: ${env.CACHE_DEFAULT_TTL:-5m}
      redis:
        urls: ["${env.CACHE_REDIS_URL:-redis://localhost:6379}"]
        fetch_timeout: 250ms   # Default: 150ms
        insert_timeout: 750ms  # Default: 500ms
        invalidate_timeout: 750ms  # Default: 1s
        pool_size: 5           # Default: 5; increase for high traffic
        namespace: response_cache  # Prefix for all Redis keys
        required_to_start: false   # Set true to block startup if Redis is down
      invalidation:
        enabled: true
        shared_key: ${env.INVALIDATION_SHARED_KEY}
    subgraphs:
      inventory:
        enabled: false  # Disable caching for a specific subgraph
      products:
        ttl: 10m  # Override TTL per subgraph
        redis:
          urls: ["${env.PRODUCTS_REDIS_URL:-redis://products-cache:6379}"]
```

### Redis URL formats

| Scheme | Description |
|--------|-------------|
| `redis://` | TCP to a single server |
| `rediss://` | TLS to a single server |
| `redis-cluster://` | TCP to a cluster |
| `rediss-cluster://` | TLS to a cluster |

Format: `redis[s][-cluster]://[[username:]password@]host[:port][/database]`

Clustered URLs can include `?node=host1:port1&node=host2:port2` query parameters or be provided as a YAML array of URLs.

## Schema Directives

### @cacheControl(maxAge, scope, inheritMaxAge)

Controls the `Cache-Control` header the subgraph returns. The router reads that header to determine TTLs — the directive itself does not directly affect what the router caches.

First, add the directive definition to your subgraph schema:

```graphql
enum CacheControlScope {
  PUBLIC
  PRIVATE
}

directive @cacheControl(
  maxAge: Int
  scope: CacheControlScope
  inheritMaxAge: Boolean
) on FIELD_DEFINITION | OBJECT | INTERFACE | UNION
```

Apollo Server recognizes this directive automatically. For other servers, consult your server's documentation for `Cache-Control` header support.

**Type-level** — sets a default TTL for all fields returning this type:

```graphql
type Product @key(fields: "id") @cacheControl(maxAge: 240) {
  id: ID!
  name: String!
  price: Int
}
```

**Field-level** — overrides type-level settings:

```graphql
type Product @key(fields: "id") @cacheControl(maxAge: 240) {
  id: ID!
  name: String!
  price: Int @cacheControl(maxAge: 60)  # Shorter TTL for volatile data
  viewerHasBookmarked: Boolean! @cacheControl(maxAge: 30, scope: PRIVATE)
}
```

When a query requests fields with different TTLs, the origin returns `Cache-Control` with the minimum `max-age`.

### @cacheTag(format)

Tags cached data for active invalidation. Introduced in Federation v2.12. Import it via:

```graphql
extend schema
  @link(
    url: "https://specs.apollo.dev/federation/v2.12"
    import: ["@key", "@cacheTag"]
  )
```

**On entities** — use `{$key.<field>}` for dynamic tags based on entity keys:

```graphql
type User @key(fields: "id")
  @cacheControl(maxAge: 60)
  @cacheTag(format: "user-{$key.id}")
  @cacheTag(format: "user") {
  id: ID!
  name: String!
}
```

**On root query fields** — use `{$args.<field>}` for dynamic tags based on arguments:

```graphql
type Query {
  postsByUser(userId: ID!): [Post!]!
    @cacheControl(maxAge: 120)
    @cacheTag(format: "posts-user-{$args.userId}")
}
```

**Rules:**
- Only applies to root query fields or resolvable entities (types with `@key` where `resolvable` is unset or `true`)
- For entities with multiple `@key` directives, you can only use fields present in **every** `@key`
- The `format` must always generate a valid string (not an object)

## Invalidation

### Passive (TTL-based)

Data automatically expires based on:
1. `@cacheControl(maxAge: N)` directives in the subgraph schema (translated to `Cache-Control` headers)
2. `Cache-Control` headers returned by the origin
3. The configured `ttl` fallback (used when no `Cache-Control` header or `max-age` is present)

The router uses the minimum TTL across all components in a response.

### Active (tag-based)

Explicitly remove cached data before TTL expires. Requires the invalidation endpoint and `@cacheTag` directives.

**Configuration:**

```yaml
response_cache:
  enabled: true
  invalidation:
    listen: 127.0.0.1:4000  # Internal only — never bind to 0.0.0.0 in production
    path: /invalidation
  subgraph:
    all:
      enabled: true
      redis:
        urls: ["${env.CACHE_REDIS_URL:-redis://localhost:6379}"]
      invalidation:
        enabled: true
        shared_key: ${env.INVALIDATION_SHARED_KEY}
```

**Invalidation request formats:**

By subgraph (all cached data for the subgraph):
```json
[{"kind": "subgraph", "subgraph": "accounts"}]
```

By entity type:
```json
[{"kind": "type", "subgraph": "accounts", "type": "User"}]
```

By cache tag:
```json
[{"kind": "cache_tag", "subgraphs": ["accounts"], "cache_tag": "user-42"}]
```

**curl example:**

```bash
curl --request POST \
  --header "authorization: $INVALIDATION_SHARED_KEY" \
  --header "content-type: application/json" \
  --url http://localhost:4000/invalidation \
  --data '[{"kind": "cache_tag", "subgraphs": ["posts"], "cache_tag": "user-42"}]'
```

Response: `{"count": 1}` — the number of invalidated Redis keys.

### Programmatic cache tags from subgraph responses

If tags depend on runtime data (not entity keys or field args), set them in the response `extensions`:

- **Entities**: Use `apolloEntityCacheTags` — an array of arrays, positionally matching the `_entities` array:
  ```json
  {
    "data": {"_entities": [
      {"__typename": "User", "id": 42, "name": "Alice"},
      {"__typename": "User", "id": 7, "name": "Bob"}
    ]},
    "extensions": {"apolloEntityCacheTags": [
      ["users", "user-42"],
      ["users", "user-7"]
    ]}
  }
  ```

- **Root fields**: Use `apolloCacheTags` — a flat array of tags for the entire response:
  ```json
  {
    "data": {"homepage": {"featuredProducts": [...]}},
    "extensions": {"apolloCacheTags": ["homepage", "featured"]}
  }
  ```

## Customization

### Private data caching

Cache user-specific data by configuring `private_id` — a context key containing the user identifier:

```yaml
response_cache:
  enabled: true
  subgraph:
    all:
      enabled: true
      redis:
        urls: ["${env.CACHE_REDIS_URL:-redis://localhost:6379}"]
    subgraphs:
      accounts:
        private_id: "user_id"
```

Extract the user ID from JWT claims via a Rhai script:

```rhai
// main.rhai
fn supergraph_service(service) {
  let request_callback = |request| {
    let claims = request.context[Router.APOLLO_AUTHENTICATION_JWT_CLAIMS];
    if claims != () {
      request.context["user_id"] = claims["sub"];
    }
  };
  service.map_request(request_callback);
}
```

### Custom cache keys

Vary cache entries by request headers using the `apollo::response_cache::key` context entry.

**Multi-tenant example** (x-tenant-id header):

```rhai
fn supergraph_service(service) {
  let request_callback = |request| {
    let tenant_id = request.headers["x-tenant-id"];
    if tenant_id != () {
      request.context[Router.APOLLO_RESPONSE_CACHE_KEY]["all"] = tenant_id;
    }
  };
  service.map_request(request_callback);
}
```

**Locale example** (accept-language header):

```rhai
fn supergraph_service(service) {
  let request_callback = |request| {
    let locale = request.headers["accept-language"];
    if locale != () {
      request.context[Router.APOLLO_RESPONSE_CACHE_KEY]["all"] = locale;
    }
  };
  service.map_request(request_callback);
}
```

### Per-subgraph Redis instances

Override the global Redis for specific subgraphs:

```yaml
response_cache:
  enabled: true
  subgraph:
    all:
      enabled: true
      redis:
        urls: ["${env.CACHE_REDIS_URL:-redis://localhost:6379}"]
    subgraphs:
      products:
        redis:
          urls: ["${env.PRODUCTS_REDIS_URL:-redis://products-cache:6379}"]
          pool_size: 15
          namespace: products_response_cache
```

### Redis tuning reference

| Option | Default | Description |
|--------|---------|-------------|
| `fetch_timeout` | 150ms | Timeout for cache reads |
| `insert_timeout` | 500ms | Timeout for cache writes |
| `invalidate_timeout` | 1s | Timeout for invalidation operations |
| `pool_size` | 5 | Number of Redis connections |
| `namespace` | (none) | Prefix for all Redis keys |
| `required_to_start` | false | Block router startup if Redis is unreachable |

### TLS and authentication

```yaml
response_cache:
  enabled: true
  subgraph:
    all:
      enabled: true
      redis:
        urls: ["rediss://${env.REDIS_HOST}:6379"]
        username: ${env.REDIS_USERNAME}
        password: ${env.REDIS_PASSWORD}
        tls:
          certificate_authorities: ${file./path/to/ca.crt}
          client_authentication:
            certificate_chain: ${file./path/to/certificate_chain.pem}
            key: ${file./path/to/key.pem}
```

## Observability

### Metrics

#### Fetch / insert

| Metric | Description | Unit |
|--------|-------------|------|
| `apollo.router.operations.response_cache.fetch` | Time to fetch from cache | s |
| `apollo.router.operations.response_cache.fetch.error` | Errors fetching from cache | {error} |
| `apollo.router.operations.response_cache.fetch.entity` | Entities per fetch node | {entity} |
| `apollo.router.operations.response_cache.insert` | Time to insert into cache | s |
| `apollo.router.operations.response_cache.insert.error` | Errors inserting into cache | {error} |

#### Invalidation

| Metric | Description | Unit |
|--------|-------------|------|
| `apollo.router.operations.response_cache.invalidation.event` | Batch invalidation requests received | {request} |
| `apollo.router.operations.response_cache.invalidation.error` | Invalidation errors | {error} |
| `apollo.router.operations.response_cache.invalidation.entry` | Entries invalidated | {entry} |
| `apollo.router.operations.response_cache.invalidation.request.entry` | Entries per invalidation request | {entry} |
| `apollo.router.operations.response_cache.invalidation.duration` | Invalidation execution time | s |

#### Internal / Redis

| Metric | Description |
|--------|-------------|
| `apollo.router.response_cache.reconnection` | Reconnections to cache storage |
| `apollo.router.response_cache.private_queries.lru.size` | LRU cache size for private queries |
| `apollo.router.cache.redis.clients` | Active Redis clients |
| `apollo.router.cache.redis.command_queue_length` | Commands waiting to send |
| `apollo.router.cache.redis.commands_executed` | Total Redis commands executed |
| `apollo.router.cache.redis.redelivery_count` | Commands retried (connection issues) |
| `apollo.router.cache.redis.errors` | Redis errors by type |

Experimental (may change): `experimental.apollo.router.cache.redis.network_latency_avg`, `latency_avg`, `request_size_avg`, `response_size_avg`.

### Telemetry configuration

```yaml
telemetry:
  instrumentation:
    instruments:
      cache:
        apollo.router.response.cache:
          attributes:
            graphql.type.name: true
            subgraph.name:
              subgraph_name: true
            supergraph.operation.name:
              supergraph_operation_name: string
```

### Trace spans

**`response_cache.lookup`** attributes:
- `kind`: `root` or `entity`
- `subgraph.name`: The subgraph name
- `graphql.type`: The type (or parent type for root fields)
- `cache.status`: `hit`, `partial_hit`, or `miss`
- `debug`, `private`, `contains_private_id`: Booleans
- `cache.key`: The primary cache key

**`response_cache.store`** attributes:
- `kind`: `root` or `entity`
- `subgraph.name`: The subgraph name
- `ttl`: Cache entry TTL
- `batch.size`: Entity batch size

### Log selectors (subgraph service)

| Selector | Values | Description |
|----------|--------|-------------|
| `response_cache` | `hit` or `miss` | Number of cache hits/misses for a subgraph request |
| `response_cache_status` | `hit`, `partial_hit`, `miss`, `status` | Cache status for the subgraph request |
| `response_cache_control` | `max_age`, `scope`, `no_store` | Data from the computed `Cache-Control` header |

Example — log uncached subgraph responses:

```yaml
telemetry:
  instrumentation:
    events:
      subgraph:
        response:
          level: info
          condition:
            all:
              - eq:
                  - subgraph_name: true
                  - static: posts
              - eq:
                  - response_cache: hit
                  - 0
```

### Cache debugger

Enable during **development only** with `response_cache.debug: true` and `sandbox.enabled: true`. Open Apollo Sandbox at the router URL to inspect:

- Cache status per entry (hit/miss, created-at, source subgraph)
- `Cache-Control` headers returned by subgraphs
- Entity keys and cache tags
- One-click `curl` commands for invalidation

**Never enable `debug: true` in production** — it exposes internal cache data.
