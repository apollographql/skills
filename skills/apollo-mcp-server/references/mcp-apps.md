# MCP Apps

## Overview

MCP Apps are interactive mini-applications that run inside MCP Apps-compatible hosts such as ChatGPT. Unlike standard MCP tools that return plain text, apps provide complete control over how data appears, enabling custom visualizations, interactive forms, and rich UI beyond text responses.

Apollo MCP Server bridges your GraphQL APIs to the MCP Apps specification. The workflow is:

1. Define GraphQL operations that fetch data from your APIs
2. Create a UI resource (HTML/React) that controls how data is displayed
3. Package them together as an app that compatible hosts can discover and use

Building an MCP App is similar to building a GraphQL app with Apollo Client. Add `@tool` and `@prefetch` directives to your GraphQL operations, and the server handles the rest.

## MCP Apps vs standard MCP tools

| Feature | Standard MCP Tools | MCP Apps |
|---------|-------------------|----------|
| Response format | Plain text | Custom HTML/UI |
| Display control | Limited to text formatting | Complete control over layout and styling |
| Interactivity | None | Full interactive capabilities |
| Use case | Simple data retrieval | Rich experiences |
| Best for | Quick queries, simple responses | Complex visualizations, interactive workflows |

Use MCP Apps when you need display customization, interactive experiences, or complex visualizations.

## App structure

Apps live in a directory (default `apps/`), with each subdirectory containing an `.application-manifest.json` file:

```
your-project/
├── config.yaml
└── apps/
    └── my-app/
        ├── .application-manifest.json   # Auto-generated manifest
        └── index.html                   # Built UI resource
```

### Configuring the apps directory

Set `apps.path` in your config file to load apps from a custom directory:

```yaml
apps:
  path: /config/apps
```

The path can be absolute or relative to the process working directory. Override it with the `APOLLO_MCP_APPS__PATH` environment variable. If the directory does not exist, the server starts without apps.

## Connecting to an app

### App query parameter

Specify which app to load with the `app` query parameter on the MCP endpoint:

```
http://your-server.com/mcp?app=my-app
```

The app name corresponds to the subdirectory name in `apps/`.

### App target

Apollo MCP Server supports two targets. Use the `appTarget` query parameter to select one:

| Target | URL | Description |
|--------|-----|-------------|
| OpenAI Apps | `?app=my-app&appTarget=openai` | Hosts supporting OpenAI's Apps SDK specification |
| MCP Apps | `?app=my-app&appTarget=mcp` | MCP-compatible clients |

## Manifest

The `.application-manifest.json` file is auto-generated from your app code and configuration files. Do not edit it directly. Make changes to your app code (for GraphQL operations) and configuration files (for app-level settings). Add `.application-manifest.json` to `.gitignore`.

## App configuration

Configuration is loaded by `cosmiconfig` from these locations (checked in order):

- `.apollo-client-ai-apps.config.{json,yml,yaml,js,ts,cjs}`
- `apollo-client-ai-apps.config.{json,yml,yaml,js,ts,cjs}`
- An `apollo-client-ai-apps` key in `package.json`

Place the config file at the root of your client application code.

### Configuration options

| Option | Required | Description |
|--------|----------|-------------|
| `name` | No | Application name. Defaults to `name` in `package.json` |
| `description` | No | Application description. Prefixed to tool descriptions |
| `version` | No | Application version. Defaults to `version` in `package.json` |
| `entry` | No | Entry point configuration per mode (development/production) |
| `csp.connectDomains` | No | Approved origins for fetch/XHR/WebSocket requests |
| `csp.frameDomains` | No | Approved origins for nested iframes |
| `csp.redirectDomains` | No | Approved origins for redirects (OpenAI only) |
| `csp.resourceDomains` | No | Approved origins for static resources |
| `csp.baseUriDomains` | No | Approved origins for base URI (MCP Apps only) |
| `widgetSettings.prefersBorder` | No | Visual boundary preference (boolean) |
| `widgetSettings.description` | No | Widget description (OpenAI only) |
| `widgetSettings.domain` | No | Dedicated origin for the view |
| `labels.toolInvocation.invoking` | No | Status text while tool runs (OpenAI only) |
| `labels.toolInvocation.invoked` | No | Status text after tool completes (OpenAI only) |

### TypeScript config example

```ts
import { ApolloClientAiAppsConfig } from "@apollo/client-ai-apps/config";

const config: ApolloClientAiAppsConfig.Config = {
  name: "My App",
  description: "My app description",
  version: "1.0.0",
  entry: {
    development: "http://localhost:5173",
    production: {
      mcp: "index.html",
      openai: "index.html",
    },
  },
  csp: {
    connectDomains: ["https://api.example.com"],
  },
};

export default config;
```

## Tool directives

Define tools in your app code using GraphQL directives.

### `@tool`

Marks a GraphQL operation as an MCP tool that hosts can invoke.

| Argument | Required | Description |
|----------|----------|-------------|
| `name` | No | Tool name. Defaults to operation name. Must be unique within the app |
| `description` | No | Tool description. Defaults to operation description |
| `extraInputs` | No | Additional tool inputs not part of the GraphQL operation |
| `extraOutputs` | No | Free-form output data written to the manifest tool config |
| `labels` | No | Tool-specific status labels (OpenAI only) |

When multiple `@tool` directives appear on the same operation, provide `name` and `description` explicitly on each.

### `@prefetch`

Marks a GraphQL operation to run automatically whenever any tool in the app is invoked. Prefetch operations execute after the main tool operation and their results are included in the tool response.

### `@private`

Hides specified fields from the LLM while keeping them accessible to your app's UI code. Apply `@private` to individual fields within a GraphQL operation.

```graphql
query GetUser($id: ID!) @tool(
  name: "GetUser",
  description: "Look up user details"
) {
  user(id: $id) {
    name
    email @private
    internalId @private
  }
}
```

Fields marked `@private` are filtered from `structuredContent` in tool responses and omitted from the output schema.

## Security

> **Security: mutation mode applies to MCP Apps.** App manifests are subject to the same `overrides.mutation_mode` gate as regular operations. With `mutation_mode: none`, Apollo MCP Server rejects an app manifest that contains a mutation instead of partially loading the app.

- ALWAYS set `mutation_mode` to `explicit` or `none` unless the app requires ad-hoc mutations
- NEVER assume app manifests bypass operation-type restrictions

## Getting started

Use the [Apollo AI Apps Template](https://github.com/apollographql/ai-apps-template) for a complete setup with React, Vite, Apollo Client, and Apollo MCP Server integration.
