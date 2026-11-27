# OpenTelemetry Integration

## Overview

Apollo MCP Server exports metrics and traces using the OpenTelemetry Protocol (OTLP). Telemetry is disabled by default and must be configured to enable export.

| Signal | Default | Destination |
|--------|---------|-------------|
| Logs | Enabled at `info` | stderr (stdio) or stdout (streamable_http), or configured log files |
| Traces | Export disabled | Configured OTLP tracing endpoint |
| Metrics | Export disabled | Configured OTLP metrics endpoint |

## Configuration

### Quick Start

```yaml
telemetry:
  exporters:
    metrics:
      otlp:
        endpoint: "http://localhost:4318/v1/metrics"
        protocol: "http/protobuf"
    tracing:
      otlp:
        endpoint: "http://localhost:4318/v1/traces"
        protocol: "http/protobuf"
```

### Full Configuration Reference

#### Top-Level Telemetry

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `service_name` | `string` | `"apollo-mcp-server"` | Service name in telemetry data |
| `version` | `string` | Current crate version | Service version in telemetry data |
| `exporters` | `Exporters` | `null` | Exporter configuration |

#### Metrics Exporter

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `otlp.endpoint` | `URL` | `http://localhost:4317` | OTLP export endpoint |
| `otlp.protocol` | `string` | `grpc` | `grpc` or `http/protobuf` |
| `otlp.temporality` | `string` | `cumulative` | `cumulative`, `delta`, or `lowmemory` |
| `otlp.metadata` | key-value pairs | | gRPC metadata (only with `grpc` protocol) |
| `otlp.headers` | key-value pairs | | HTTP headers (only with `http/protobuf` protocol) |
| `export_interval` | `Duration` | `30s` | Interval for metric export |
| `omitted_attributes` | `List<String>` | | Metric attributes to omit before export |

#### Tracing Exporter

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `otlp.endpoint` | `URL` | `http://localhost:4317` | OTLP export endpoint |
| `otlp.protocol` | `string` | `grpc` | `grpc` or `http/protobuf` |
| `otlp.metadata` | key-value pairs | | gRPC metadata (only with `grpc` protocol) |
| `otlp.headers` | key-value pairs | | HTTP headers (only with `http/protobuf` protocol) |
| `sampler` | `string` | `always_on` | `always_on`, `always_off`, or `0.0`-`1.0` percentage |
| `parent_based_sampler` | `bool` | `true` | Follow the sampling decision of an incoming trace context. Set to `false` for public-facing servers |
| `client_address` | `bool` | `false` | Record client IP address and port on spans. Behind a reverse proxy, add the proxy's IP or CIDR to `transport.trusted_proxies` |
| `gen_ai_content` | `bool` | `false` | Export `gen_ai.tool.call.arguments`, `gen_ai.tool.call.result`, and `gen_ai.prompt.variable.<name>` span attributes |
| `omitted_attributes` | `List<String>` | | Span attributes to omit before export. Omitting an Apollo attribute also removes its `gen_ai.*` counterpart |

### Production Example

```yaml
telemetry:
  service_name: "mcp-server-prod"
  version: "1.0.0"
  exporters:
    metrics:
      otlp:
        endpoint: "https://your-metrics-endpoint"
        protocol: "http/protobuf"
      export_interval: 1m
    tracing:
      otlp:
        endpoint: "https://your-traces-endpoint"
        protocol: "http/protobuf"
      sampler: 0.1
```

## Emitted Metrics

| Metric | Type | Description | Attributes |
|--------|------|-------------|------------|
| `apollo.mcp.initialize.count` | Counter | Each `initialize` request | `client_name`, `client_version` |
| `apollo.mcp.list_tools.count` | Counter | Each `list_tools` request | |
| `apollo.mcp.get_info.count` | Counter | Each `get_info` request | |
| `apollo.mcp.tool.count` | Counter | Each tool call | `tool_name`, `success` |
| `apollo.mcp.tool.duration` | Histogram | Tool execution duration (ms) | `tool_name`, `success` |
| `apollo.mcp.operation.count` | Counter | Each downstream GraphQL operation | `operation.id`, `operation.type`, `success` |
| `apollo.mcp.operation.duration` | Histogram | GraphQL operation round-trip (ms) | `operation.id`, `operation.type`, `success` |
| `apollo.mcp.auth.rate_limit.count` | Counter | Each request the auth rate limiter rejects | (none) |
| `apollo.mcp.auth.rate_limit.overflow.count` | Counter | Rate limiter allows a request untracked (key table full) | (none) |

The two `auth.rate_limit` metrics are emitted only when OAuth auth is configured and `rate_limit.enabled` is `true`.

The server also emits `mcp.server.operation.duration`, the request duration histogram from the OpenTelemetry MCP semantic conventions. It records every MCP request except `ping`, `server/discover`, and `completion/complete`. Duration is in seconds with convention-advised bucket boundaries.

| Attribute | Description |
|-----------|-------------|
| `mcp.method.name` | The MCP method, such as `tools/call` |
| `mcp.protocol.version` | MCP protocol version of the request, when known |
| `network.transport` | `tcp` for Streamable HTTP, `pipe` for stdio |
| `gen_ai.operation.name` | `execute_tool`, for `tools/call` only |
| `gen_ai.tool.name` | The tool name, for `tools/call` only |
| `gen_ai.prompt.name` | The prompt name, for `prompts/get` only |
| `rpc.response.status_code` | JSON-RPC error code, when the request returns an error |
| `error.type` | JSON-RPC error code for server errors, or `tool_error` when `isError: true` |

Standard HTTP server metrics are also emitted: `http.server.request.duration` (histogram), `http.server.active_requests` (gauge), `http.server.request.body.size` (histogram), and `http.server.response.body.size` (histogram).

## Semantic Conventions

The server follows two sets of OpenTelemetry semantic conventions:

| Conventions | Version | Used for |
|-------------|---------|----------|
| OpenTelemetry semantic conventions | v1.42.0 | Resource attributes, HTTP server spans/metrics, `network.*` and `error.type` attributes |
| OpenTelemetry GenAI semantic conventions | Experimental (pinned to commit `6f98aef`) | MCP handler span names, `mcp.server.operation.duration` metric, `mcp.*`, `gen_ai.*`, and `jsonrpc.*` attributes |

The `apollo.*` metrics and attributes are Apollo's own and don't follow the semantic conventions. Where both cover the same data, the server emits both names (e.g., `apollo.mcp.tool_name` and `gen_ai.tool.name`). Use Apollo names for dashboards and alerts that must stay stable across upgrades.

## Emitted Traces

Spans are generated for:

- **HTTP requests** to the MCP endpoint (not health checks)
- **MCP handler methods** — each handler creates a `SERVER` span named after its MCP method (e.g., `tools/list`, `resources/read`). A `tools/call` span includes the tool name (e.g., `tools/call GetUser`). A `prompts/get` span includes the prompt name. These names follow the MCP semantic conventions. Text and JSON logs still show the internal span names, such as `call_tool`.
- **Tool execution** with nested spans per tool
- **Downstream GraphQL calls** with `traceparent`, `tracestate`, and `baggage` propagation

### Key Span Attributes

`tools/call` span:

| Attribute | Description |
|-----------|-------------|
| `apollo.mcp.tool_name` | Tool name |
| `apollo.mcp.request_id` | MCP request ID |
| `apollo.mcp.tool_arguments` | Tool input (JSON) |
| `apollo.mcp.tool_result` | Tool output (JSON) |
| `mcp.method.name` | Always `tools/call` |
| `mcp.protocol.version` | MCP protocol version of the request |
| `mcp.session.id` | MCP session ID, for a request on a session |
| `network.transport` | `tcp` for Streamable HTTP, `pipe` for stdio |
| `gen_ai.operation.name` | Always `execute_tool` |
| `gen_ai.tool.name` | Same value as `apollo.mcp.tool_name` |
| `gen_ai.tool.call.arguments` | Same as `apollo.mcp.tool_arguments` (opt-in via `gen_ai_content`) |
| `gen_ai.tool.call.result` | Same as `apollo.mcp.tool_result`, successful calls only (opt-in via `gen_ai_content`) |
| `jsonrpc.request.id` | Same value as `apollo.mcp.request_id` |
| `rpc.response.status_code` | JSON-RPC error code when call returns an error response |
| `error.type` | `tool_error` when `isError: true`, or JSON-RPC error code for server errors |

### HTTP server span

The span wrapping each request to the MCP endpoint is a `SERVER` span named `{method} {route}` (e.g., `POST /mcp`). Key attributes: `http.request.method`, `url.path`, `http.response.status_code` (integer), `apollo.mcp.session_id`, `server.address`, `server.port`.

GraphQL `execute` span:

| Attribute | Description |
|-----------|-------------|
| `apollo.mcp.graphql_query` | GraphQL query sent |
| `apollo.mcp.graphql_response` | GraphQL response received |

## Sensitive Data

Tool arguments, results, queries, and responses can contain sensitive data. Omit specific attributes:

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

Use short attribute names like `tool_name`, `operation_id`, `tool_arguments`, `graphql_response`. Omitting an Apollo attribute also removes its `gen_ai.*` counterpart, even when `gen_ai_content` is enabled.

The `gen_ai_content` option controls only the `gen_ai.*` copies of tool arguments and results. The same data is still exported as `apollo.mcp.tool_arguments` and `apollo.mcp.tool_result` unless you omit them with `omitted_attributes`. Prompt arguments (`gen_ai.prompt.variable.<name>`) are exported only when `gen_ai_content` is enabled and have no `apollo.mcp.*` counterpart.

## Trace Context Propagation

MCP requests can carry W3C `traceparent`, `tracestate`, and `baggage` in `params._meta` over stdio or streamable HTTP. A valid `_meta.traceparent` becomes the parent of the MCP handler span. Trace context propagates automatically to downstream GraphQL requests.

## Dashboard Templates

Apollo provides pre-built dashboard templates at [apollographql/apm-templates](https://github.com/apollographql/apm-templates):

| Platform | Location |
|----------|----------|
| Grafana | `grafana/` |
| Datadog | `datadog/` |
