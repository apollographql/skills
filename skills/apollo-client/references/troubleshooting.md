# Troubleshooting Reference

## Table of Contents

- [Setup Issues](#setup-issues)
- [Cache Issues](#cache-issues)
- [TypeScript Issues](#typescript-issues)
- [Performance Issues](#performance-issues)
- [DevTools Usage](#devtools-usage)
- [Common Error Messages](#common-error-messages)

## Setup Issues

### Provider Not Found

**Error:** `Could not find "client" in the context or passed in as an option`

**Cause:** Component is not wrapped with `ApolloProvider`.

**Solution:**
```tsx
// Ensure ApolloProvider wraps your app
import { ApolloProvider } from '@apollo/client';

function App() {
  return (
    <ApolloProvider client={client}>
      <YourApp />
    </ApolloProvider>
  );
}
```

### Multiple Apollo Clients

**Problem:** Unintended cache isolation or conflicting states.

**Solution:** Use a single client instance or explicitly manage multiple clients:
```tsx
// Single client (recommended)
const client = new ApolloClient({ /* ... */ });

export function App() {
  return (
    <ApolloProvider client={client}>
      <Router />
    </ApolloProvider>
  );
}

// Multiple clients (rare use case)
const publicClient = new ApolloClient({ uri: '/public/graphql', cache: new InMemoryCache() });
const adminClient = new ApolloClient({ uri: '/admin/graphql', cache: new InMemoryCache() });

function AdminSection() {
  return (
    <ApolloProvider client={adminClient}>
      <AdminDashboard />
    </ApolloProvider>
  );
}
```

### Client Created in Component

**Problem:** New client on every render causes cache loss.

**Solution:** Create client outside component or use `useMemo`:
```tsx
// Bad - new client on every render
function App() {
  const client = new ApolloClient({ /* ... */ }); // Don't do this!
  return <ApolloProvider client={client}>...</ApolloProvider>;
}

// Good - module-level client
const client = new ApolloClient({ /* ... */ });
function App() {
  return <ApolloProvider client={client}>...</ApolloProvider>;
}

// Good - useMemo for dynamic config
function App() {
  const client = useMemo(() => new ApolloClient({
    uri: process.env.REACT_APP_GRAPHQL_URL,
    cache: new InMemoryCache(),
  }), []);

  return <ApolloProvider client={client}>...</ApolloProvider>;
}
```

## Cache Issues

### Stale Data Not Updating

**Problem:** UI doesn't reflect mutations or other updates.

**Solution 1:** Verify cache key identification:
```typescript
const cache = new InMemoryCache({
  typePolicies: {
    // Ensure proper identification
    Product: {
      keyFields: ['id'], // or ['sku'] if no id field
    },
  },
});
```

**Solution 2:** Update cache after mutations:
```tsx
const [deleteProduct] = useMutation(DELETE_PRODUCT, {
  update: (cache, { data }) => {
    cache.evict({ id: cache.identify(data.deleteProduct) });
    cache.gc();
  },
});
```

**Solution 3:** Use appropriate fetch policy:
```tsx
const { data } = useQuery(GET_PRODUCTS, {
  fetchPolicy: 'cache-and-network', // Always fetch fresh data
});
```

### Missing Cache Updates After Mutation

**Problem:** New items don't appear in lists after creation.

**Solution:** Manually update the cache:
```tsx
const [createProduct] = useMutation(CREATE_PRODUCT, {
  update: (cache, { data }) => {
    const existing = cache.readQuery<{ products: Product[] }>({
      query: GET_PRODUCTS,
    });

    cache.writeQuery({
      query: GET_PRODUCTS,
      data: {
        products: [...(existing?.products ?? []), data.createProduct],
      },
    });
  },
});
```

### Pagination Cache Issues

**Problem:** Paginated data not merging correctly.

**Solution:** Configure proper type policies:
```typescript
const cache = new InMemoryCache({
  typePolicies: {
    Query: {
      fields: {
        products: {
          keyArgs: ['category'], // Only category creates new cache entries
          merge(existing = [], incoming) {
            return [...existing, ...incoming];
          },
        },
      },
    },
  },
});
```

### Cache Normalization Problems

**Problem:** Objects with same ID showing different data in different queries.

**Debug:** Check cache contents:
```typescript
// In DevTools console or component
console.log(client.cache.extract());
```

**Solution:** Ensure consistent `__typename` and `id` fields:
```graphql
query GetUsers {
  users {
    id  # Always include id
    name
  }
}
```

## TypeScript Issues

### Type Generation Setup

**Problem:** No type safety for GraphQL operations.

**Solution:** Set up GraphQL Code Generator:
```bash
npm install -D @graphql-codegen/cli @graphql-codegen/typescript \
  @graphql-codegen/typescript-operations @graphql-codegen/typed-document-node
```

```yaml
# codegen.yml
schema: "http://localhost:4000/graphql"
documents: "src/**/*.{ts,tsx}"
generates:
  src/generated/graphql.ts:
    plugins:
      - typescript
      - typescript-operations
      - typed-document-node
```

```json
// package.json
{
  "scripts": {
    "codegen": "graphql-codegen"
  }
}
```

### Using Generated Types

```tsx
import { useQuery } from '@apollo/client';
import { GetUsersDocument, GetUsersQuery } from './generated/graphql';

function UserList() {
  // Fully typed without manual type annotations
  const { data, loading, error } = useQuery(GetUsersDocument);

  // data.users is automatically typed as GetUsersQuery['users']
  return (
    <ul>
      {data?.users.map((user) => (
        <li key={user.id}>{user.name}</li>
      ))}
    </ul>
  );
}
```

## Performance Issues

### Over-Fetching

**Problem:** Fetching more data than needed.

**Solution:** Select only required fields:
```graphql
# Bad - fetching everything
query GetUsers {
  users {
    id
    name
    email
    profile { ... }
    posts { ... }
    friends { ... }
  }
}

# Good - fetch what's needed
query GetUserNames {
  users {
    id
    name
  }
}
```

### N+1 Queries

**Problem:** Multiple network requests for related data.

**Solution:** Structure queries to batch requests:
```graphql
# Bad - separate queries
query GetUser($id: ID!) { user(id: $id) { id name } }
query GetUserPosts($userId: ID!) { posts(userId: $userId) { id title } }

# Good - single query
query GetUserWithPosts($id: ID!) {
  user(id: $id) {
    id
    name
    posts {
      id
      title
    }
  }
}
```

### Unnecessary Re-Renders

**Problem:** Components re-render when unrelated cache data changes.

**Solution:** Use selective field reading:
```tsx
// Read only what you need
const { data } = useQuery(GET_USER, {
  variables: { id },
  // Only re-render when these fields change
  returnPartialData: true,
});
```

### Cache Misses

**Debug:** Enable cache logging:
```typescript
const client = new ApolloClient({
  cache: new InMemoryCache(),
  connectToDevTools: true,
});

// Or use Apollo DevTools to inspect cache
```

## DevTools Usage

### Installing Apollo DevTools

Install the browser extension:
- [Chrome](https://chrome.google.com/webstore/detail/apollo-client-devtools/jdkknkkbebbapilgoeccciglkfbmbnfm)
- [Firefox](https://addons.mozilla.org/en-US/firefox/addon/apollo-developer-tools/)

### Enabling DevTools

```typescript
const client = new ApolloClient({
  cache: new InMemoryCache(),
  connectToDevTools: process.env.NODE_ENV === 'development',
});
```

### DevTools Features

1. **Cache Inspector**: View normalized cache contents
2. **Queries**: See active queries and their states
3. **Mutations**: Track mutation history
4. **Explorer**: Build and test queries against your schema

### Debugging Cache

```typescript
// Log cache contents
console.log(JSON.stringify(client.cache.extract(), null, 2));

// Check specific object
console.log(client.cache.readFragment({
  id: 'User:1',
  fragment: gql`fragment _ on User { id name email }`,
}));
```

## Common Error Messages

### "Missing field 'X' in {...}"

**Cause:** Query doesn't include required field for cache normalization.

**Solution:** Include `id` and `__typename`:
```graphql
query GetUsers {
  users {
    id          # Required for caching
    __typename  # Usually added automatically
    name
  }
}
```

### "Store reset while query was in flight"

**Cause:** `client.resetStore()` called during active queries.

**Solution:** Wait for queries to complete or use `clearStore()`:
```typescript
// Option 1: Clear without refetching
await client.clearStore();

// Option 2: Reset and refetch active queries
await client.resetStore();
```

### "Invariant Violation: X"

**Cause:** Various configuration or usage errors.

**Common fixes:**
- Ensure `ApolloProvider` wraps the component tree
- Check that `gql` tagged templates are valid GraphQL
- Verify cache configuration matches your schema

### "Query was cancelled"

**Cause:** Component unmounted before query completed.

**Solution:** This is usually expected behavior. If problematic:
```tsx
// The query will continue but won't update unmounted component
const { data } = useQuery(QUERY, {
  // This prevents the warning
  fetchPolicy: 'cache-and-network',
});
```

### "Cannot read property 'X' of undefined"

**Cause:** Accessing data before query completes.

**Solution:** Check loading state:
```tsx
const { data, loading } = useQuery(GET_USER);

if (loading) return <Spinner />;

// Now data is guaranteed to exist
return <div>{data.user.name}</div>;

// Or use optional chaining
return <div>{data?.user?.name}</div>;
```
