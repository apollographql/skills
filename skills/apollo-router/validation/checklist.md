# Post-Generation Validation Checklist

Run through this checklist after generating a `router.yaml` to catch common mistakes.

## Security

- [ ] **Introspection disabled** (production): `supergraph.introspection: false`
- [ ] **Sandbox disabled** (production): `sandbox.enabled: false`
- [ ] **Homepage disabled** (production): `homepage.enabled: false`
- [ ] **Subgraph errors hidden** (production): `include_subgraph_errors.all: false`
- [ ] **No wildcard CORS** (production): explicit origins only (no `"*"` and no `allow_any_origin: true`)
- [ ] **Authentication required** (if applicable): `authorization.require_authentication: true`

## Version Correctness

- [ ] **CORS schema matches version**:
  - v1: flat `cors.origins: [...]`
  - v2: `cors.policies: [{ origins: [...] }]`
- [ ] **JWT issuer field matches version**:
  - v1: `issuer: <string>` (singular)
  - v2: `issuers: [<string>]` (plural array)
- [ ] **Max age format matches version**:
  - v1: duration string (`max_age: 24h`)
  - v2: duration string (`max_age: 24h`)
- [ ] **Limits key is correct**: Use `limits` (v1.17+ and v2), not `preview_operation_limits`
- [ ] **Connectors key is correct** (if applicable): early v2 preview = `preview_connectors`, current v2 GA = `connectors`

## Operational

- [ ] **Health check enabled**: `health_check.enabled: true` with a listen address
- [ ] **Rate limiting on `router:`**: `traffic_shaping.router.global_rate_limit` limits client requests; `all:` limits subgraph requests
- [ ] **All env vars documented**: Every `${env.VAR}` in the config has a corresponding entry in deployment docs
- [ ] **APOLLO_KEY not hardcoded**: API key is via environment variable, never in config file or logs
- [ ] **Secrets use env var expansion**: `${env.JWKS_URL}`, `${env.JWT_ISSUER}`, etc.

## Telemetry

- [ ] **Logging format is JSON** (production): `telemetry.exporters.logging.stdout.format: json`
- [ ] **Tracing sampler is set**: `sampler: 0.1` (10%) is a reasonable default; tune for your traffic volume
- [ ] **Service name is set**: `common.service_name` identifies this router instance

## Recommended Final Step

```bash
# Validate config syntax against the Router's schema
router config validate router.yaml
```

If migrating from v1 to v2, use the built-in upgrade tool:
```bash
router config upgrade router.yaml
```
