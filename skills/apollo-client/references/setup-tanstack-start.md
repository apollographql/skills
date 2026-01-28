# Apollo Client Setup with TanStack Start

This guide covers setting up Apollo Client in a TanStack Start application with support for modern streaming SSR.

## Why Use Apollo Client with TanStack Start?

TanStack Start (formerly TanStack Router with SSR) provides a modern routing solution with built-in support for data loading and streaming SSR. The Apollo Client integration enables you to execute GraphQL queries during route loading and seamlessly hydrate data on the client side.

## Installation

Install Apollo Client and the TanStack Start integration package:

```bash
npm install @apollo/client-integration-tanstack-start @apollo/client graphql
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
import { useReadQuery } from "@apollo/client";
import { createFileRoute } from "@tanstack/react-router";

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
import { useSuspenseQuery } from "@apollo/client";
import { createFileRoute } from "@tanstack/react-router";

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

```typescript
import { useReadQuery, useQueryRefHandlers, QueryRef } from "@apollo/client";

function UserComponent({ queryRef }: { queryRef: QueryRef<GetUserQuery> }) {
  const { data } = useReadQuery(queryRef);
  const { refetch } = useQueryRefHandlers(queryRef);

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

6. **Authentication:** Configure auth headers in the `HttpLink` during client creation, or use Apollo Client's `setContext` link for dynamic auth tokens.

## Advanced Configuration

### Adding Authentication

```typescript
import { setContext } from "@apollo/client/link/context";

export function getRouter() {
  const httpLink = new HttpLink({
    uri: "https://your-graphql-endpoint.com/graphql",
  });

  const authLink = setContext((_, { headers }) => {
    const token = localStorage.getItem("token");
    return {
      headers: {
        ...headers,
        authorization: token ? `Bearer ${token}` : "",
      },
    };
  });

  const apolloClient = new ApolloClient({
    cache: new InMemoryCache(),
    link: authLink.concat(httpLink),
  });

  // ... rest of router setup
}
```

### Custom Cache Configuration

```typescript
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

  // ... rest of router setup
}
```
