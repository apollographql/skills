# Apollo Client Setup with TanStack Start

This guide covers setting up Apollo Client in a TanStack Start application with support for modern streaming SSR.

## Why Use Apollo Client with TanStack Start?

TanStack Start (formerly TanStack Router with SSR) provides a modern routing solution with built-in support for data loading and streaming SSR. The Apollo Client integration enables you to execute GraphQL queries during route loading and seamlessly hydrate data on the client side.

> **Note:** When using `npx create-tsrouter-app` to create a new TanStack Start application, you can choose Apollo Client in the setup wizard to have all of this configuration automatically set up for you.

## Installation

Install Apollo Client and the TanStack Start integration package:

```bash
npm install @apollo/client-integration-tanstack-start @apollo/client graphql rxjs
```

## Setup

### Step 1: Configure Root Route with Context

In your `routes/__root.tsx`, change from `createRootRoute` to `createRootRouteWithContext` to provide the right context type:

```typescript
import type { ApolloClientIntegration } from "@apollo/client-integration-tanstack-start";
import {
  createRootRouteWithContext,
  Outlet,
} from "@tanstack/react-router";

export const Route = createRootRouteWithContext<ApolloClientIntegration.RouterContext>()({
  component: RootComponent,
});

function RootComponent() {
  return (
    <html>
      <head>
        <meta charSet="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <title>My App</title>
      </head>
      <body>
        <Outlet />
      </body>
    </html>
  );
}
```

### Step 2: Set Up Apollo Client in Router

In your `router.tsx`, set up your Apollo Client instance and run `routerWithApolloClient`:

```typescript
import {
  routerWithApolloClient,
  ApolloClient,
  InMemoryCache,
} from "@apollo/client-integration-tanstack-start";
import { HttpLink } from "@apollo/client";
import { createRouter } from "@tanstack/react-router";
import { routeTree } from "./routeTree.gen";

export function getRouter() {
  const apolloClient = new ApolloClient({
    cache: new InMemoryCache(),
    link: new HttpLink({ uri: "https://your-graphql-endpoint.com/graphql" }),
  });

  const router = createRouter({
    routeTree,
    context: {
      ...routerWithApolloClient.defaultContext,
    },
  });

  return routerWithApolloClient(router, apolloClient);
}
```

> **Important:** `ApolloClient` and `InMemoryCache` must be imported from `@apollo/client-integration-tanstack-start`, not from `@apollo/client`.

## Usage

### Option 1: Loader with preloadQuery and useReadQuery

Use the `preloadQuery` function in your route loader to preload data during navigation:

```typescript
import { gql } from "@apollo/client";
import { useReadQuery } from "@apollo/client/react";
import { createFileRoute } from "@tanstack/react-router";

// TypedDocumentNode definition
const GET_USER = gql`
  query GetUser($id: ID!) {
    user(id: $id) {
      id
      name
      email
    }
  }
`;

export const Route = createFileRoute("/user/$userId")({
  component: RouteComponent,
  loader: ({ context: { preloadQuery }, params }) => {
    const queryRef = preloadQuery(GET_USER, {
      variables: { id: params.userId },
    });

    return {
      queryRef,
    };
  },
});

function RouteComponent() {
  const { queryRef } = Route.useLoaderData();
  const { data } = useReadQuery(queryRef);

  return (
    <div>
      <h1>{data.user.name}</h1>
      <p>{data.user.email}</p>
    </div>
  );
}
```

### Option 2: Direct useSuspenseQuery in Component

You can also use Apollo Client's suspenseful hooks directly in your component without a loader:

```typescript
import { gql, useSuspenseQuery } from "@apollo/client/react";
import { createFileRoute } from "@tanstack/react-router";

// TypedDocumentNode definition
const GET_POSTS = gql`
  query GetPosts {
    posts {
      id
      title
      content
    }
  }
`;

export const Route = createFileRoute("/posts")({
  component: RouteComponent,
});

function RouteComponent() {
  const { data } = useSuspenseQuery(GET_POSTS);

  return (
    <div>
      <h1>Posts</h1>
      <ul>
        {data.posts.map((post) => (
          <li key={post.id}>
            <h2>{post.title}</h2>
            <p>{post.content}</p>
          </li>
        ))}
      </ul>
    </div>
  );
}
```

### Multiple Queries in a Loader

You can preload multiple queries in a single loader:

```typescript
import { gql } from "@apollo/client";
import { useReadQuery } from "@apollo/client/react";
import { createFileRoute } from "@tanstack/react-router";

// TypedDocumentNode definitions omitted for brevity

export const Route = createFileRoute("/dashboard")({
  component: RouteComponent,
  loader: ({ context: { preloadQuery } }) => {
    const userQueryRef = preloadQuery(GET_USER, {
      variables: { id: "current" },
    });

    const statsQueryRef = preloadQuery(GET_STATS, {
      variables: { period: "month" },
    });

    return {
      userQueryRef,
      statsQueryRef,
    };
  },
});

function RouteComponent() {
  const { userQueryRef, statsQueryRef } = Route.useLoaderData();
  const { data: userData } = useReadQuery(userQueryRef);
  const { data: statsData } = useReadQuery(statsQueryRef);

  return (
    <div>
      <h1>Welcome, {userData.user.name}</h1>
      <div>
        <h2>Monthly Stats</h2>
        <p>Views: {statsData.stats.views}</p>
        <p>Clicks: {statsData.stats.clicks}</p>
      </div>
    </div>
  );
}
```

### Using useQueryRefHandlers for Refetching

When using `useReadQuery`, you can get refetch functionality from `useQueryRefHandlers`:

> **Important:** Always call `useQueryRefHandlers` before `useReadQuery`. These two hooks interact with the same `queryRef`, and calling them in the wrong order could cause subtle bugs.

```typescript
import { useReadQuery, useQueryRefHandlers, QueryRef } from "@apollo/client/react";

function UserComponent({ queryRef }: { queryRef: QueryRef<GetUserQuery> }) {
  const { refetch } = useQueryRefHandlers(queryRef);
  const { data } = useReadQuery(queryRef);

  return (
    <div>
      <h1>{data.user.name}</h1>
      <button onClick={() => refetch()}>Refresh</button>
    </div>
  );
}
```

## Important Considerations

1. **Import from Integration Package:** Always import `ApolloClient` and `InMemoryCache` from `@apollo/client-integration-tanstack-start`, not from `@apollo/client`, to ensure proper SSR hydration.

2. **Context Type:** Use `createRootRouteWithContext<ApolloClientIntegration.RouterContext>()` to provide proper TypeScript types for the `preloadQuery` function in loaders.

3. **Loader vs Component Queries:**
   - Use `preloadQuery` in loaders when you want to start fetching data before the component renders
   - Use `useSuspenseQuery` directly in components for simpler cases or when data fetching can wait until render

4. **Streaming SSR:** The integration fully supports React's streaming SSR capabilities. Place `Suspense` boundaries strategically for optimal user experience.

5. **Cache Management:** The Apollo Client instance is shared across all routes, so cache updates from one route will be reflected in all routes that use the same data.

6. **Authentication:** Use Apollo Client's `SetContextLink` for dynamic auth tokens.

## Advanced Configuration

### Adding Authentication

For authentication in TanStack Start with SSR support, you need to handle both server and client environments differently. Use `createIsomorphicFn` to provide environment-specific implementations:

```typescript
import { ApolloClient, InMemoryCache } from "@apollo/client-integration-tanstack-start";
import { ApolloLink, HttpLink } from "@apollo/client";
import { SetContextLink } from "@apollo/client/link/context";
import { createIsomorphicFn } from "@tanstack/react-start";
import { createRouter } from "@tanstack/react-router";
import { getSession } from "@tanstack/react-start/server";
import { routeTree } from "./routeTree.gen";

// Define your session data structure
type SessionData = {
  userId?: string;
  authToken?: `******;
};

// Create isomorphic link that uses different implementations per environment
const createAuthLink = createIsomorphicFn()
  .server(() => {
    // Server-only: Access session data using getSession
    return new SetContextLink(async (prevContext) => {
      const session = await getSession<SessionData>({
        name: "app-session",
        password: process.env.SESSION_SECRET!,
      });

      return {
        headers: {
          ...prevContext.headers,
          authorization: session.data.authToken ?? "",
        },
      };
    });
  })
  .client(() => {
    // Client-only: Access localStorage or other browser APIs
    return new SetContextLink((prevContext) => {
      return {
        headers: {
          ...prevContext.headers,
          authorization: localStorage.getItem("authToken") ?? "",
        },
      };
    });
  });

export function getRouter() {
  const httpLink = new HttpLink({
    uri: "https://your-graphql-endpoint.com/graphql",
  });

  const apolloClient = new ApolloClient({
    cache: new InMemoryCache(),
    link: ApolloLink.from([createAuthLink(), httpLink]),
  });

  const router = createRouter({
    routeTree,
    context: {
      ...routerWithApolloClient.defaultContext,
    },
  });

  return routerWithApolloClient(router, apolloClient);
}
```

> **Important:** The `getRouter` function is called both on the server and client, so it must not contain environment-specific code. Use `createIsomorphicFn` to provide different implementations:
>
> - **Server:** Use `getSession` from `@tanstack/react-start/server` to access session data (or other server-only functions like `getCookies`, `getCookie`)
> - **Client:** Use `localStorage` or other browser APIs to access auth tokens
>
> This ensures your authentication works correctly in both SSR and browser contexts.

### Custom Cache Configuration

```typescript
import { ApolloClient, InMemoryCache } from "@apollo/client-integration-tanstack-start";
import { HttpLink } from "@apollo/client";
import { createRouter } from "@tanstack/react-router";
import { routeTree } from "./routeTree.gen";
import { routerWithApolloClient } from "@apollo/client-integration-tanstack-start";

export function getRouter() {
  const apolloClient = new ApolloClient({
    cache: new InMemoryCache({
      typePolicies: {
        Query: {
          fields: {
            posts: {
              merge(existing = [], incoming) {
                return [...existing, ...incoming];
              },
            },
          },
        },
      },
    }),
    link: new HttpLink({ uri: "https://your-graphql-endpoint.com/graphql" }),
  });

  const router = createRouter({
    routeTree,
    context: {
      ...routerWithApolloClient.defaultContext,
    },
  });

  return routerWithApolloClient(router, apolloClient);
}
```
