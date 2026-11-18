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
| `parent_based_sampler` | `bool` | `true` | Follow the sampling decision of an incoming trace context. When `false`, `sampler` applies to every request regardless of incoming context |
| `gen_ai_content` | `bool` | `false` | Export `gen_ai.tool.call.arguments`, `gen_ai.tool.call.result`, and `gen_ai.prompt.variable.<name>` span attributes |
| `client_address` | `bool` | `false` | Record the client's IP address and port on spans. Behind a proxy, list it under `transport.trusted_proxies` |
| `omitted_attributes` | `List<String>` | | Span attributes to omit before export |

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
      parent_based_sampler: false
```

## Semantic Conventions

The server follows two sets of OpenTelemetry semantic conventions:

| Conventions | Used for |
|-------------|----------|
| OpenTelemetry semantic conventions (v1.42.0) | Resource attributes, HTTP server spans/metrics, `network.*` and `error.type` attributes |
| OpenTelemetry GenAI semantic conventions | MCP handler spans, `mcp.server.operation.duration` metric, `mcp.*`, `gen_ai.*`, and `jsonrpc.*` attributes |

The `apollo.*` metrics and attributes are Apollo's own and don't follow the semantic conventions. Where a convention covers the same data, the server emits both names. Use the `apollo.*` names for dashboards and alerts that must keep working across upgrades.

## Emitted Metrics

### Apollo Metrics

The `apollo.mcp.*` duration metrics are in milliseconds.

| Metric | Type | Description | Attributes |
|--------|------|-------------|------------|
| `apollo.mcp.initialize.count` | Counter | Each `initialize` request | `client_name`, `client_version` |
| `apollo.mcp.list_tools.count` | Counter | Each `list_tools` request | |
| `apollo.mcp.get_info.count` | Counter | Each `get_info` request | |
| `apollo.mcp.tool.count` | Counter | Each tool call | `tool_name`, `success` |
| `apollo.mcp.tool.duration` | Histogram | Tool execution duration (ms) | `tool_name`, `success` |
| `apollo.mcp.operation.count` | Counter | Each downstream GraphQL operation | `operation.id`, `operation.type`, `success` |
| `apollo.mcp.operation.duration` | Histogram | GraphQL operation round-trip (ms) | `operation.id`, `operation.type`, `success` |
| `apollo.mcp.auth.rate_limit.count` | Counter | Requests the auth rate limiter rejects before token validation | (none) |
| `apollo.mcp.auth.rate_limit.overflow.count` | Counter | Requests the rate limiter allows untracked because its key table is full | (none) |

The `auth.rate_limit` metrics are emitted only when OAuth authentication is configured and `rate_limit.enabled` is `true`.

### MCP Semantic Convention Metric

The server emits `mcp.server.operation.duration`, a histogram in seconds with one measurement per MCP request (except `ping`, `server/discover`, and `completion/complete`).

| Attribute | Description |
|-----------|-------------|
| `mcp.method.name` | The MCP method, such as `tools/call` |
| `mcp.protocol.version` | The MCP protocol version of the request |
| `network.transport` | `tcp` for Streamable HTTP, or `pipe` for stdio |
| `network.protocol.name` | `http`, for Streamable HTTP only |
| `network.protocol.version` | The HTTP version, for Streamable HTTP only |
| `gen_ai.operation.name` | `execute_tool`, for `tools/call` only |
| `gen_ai.tool.name` | The tool name, for `tools/call` only |
| `gen_ai.prompt.name` | The prompt name, for `prompts/get` only |
| `rpc.response.status_code` | The JSON-RPC error code, when the request returns an error |
| `error.type` | The JSON-RPC error code for a server error, or `tool_error` when a tool result has `isError: true` |

### HTTP Server Metrics

Standard HTTP server metrics: `http.server.request.duration` (histogram, seconds), `http.server.active_requests` (gauge), `http.server.request.body.size` (histogram, bytes), and `http.server.response.body.size` (histogram, bytes).

## Emitted Traces

Spans are generated for:

- **HTTP requests** to the MCP endpoint (not health checks)
- **MCP handler methods** (tools, resources, prompts, initialization, tasks)
- **Tool execution** with nested spans per tool
- **Downstream GraphQL calls** with `traceparent`, `tracestate`, and `baggage` propagation

### MCP Handler Spans

Each MCP request handler creates a `SERVER` span named after the MCP method:

| Request | Span Name | Example |
|---------|-----------|---------|
| `tools/call` | `tools/call {tool name}` | `tools/call GetUser` |
| `prompts/get` | `prompts/get {prompt name}` | `prompts/get check_orders` |
| `tools/list` | `tools/list` | |
| `resources/read` | `resources/read` | |
| Other methods | The method name | `initialize` |

The span name uses the method alone until the request finishes, and stays that way when a caller error occurs (such as an unknown tool), so names a client makes up don't become span names.

Handler span attributes:

| Attribute | Description |
|-----------|-------------|
| `mcp.method.name` | The MCP method, such as `tools/call` or `resources/read` |
| `jsonrpc.request.id` | The JSON-RPC request ID |
| `mcp.protocol.version` | The MCP protocol version of the request |
| `mcp.session.id` | The MCP session ID, for a request on a session |
| `network.transport` | `tcp` for Streamable HTTP, or `pipe` for stdio |
| `network.protocol.name` | `http`, for Streamable HTTP only |
| `network.protocol.version` | The HTTP version, for Streamable HTTP only |
| `rpc.response.status_code` | The JSON-RPC error code, when the request returns an error |
| `error.type` | The error code for a server error, or `tool_error` for `isError: true` |

### `tools/call` Span Attributes

| Attribute | Description |
|-----------|-------------|
| `apollo.mcp.tool_name` | The name of the tool that was called |
| `apollo.mcp.request_id` | The MCP request ID |
| `apollo.mcp.tool_arguments` | The tool call input arguments as a JSON string |
| `apollo.mcp.tool_result` | The tool call output result as a JSON string |
| `gen_ai.operation.name` | Always `execute_tool` |
| `gen_ai.tool.name` | Same value as `apollo.mcp.tool_name` |
| `gen_ai.tool.call.arguments` | Same as `apollo.mcp.tool_arguments` (opt-in via `gen_ai_content`) |
| `gen_ai.tool.call.result` | Same as `apollo.mcp.tool_result`, successful calls only (opt-in via `gen_ai_content`) |

### `prompts/get` Span Attributes

| Attribute | Description |
|-----------|-------------|
| `gen_ai.prompt.name` | The prompt name |
| `gen_ai.prompt.variable.<name>` | Each prompt argument value (opt-in via `gen_ai_content`) |

### HTTP Server Span

The span wrapping each request to the MCP endpoint is a `SERVER` span named `{method} {route}` (e.g., `POST /mcp`). Key attributes: `http.request.method`, `url.path`, `http.response.status_code` (integer), `apollo.mcp.session_id`, `server.address`, `server.port`. With `client_address` enabled, also includes `client.address`, `network.peer.address`, and `network.peer.port`.

### GraphQL Execute Span

| Attribute | Description |
|-----------|-------------|
| `apollo.mcp.graphql_query` | The GraphQL query sent |
| `apollo.mcp.graphql_response` | The GraphQL response received |

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

Omitting `tool_name`, `tool_arguments`, or `tool_result` also removes the matching `gen_ai.*` attribute.

Prompt arguments are exported only as `gen_ai.prompt.variable.<name>` when `gen_ai_content` is enabled. They have no `apollo.mcp.*` counterpart. To keep them out of traces, leave `gen_ai_content` disabled.

## Log Correlation

Log lines emitted inside an active span carry the span's IDs for trace-to-log correlation. The format depends on `logging.format`:

- `text` (default): lines start with `trace_id=<32 hex> span_id=<16 hex>`
- `json`: `trace_id` and `span_id` are top-level string keys alongside `span` (the span's name)

## Trace Context Propagation

MCP requests can carry W3C `traceparent`, `tracestate`, and `baggage` in `params._meta` over stdio or streamable HTTP. A valid `_meta.traceparent` becomes the parent of the MCP handler span. Trace context propagates automatically to downstream GraphQL requests.

## Client Addresses

Client address recording is opt-in via `client_address: true` in the tracing config. Behind a reverse proxy, list proxies under `transport.trusted_proxies` to record the original client from `X-Forwarded-For`.

```yaml
transport:
  type: streamable_http
  trusted_proxies:
    - 10.0.4.0/24
telemetry:
  exporters:
    tracing:
      client_address: true
```

## Dashboard Templates

Apollo provides pre-built dashboard templates at [apollographql/apm-templates](https://github.com/apollographql/apm-templates):

| Platform | Location |
|----------|----------|
| Grafana | `grafana/` |
| Datadog | `datadog/` |
