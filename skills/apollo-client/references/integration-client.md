# Apollo Client Integration for Client-Side Apps

This guide covers setting up Apollo Client in client-side React applications without server-side rendering (SSR). This includes applications using Vite, Parcel, Create React App, or other bundlers that don't implement SSR.

For applications with SSR, use one of the framework-specific integration guides instead:
- [Next.js App Router](integration-nextjs.md)
- [React Router Framework Mode](integration-react-router.md)
- [TanStack Start](integration-tanstack-start.md)

## Installation

```bash
npm install @apollo/client graphql rxjs
```

## TypeScript Code Generation (optional but recommended)

For type-safe GraphQL operations with TypeScript, see the [TypeScript Code Generation guide](typescript-codegen.md).

## Setup Steps

### Step 1: Create Client

```typescript
import { ApolloClient, InMemoryCache, HttpLink } from "@apollo/client";
import { SetContextLink } from "@apollo/client/link/context";

const httpLink = new HttpLink({
  uri: "https://your-graphql-endpoint.com/graphql",
});

// Use SetContextLink for auth headers to update dynamically per request
const authLink = new SetContextLink(({ headers }) => {
  const token = localStorage.getItem("token");
  return {
    headers: {
      ...headers,
      authorization: token ? `Bearer ${token}` : "",
    },
  };
});

const client = new ApolloClient({
  link: authLink.concat(httpLink),
  cache: new InMemoryCache(),
});
```

### Step 2: Setup Provider

```tsx
import { ApolloProvider } from "@apollo/client";
import App from "./App";

function Root() {
  return (
    <ApolloProvider client={client}>
      <App />
    </ApolloProvider>
  );
}
```

### Step 3: Execute Query

```tsx
import { gql } from "@apollo/client";
import { useQuery } from "@apollo/client/react";

const GET_USERS = gql`
  query GetUsers {
    users {
      id
      name
      email
    }
  }
`;

function UserList() {
  const { loading, error, data, dataState } = useQuery(GET_USERS);

  if (loading) return <p>Loading...</p>;
  if (error) return <p>Error: {error.message}</p>;

  // TypeScript: dataState === "ready" provides better type narrowing than just checking data
  return (
    <ul>
      {data.users.map((user) => (
        <li key={user.id}>{user.name}</li>
      ))}
    </ul>
  );
}
```

## Basic Query Usage

### Using Variables

```tsx
const GET_USER = gql`
  query GetUser($id: ID!) {
    user(id: $id) {
      id
      name
      email
    }
  }
`;

function UserProfile({ userId }: { userId: string }) {
  const { loading, error, data, dataState } = useQuery(GET_USER, {
    variables: { id: userId },
  });

  if (loading) return <p>Loading...</p>;
  if (error) return <p>Error: {error.message}</p>;

  // TypeScript: dataState === "ready" provides better type narrowing than just checking data
  return <div>{data.user.name}</div>;
}
```

> **Note for TypeScript users**: Use [`dataState`](https://www.apollographql.com/docs/react/data/typescript#type-narrowing-data-with-datastate) for more robust type safety and better type narrowing in Apollo Client 4.x.

### TypeScript Integration

```typescript
// Define types for codegen or TypedDocumentNode
interface GetUserData {
  user: {
    id: string;
    name: string;
    email: string;
  };
}

interface GetUserVariables {
  id: string;
}

// Types are inferred from TypedDocumentNode - never use manual generics
const GET_USER: TypedDocumentNode<GetUserData, GetUserVariables> = gql`
  query GetUser($id: ID!) {
    user(id: $id) {
      id
      name
      email
    }
  }
`;

const { data } = useQuery(GET_USER, {
  variables: { id: userId },
});

// data.user is automatically typed from GET_USER
```

## Basic Mutation Usage

```tsx
import { gql, TypedDocumentNode } from "@apollo/client";
import { useMutation } from "@apollo/client/react";

interface CreateUserMutation {
  createUser: {
    id: string;
    name: string;
    email: string;
  };
}

interface CreateUserMutationVariables {
  input: {
    name: string;
    email: string;
  };
}

const CREATE_USER: TypedDocumentNode<
  CreateUserMutation,
  CreateUserMutationVariables
> = gql`
  mutation CreateUser($input: CreateUserInput!) {
    createUser(input: $input) {
      id
      name
      email
    }
  }
`;

function CreateUserForm() {
  const [createUser, { loading, error }] = useMutation(CREATE_USER);

  const handleSubmit = async (formData: FormData) => {
    const { data } = await createUser({
      variables: {
        input: {
          name: formData.get("name") as string,
          email: formData.get("email") as string,
        },
      },
    });
    if (data) {
      console.log("Created user:", data.createUser);
    }
  };

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        handleSubmit(new FormData(e.currentTarget));
      }}
    >
      <input name="name" placeholder="Name" />
      <input name="email" placeholder="Email" />
      <button type="submit" disabled={loading}>
        {loading ? "Creating..." : "Create User"}
      </button>
      {error && <p>Error: {error.message}</p>}
    </form>
  );
}
```

## Client Configuration Options

```typescript
const client = new ApolloClient({
  // Required: The cache implementation
  cache: new InMemoryCache({
    typePolicies: {
      Query: {
        fields: {
          // Field-level cache configuration
        },
      },
    },
  }),

  // Network layer
  link: new HttpLink({ uri: "/graphql" }),

  // Avoid defaultOptions if possible as they break TypeScript expectations.
  // Configure options per-query/mutation instead for better type safety.
  // defaultOptions: {
  //   watchQuery: { fetchPolicy: 'cache-and-network' },
  // },

  // DevTools are enabled by default in development
  // Only configure when enabling in production
  devtools: {
    enabled: true, // Only needed for production
  },

  // Custom name for this client instance
  clientAwareness: {
    name: "web-client",
    version: "1.0.0",
  },
});
```

## Important Considerations

1. **Client-Side Only:** This setup is for client-side apps without SSR. The Apollo Client instance is created once and reused throughout the application lifecycle.

2. **Authentication:** Use `SetContextLink` to dynamically add authentication headers from `localStorage` or other client-side storage.

3. **Cache Persistence:** Consider using `apollo3-cache-persist` if you need to persist the cache between sessions.

4. **Environment Variables:** Store your GraphQL endpoint URL in environment variables for different environments (development, staging, production).

5. **Error Handling:** Always handle `loading` and `error` states when using `useQuery` or `useLazyQuery`. For Suspense-based hooks (`useSuspenseQuery`), React handles this through `<Suspense>` boundaries and error boundaries.
