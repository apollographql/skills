# Error handling

## Overview

Apollo MCP Server follows the MCP error model, which distinguishes between protocol errors and tool execution errors. Understanding this distinction is essential for building reliable MCP clients and monitoring the server in production.

## Protocol vs tool errors

### Protocol errors

Protocol errors indicate that the request itself is malformed or unsupported. Examples include calling an unknown tool or sending an invalid JSON-RPC payload. The server returns a JSON-RPC error response with a numeric `code` and a `message`:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32602,
    "message": "Unknown tool: NonExistentTool"
  }
}
```

The tool did not run. Surface these failures directly in the application.

### Tool execution errors

Tool execution errors indicate that the request was valid and the tool ran, but execution failed. The server returns a successful JSON-RPC response with `isError: true` in the `result`:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "isError": true,
    "content": [
      { "type": "text", "text": "..." }
    ]
  }
}
```

Pass tool failures back to the LLM for recovery rather than surfacing them as application errors.

## HTTP status codes

For `streamable_http` transport, the HTTP status code reflects the transport layer, not the outcome of a tool call.

| Status | Meaning |
|--------|---------|
| `2xx` | MCP request accepted. Inspect the JSON-RPC response body. |
| `401` | Authentication failure (missing, malformed, or expired token) |
| `403` | Token valid but lacks required scopes |
| `4xx` / `5xx` | Request rejected before reaching the tool handler |

A tool that fails returns HTTP `200 OK` with `isError: true` in the JSON-RPC result. Do not rely on HTTP status to determine tool success.

## GraphQL errors as tool errors

When the upstream GraphQL response includes a non-null `errors` field, Apollo MCP Server returns a tool execution error. This applies to both fully failed responses (`data: null` with `errors`) and partial successes (some `data` alongside `errors`). In both cases, `isError` is `true`.

### With structured content

When `overrides.enable_output_schema: true` is configured and the client supports structured content, the server returns the GraphQL response in `structuredContent`:

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "isError": true,
    "structuredContent": {
      "data": null,
      "errors": [
        {
          "message": "Cannot query field 'unknownField' on type 'User'",
          "path": ["user"],
          "extensions": { "code": "GRAPHQL_VALIDATION_FAILED" }
        }
      ]
    },
    "content": [
      { "type": "text", "text": "..." }
    ]
  }
}
```

Parse `structuredContent.errors` for the standard GraphQL error array, including any `extensions` your GraphQL server attaches.

For successful GraphQL responses, the same envelope is returned with `isError: false` and the GraphQL response body in `structuredContent`.

### Without structured content

When structured content is not enabled or the client negotiates an older MCP protocol version, parse the serialized GraphQL response from the text `content` instead.

### Private fields

When an operation uses `@private` fields, Apollo MCP Server filters those fields out of `structuredContent`. The full GraphQL response is preserved in the response metadata.

## Other tool errors

Some failures occur before the GraphQL request is sent. The server returns these as tool execution errors (`isError: true`) with a plain text message in `content`:

- Tool input does not match the operation's input schema
- Network or DNS failure reaching the GraphQL endpoint
- GraphQL endpoint returned a body that is not valid JSON

## Recommended error handling flow

1. Use a spec-compliant MCP client library.
2. Check for a JSON-RPC `error` response. This is a protocol failure. The tool did not run.
3. If the response is a successful `result`, check `result.isError`:
   - If `true`, parse `result.structuredContent.errors` for GraphQL errors when structured content is present. Fall back to `result.content` for serialized GraphQL responses and plain text failure messages.
   - If `false`, the tool succeeded. Read data from `structuredContent` or `content`.

## Monitoring

Apollo MCP Server records tool and operation outcomes in emitted metrics with a `success` attribute. Any tool call that returns `isError: true` is marked as `success=false`, including calls that return GraphQL errors. Alert on tool failure rates without parsing response bodies.

| Metric | Attribute | Value |
|--------|-----------|-------|
| `apollo.mcp.tool.count` | `success` | `false` for any `isError: true` |
| `apollo.mcp.operation.count` | `success` | `false` for GraphQL errors |
