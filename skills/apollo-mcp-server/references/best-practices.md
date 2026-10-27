# Best Practices and Security

## Use contract variants to control AI access

GraphOS [contract variants](https://www.apollographql.com/docs/graphos/platform/schema-management/delivery/contracts/overview) deliver different subsets of a graph to different consumers. Use them to expose only the types and fields AI agents need.

Contract variants are strongly recommended when using:

- GraphOS-managed persisted queries (`operations.source: uplink`)
- Introspection tools (`introspect`, `search`)

```yaml
graphos:
  apollo_key: ${env.APOLLO_KEY}
  apollo_graph_ref: my-graph@ai-contract
schema:
  source: uplink
```

## Gate mutations

Keep `mutation_mode` at its default (`none`) unless the use case requires GraphQL mutations.

| Mode | Predefined mutations | Ad hoc mutations (`execute`) |
|------|---------------------|------------------------------|
| `none` | Skipped | Rejected |
| `explicit` | Exposed | Rejected |
| `all` | Exposed | Allowed |

> **Security: mutation exposure.** These modes are configuration gates, not per-invocation approval. `explicit` does not mean the operation was reviewed or committed to version control. Hot-reloaded source changes can add or change mutations without an approval step.

- ALWAYS apply review and promotion controls to every configured operation source
- ALWAYS keep query fields read-only at the upstream API (the server cannot detect writes behind a query)
- PREFER `explicit` over `all` when you need predefined mutations but not ad-hoc ones
- NEVER use `mutation_mode: all` unless `execute` must accept ad-hoc mutations

## Limit intent-flow subversion

[OWASP MCP06](https://owasp.org/www-project-mcp-top-10/) describes how instructions from retrieved context can steer an agent away from the user's goal. Apollo MCP Server limits predefined calls to operations in its tool catalog but does not determine whether a proposed call aligns with the user's intent.

Treat the exposed tool surface as impact limitation, not intent validation:

1. Expose only the operations required for the use case. Review both what each operation does and how broadly its variables can target data.
2. Keep `execute` disabled unless the agent needs ad-hoc queries.
3. Protect every configured operation source. Hot-reloaded changes can add or replace operations without restarting the server.
4. Enforce authentication, authorization, and demand controls at the GraphQL API. Implement intent checks and per-action approval in the MCP client or agent framework.

## Protect tool definitions from poisoning

MCP clients expose tool names, descriptions, and input property descriptions to AI models. Models use all of this text when selecting tools and arguments. Treat every operation and schema source as security-sensitive. See [OWASP MCP03](https://owasp.org/www-project-mcp-top-10/).

Apollo MCP Server does not automatically scan tool metadata for hidden instructions or compare the live tool list with an approved snapshot. Establish these controls:

- Restrict write access to operation, schema, manifest, collection, and configuration sources. Require review for changes promoted to production.
- Capture the live `tools/list` response after deployment. Store an approved snapshot using a consistent MCP protocol version and server configuration.
- Review tool names, descriptions, and input descriptions for unexpected model-directed instructions, external destinations, hidden Unicode characters, and misleading semantics.
- Compare the live response with the approved snapshot whenever operations, schemas, or description overrides are added, removed, renamed, or hot-reloaded.

`overrides.descriptions` controls only the top-level description of an exact operation-name match. It does not pin the operation name, input property names or descriptions, or executable document.

## Plan audit and telemetry

Before production deployment:

- Configure OTLP trace and metric exporters and route application logs to managed destinations.
- Review captured span attributes and omit payload fields that the investigation process does not require:

```yaml
telemetry:
  exporters:
    tracing:
      omitted_attributes:
        - tool_arguments
        - tool_result
        - graphql_query
        - graphql_response
```

- Apply access controls, retention, and data-handling policies in the collector and storage backend.
- Alert on tool failures (`success=false` in `apollo.mcp.tool.count`), unexpected usage patterns, and telemetry ingestion gaps.

Metrics do not include per-request trace IDs. Use metrics for aggregate monitoring and traces plus correlated logs for request-level investigation.

## Review per-operation scopes when tools change

Use global OAuth scopes as a server-wide baseline and `overrides.required_scopes` for tools that need additional permissions. Per-operation keys are matched exactly against MCP tool names.

- ALWAYS compare `required_scopes` keys with the live `tools/list` response after deployment
- ALWAYS repeat this review whenever operations are added, removed, renamed, or hot-reloaded
- ALWAYS list the `execute` tool in `required_scopes` if you enable it (otherwise an ad-hoc query can reach data a scoped operation protects)

A new or mismatched tool name remains governed only by the global scope requirement. The server does not reject or warn about unknown `required_scopes` keys.

## Understand the execution boundary

Apollo MCP Server parses predefined and ad-hoc operation documents but does not automatically validate them against the configured schema before forwarding. The upstream GraphQL endpoint performs validation during execution.

- The `validate` tool validates an ad-hoc operation against the schema, but enabling it does not force a client to call it before `execute`.
- The base request path sends GraphQL as a structured JSON HTTP request. It does not construct shell commands or spawn child processes from MCP tool input.
- Rhai scripts run before outgoing GraphQL requests and can change the endpoint, headers, and make outbound HTTP requests. Treat the script directory as trusted code.

## Security: OAuth token passthrough

> **Security: confused deputy risk.** Apollo MCP Server passes validated OAuth tokens to upstream GraphQL APIs by default. This can lead to audience confusion and confused deputy vulnerabilities.

Disable automatic passthrough when your GraphQL API does not require the caller's token:

```yaml
transport:
  type: streamable_http
  auth:
    disable_auth_token_passthrough: true
```

When passthrough is disabled, Apollo MCP Server still validates tokens for MCP client authentication but does not forward them downstream.

- ALWAYS audit `disable_auth_token_passthrough` and `forward_headers` together
- If `forward_headers` contains `authorization`, the server still copies the incoming header even when passthrough is disabled
- When passthrough is enabled, the validated token replaces a forwarded `authorization` header
- ALWAYS verify that upstream APIs validate token audiences (`aud` claim)
- ALWAYS redact authorization headers from upstream logs and traces

## Send client name header for persisted queries

If you register a persisted query with a specific client name (not `null`), configure the server to send the client name header to the router:

```yaml
headers:
  "apollographql-client-name": "my-mcp-server"
operations:
  source: uplink
```

The default header expected by the router is `apollographql-client-name`. To use a different header name, configure `telemetry.apollo.client_name_header` in router YAML configuration.

## Key Rules

- ALWAYS configure authentication before exposing the server to AI agents
- ALWAYS use contract variants when using persisted queries or introspection with GraphOS
- ALWAYS review `required_scopes` keys after any tool change
- NEVER expose `execute` with `mutation_mode: all` unless strictly required
- NEVER assume `mutation_mode` provides per-invocation approval
- PREFER predefined operation files over ad-hoc `execute` for predictable behavior
- PREFER `explicit` mutation mode over `all` in shared environments
