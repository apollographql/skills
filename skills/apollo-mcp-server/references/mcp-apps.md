# MCP Apps Reference

MCP Apps are mini applications that run inside MCP Apps-compatible hosts (such as ChatGPT with OpenAI's Apps SDK). Unlike standard MCP tools that return plain text, MCP Apps give you complete control over how data appears.

## MCP Apps vs standard MCP tools

| Feature | Standard MCP Tools | MCP Apps |
|---------|--------------------|----------|
| Response format | Plain text | Custom HTML/UI |
| Display control | Text formatting only | Complete layout and styling control |
| Interactivity | None | Forms, buttons, interactive elements |
| Best for | Quick queries, simple responses | Visualizations, interactive workflows |

## When to use MCP Apps

- Display data in tables, cards, charts, or custom layouts
- Build interactive forms and buttons
- Create rich product catalogs, property listings, dashboards

## How MCP Apps work

MCP Apps combine GraphQL operations with custom UI resources:

1. **Define GraphQL operations** that fetch data from your API
2. **Create a UI resource** (React app) that controls how data is displayed
3. **Package them together** — Apollo MCP Server serves the app as an MCP resource

The host discovers the app, pre-fetches the UI, then injects GraphQL data into the iframe when a tool is invoked.

## Getting started

Use the [Apollo AI Apps Template](https://github.com/apollographql/ai-apps-template) — a complete setup with React, Vite, Apollo Client, and Apollo MCP Server integration.

### Prerequisites

- Apollo MCP Server
- Node.js v18 or later
- npm or yarn
- MCP Apps-compatible host (e.g., ChatGPT)
- Optional: ngrok for tunneling during development

### Project structure

```
your-app/
├── apps/
│   └── my-app/
│       ├── src/
│       │   ├── App.tsx          # Main app component
│       │   └── operations.ts    # GraphQL operations with @tool directive
│       └── app.config.ts        # App-level configuration
├── config.yaml                  # Apollo MCP Server config
└── package.json
```

## Development concepts

### Apollo Client initialization

Use `@apollo/client-ai-apps` to set up Apollo Client for the MCP Apps environment:

```tsx
import { ApolloProvider } from '@apollo/client-ai-apps';

function App() {
  return (
    <ApolloProvider>
      <React.Suspense fallback={<div>Loading...</div>}>
        <MyComponent />
      </React.Suspense>
    </ApolloProvider>
  );
}
```

### Registering MCP tools with @tool

Add the `@tool` directive to GraphQL operations to register them as MCP tools:

```graphql
query GetProducts @tool(description: "Fetch a list of products") {
  products {
    id
    name
    price
  }
}
```

### Pre-fetching data with @prefetch

Use `@prefetch` to load data before the tool is invoked, reducing latency:

```graphql
query GetProductDetails($id: ID!) @tool @prefetch {
  product(id: $id) {
    id
    name
    description
    imageUrl
  }
}
```

### Accessing tool input

Use `createHydrationUtils` to populate component variables from the MCP tool's input:

```tsx
import { createHydrationUtils } from '@apollo/client-ai-apps';
import { GetProductDetailsDocument } from './generated/graphql';

const { useVariables } = createHydrationUtils(GetProductDetailsDocument);

function ProductDetail() {
  const variables = useVariables();
  const { data } = useSuspenseQuery(GetProductDetailsDocument, { variables });
  return <div>{data.product.name}</div>;
}
```

### Accessing host context

Use `useHostContext` to get information about the current host environment:

```tsx
import { useHostContext } from '@apollo/client-ai-apps';

function MyComponent() {
  const context = useHostContext();
  // context.platform — current platform identifier
}
```

## App configuration

Configure each app in `app.config.ts`:

```ts
export default {
  name: "my-app",
  description: "My MCP App",
  version: "1.0.0",
  entry: "./src/App.tsx",
};
```

### Key configuration options

| Option | Description |
|--------|-------------|
| `name` | App identifier |
| `description` | Shown to MCP hosts |
| `version` | App version string |
| `entry` | Entry point file |
| `csp` | Content Security Policy settings |

## Architecture

### App components

- **Tools**: GraphQL operations decorated with `@tool` — these become the MCP tools that the host invokes
- **Resources**: The built `.html` file containing the React application code

### Flow

1. **Discovery phase**: Host discovers available tools and pre-fetches the UI resource
2. **Tool execution phase**: User invokes a tool → host calls the MCP server → server executes GraphQL → host injects data into the iframe

### Build output

Compiled apps are placed in the `apps/` directory at the project root. Apollo MCP Server serves them as MCP resources automatically.

## Platform-specific modules

Create platform-specific implementations using file extensions:

- `.openai.tsx` — ChatGPT / OpenAI Apps SDK
- `.mcp.tsx` — Generic MCP Apps host

```tsx
// Button.openai.tsx
export function Button({ onClick, children }) {
  return <button onClick={onClick}>{children}</button>;
}
```

Use the `Platform` utility for runtime detection when needed.

## TypeScript configuration

The template includes Vite plugin configuration and TypeScript extensions for MCP Apps. Schema type generation is supported via standard Apollo codegen tools.
