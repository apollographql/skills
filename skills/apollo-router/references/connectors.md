# Router Connectors Configuration (v2)

Apollo Connectors are configured in Router v2 under the `connectors` key.

## Core Rules

- Use `connectors` (GA), not `preview_connectors` (early v2 preview).
- Source keys use `<subgraph>.<source>` naming.
- `<source>` must match the `@source(name: "...")` used in your connector schema.

## Minimal Router v2 Example

```yaml
connectors:
  sources:
    my_subgraph.my_api:
      $config:
        api_version: "v2"
        feature_flag: true
```

Use `${env.VAR}` for sensitive values instead of hardcoding secrets in `$config`.

## Migration Note

If you have early v2 preview config:

- Rename `preview_connectors` -> `connectors`
- Move source mapping from `subgraphs.<name>.sources.<source>` to `sources.<subgraph>.<source>`

## Parameter Checklist

- Subgraph name (for example: `products`)
- Source name (for example: `inventory`)
- `$config` keys used by your schema (for example: `api_version`)

## Validate

```bash
router config validate router.yaml
```

## Response Caching for Connectors

Cache connector HTTP responses to reduce calls to REST APIs. Requires the `response_cache.connector` configuration block (v2.6.0+).

```yaml
response_cache:
  enabled: true
  connector:
    all:
      enabled: true
      ttl: 5m
      redis:
        urls: ["${env.CACHE_REDIS_URL:-redis://localhost:6379}"]
      cache_key_headers:
        - "x-api-version"    # Vary cache entries by these request headers
    sources:
      products.rest_api:
        ttl: 10m
        cache_key_headers:
          - "accept-language"
```

The `cache_key_headers` list specifies which request headers become part of the cache key. Responses with different values for these headers are cached separately.
