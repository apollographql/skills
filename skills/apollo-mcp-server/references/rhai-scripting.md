# Rhai Scripting Reference

Apollo MCP Server supports [Rhai](https://rhai.rs), a lightweight embedded scripting language. Rhai scripts hook into the server's request lifecycle to inspect and modify outgoing GraphQL requests without recompiling the server.

## Common use cases

- Forwarding authentication headers from incoming MCP requests to the GraphQL endpoint
- Routing requests to different GraphQL endpoints based on request properties
- Rejecting requests that don't meet certain criteria

## Setup

Create a `rhai/` directory alongside your config file with a `main.rhai` entry point:

```
your-project/
├── config.yaml
└── rhai/
    └── main.rhai
```

The server loads `rhai/main.rhai` on startup. If the file doesn't exist, the server starts without any scripting.

## Lifecycle hooks

Hooks are Rhai functions with specific names. The server calls them automatically at the matching lifecycle event. If a hook isn't defined, it is skipped.

### on_execute_graphql_operation

Called before every outgoing GraphQL HTTP request. Use it to inspect or modify the endpoint and headers.

```rhai
fn on_execute_graphql_operation(ctx) {
    ctx.headers["x-custom-header"] = "my-value";
}
```

#### Context object

| Property | Type | Access | Description |
|----------|------|--------|-------------|
| `endpoint` | `String` | read/write | URL of the GraphQL endpoint |
| `headers` | `HeaderMap` | read/write | HTTP headers for the outgoing request |
| `incoming_request` | `HttpParts` | read-only | Original HTTP request from the MCP client (HTTP transport only) |
| `tool_name` | `String` | read-only | Name of the MCP tool that triggered the operation |

#### Working with headers

```rhai
fn on_execute_graphql_operation(ctx) {
    // Read a header (returns empty string if not present)
    let auth = ctx.headers["authorization"];

    // Set a header
    ctx.headers["x-request-id"] = "abc-123";
}
```

#### The incoming_request object

Available when using `streamable_http` transport. Empty when using `stdio`.

| Property | Type | Description |
|----------|------|-------------|
| `method` | `String` | HTTP method (e.g., `"POST"`) |
| `uri` | `String` | Request URI path (e.g., `"/mcp"`) |
| `headers` | `HeaderMap` | Headers from the incoming MCP request |

#### Example: Forward a header under a different name

```rhai
fn on_execute_graphql_operation(ctx) {
    let token = ctx.incoming_request.headers["authorization"];
    if token != "" {
        ctx.headers["x-forwarded-auth"] = token;
    }
}
```

#### Example: Route to a different endpoint

```rhai
fn on_execute_graphql_operation(ctx) {
    let region = Env::get("GRAPHQL_REGION");
    if region == "eu" {
        ctx.endpoint = "https://eu.api.example.com/graphql";
    }
}
```

## Error handling

Use `throw` inside a hook to abort the request and return an error to the MCP client. Throw a map with `message` and `code` for a structured error:

```rhai
fn on_execute_graphql_operation(ctx) {
    let token = ctx.incoming_request.headers["authorization"];
    if token == "" {
        throw #{
            message: "Missing authorization header",
            code: ErrorCode::INVALID_REQUEST
        };
    }
}
```

### Error codes

| Constant | Description |
|----------|-------------|
| `ErrorCode::INVALID_REQUEST` | Client error — missing header, invalid input |
| `ErrorCode::INTERNAL_ERROR` | Server-side error (default when no code is provided) |

Throwing a non-map value returns a generic internal error. The value is logged server-side but not forwarded to the client.

## Global variables

Top-level variables in `main.rhai` persist across all hook calls for the server's lifetime:

```rhai
let api_key = Env::get("API_KEY");
let backend_url = Env::get("BACKEND_URL");

fn on_execute_graphql_operation(ctx) {
    ctx.endpoint = backend_url;
    ctx.headers["x-api-key"] = api_key;
}
```

Avoid mutable global state — hooks for concurrent requests can run in any order.

## Modules

Organize scripts into multiple files using Rhai's module system:

```rhai
// rhai/main.rhai
import "helpers" as helpers;

fn on_execute_graphql_operation(ctx) {
    helpers::add_auth_headers(ctx);
}
```

```rhai
// rhai/helpers.rhai
fn add_auth_headers(ctx) {
    ctx.headers["authorization"] = "Bearer " + Env::get("AUTH_TOKEN");
}
```

## Built-in functions

All functions are available without imports.

### Env

| Function | Description |
|----------|-------------|
| `Env::get(name)` | Returns the environment variable value, or empty string if unset |

### JSON

| Function | Description |
|----------|-------------|
| `JSON::parse(input)` | Parses a JSON string into a Rhai value. Throws on invalid JSON. |
| `JSON::stringify(value)` | Converts a Rhai value to a JSON string |

```rhai
let data = JSON::parse("{\"name\": \"Apollo\"}");
print(data.name); // "Apollo"

let json = JSON::stringify(#{status: "ok"});
```

### Sha256

| Function | Description |
|----------|-------------|
| `Sha256::digest(input)` | Returns the hex-encoded SHA-256 hash of the input string |

### Regex

| Function | Description |
|----------|-------------|
| `Regex::is_match(string, pattern)` | Returns `true` if the pattern matches anywhere in the string |
| `Regex::replace(string, pattern, replacement)` | Replaces all matches. Supports `$1` and `$name` capture groups. |
| `Regex::matches(string, pattern)` | Returns an array of all matching substrings |

```rhai
let has_digits = Regex::is_match("order-123", "\\d+"); // true
let result = Regex::replace("foo bar", "foo", "baz");   // "baz bar"
let nums = Regex::matches("abc 123 def 456", "\\d+");   // ["123", "456"]
```

### Http

Make HTTP requests from scripts. All functions return a `Promise` — call `.wait()` to block for the response.

| Function | Description |
|----------|-------------|
| `Http::get(url)` | GET request |
| `Http::get(url, options)` | GET request with options |
| `Http::post(url)` | POST request |
| `Http::post(url, options)` | POST request with options |

Options map keys: `headers` (map), `body` (string), `timeout` (integer seconds, default 30).

Response properties: `.status` (integer), `.text()` (string), `.json()` (parsed value).

```rhai
let resp = Http::get("https://api.example.com/health").wait();
print(resp.status); // 200

let resp = Http::post("https://api.example.com/items", #{
    headers: #{ "content-type": "application/json" },
    body: JSON::stringify(#{ name: "item" })
}).wait();

if resp.status != 201 {
    throw #{
        message: "Failed: " + resp.text(),
        code: ErrorCode::INTERNAL_ERROR
    };
}
```
