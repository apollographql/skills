# Error Handling Reference

## Table of Contents

- [Error Types](#error-types)
- [Error Policy](#error-policy)
- [Error Links](#error-links)
- [Retry Logic](#retry-logic)
- [Error Boundaries](#error-boundaries)

## Error Types

Apollo Client distinguishes between GraphQL errors and network errors.

### GraphQL Errors

GraphQL errors are returned in the `errors` array of the response. The request succeeded at the network level.

```typescript
// Response with GraphQL error
{
  "data": { "user": null },
  "errors": [
    {
      "message": "User not found",
      "path": ["user"],
      "extensions": {
        "code": "NOT_FOUND"
      }
    }
  ]
}
```

### Network Errors

Network errors occur when the request fails to reach the server or the server fails to respond.

```tsx
function UserProfile({ userId }: { userId: string }) {
  const { data, error, loading } = useQuery(GET_USER, {
    variables: { id: userId },
  });

  if (error) {
    // Check error type
    if (error.networkError) {
      // Network-level failure
      console.error('Network error:', error.networkError.message);
      return <p>Network error. Please check your connection.</p>;
    }

    if (error.graphQLErrors.length > 0) {
      // GraphQL-level errors
      return (
        <div>
          {error.graphQLErrors.map((err, i) => (
            <p key={i}>Error: {err.message}</p>
          ))}
        </div>
      );
    }
  }

  return data ? <Profile user={data.user} /> : null;
}
```

### ApolloError Structure

```typescript
interface ApolloError extends Error {
  message: string;
  graphQLErrors: ReadonlyArray<GraphQLError>;
  networkError: Error | null;
  extraInfo: any;
}
```

## Error Policy

Control how errors are handled per query/mutation.

| Policy | GraphQL Errors | Network Errors | Data |
|--------|---------------|----------------|------|
| `none` (default) | Throws | Throws | Discarded |
| `ignore` | Ignored | Throws | Used |
| `all` | Returned in `error` | Throws | Used |

### Using errorPolicy

```tsx
// Get both data and errors
const { data, error } = useQuery(GET_USERS, {
  errorPolicy: 'all',
});

// Handle partial success
if (data?.users) {
  // Some data was returned
  renderUsers(data.users);
}

if (error?.graphQLErrors) {
  // Some fields had errors
  showWarning(error.graphQLErrors);
}
```

### Global Error Policy

```typescript
const client = new ApolloClient({
  cache: new InMemoryCache(),
  link: httpLink,
  defaultOptions: {
    watchQuery: {
      errorPolicy: 'all',
    },
    query: {
      errorPolicy: 'all',
    },
    mutate: {
      errorPolicy: 'all',
    },
  },
});
```

## Error Links

Use `onError` link to handle errors globally.

### Basic Error Link

```typescript
import { onError } from '@apollo/client/link/error';

const errorLink = onError(({ graphQLErrors, networkError, operation }) => {
  if (graphQLErrors) {
    graphQLErrors.forEach(({ message, locations, path, extensions }) => {
      console.error(
        `[GraphQL error]: Message: ${message}, Location: ${locations}, Path: ${path}`
      );

      // Handle specific error codes
      if (extensions?.code === 'UNAUTHENTICATED') {
        // Redirect to login
        window.location.href = '/login';
      }
    });
  }

  if (networkError) {
    console.error(`[Network error]: ${networkError}`);
  }
});
```

### Composing Links

```typescript
import { ApolloClient, HttpLink, from } from '@apollo/client';
import { onError } from '@apollo/client/link/error';

const httpLink = new HttpLink({
  uri: '/graphql',
});

const errorLink = onError(({ graphQLErrors, networkError }) => {
  // Error handling...
});

const client = new ApolloClient({
  cache: new InMemoryCache(),
  link: from([errorLink, httpLink]),
});
```

### Forwarding Operations

```typescript
import { onError } from '@apollo/client/link/error';
import { Observable } from '@apollo/client';

const errorLink = onError(({ graphQLErrors, operation, forward }) => {
  if (graphQLErrors) {
    for (const err of graphQLErrors) {
      if (err.extensions?.code === 'UNAUTHENTICATED') {
        // Refresh token and retry
        return new Observable((observer) => {
          refreshToken()
            .then((newToken) => {
              // Update headers
              operation.setContext({
                headers: {
                  ...operation.getContext().headers,
                  authorization: `Bearer ${newToken}`,
                },
              });

              // Retry the operation
              forward(operation).subscribe(observer);
            })
            .catch((error) => {
              observer.error(error);
            });
        });
      }
    }
  }
});
```

## Retry Logic

### Retry Link

```typescript
import { RetryLink } from '@apollo/client/link/retry';

const retryLink = new RetryLink({
  delay: {
    initial: 300,
    max: Infinity,
    jitter: true,
  },
  attempts: {
    max: 5,
    retryIf: (error, operation) => {
      // Retry on network errors
      return !!error && operation.operationName !== 'SensitiveOperation';
    },
  },
});

const client = new ApolloClient({
  cache: new InMemoryCache(),
  link: from([retryLink, errorLink, httpLink]),
});
```

### Custom Retry Logic

```typescript
const retryLink = new RetryLink({
  attempts: (count, operation, error) => {
    // Don't retry mutations
    if (operation.query.definitions.some(
      (def) => def.kind === 'OperationDefinition' && def.operation === 'mutation'
    )) {
      return false;
    }

    // Retry up to 3 times on network errors
    return count < 3 && !!error;
  },
  delay: (count) => {
    // Exponential backoff
    return Math.min(1000 * Math.pow(2, count), 30000);
  },
});
```

## Error Boundaries

Integrate with React Error Boundaries for graceful error handling.

### Basic Error Boundary

```tsx
import { Component, ReactNode } from 'react';

interface Props {
  children: ReactNode;
  fallback: ReactNode;
}

interface State {
  hasError: boolean;
}

class ErrorBoundary extends Component<Props, State> {
  state = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('Error caught by boundary:', error, errorInfo);
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback;
    }
    return this.props.children;
  }
}

// Usage
function App() {
  return (
    <ErrorBoundary fallback={<ErrorFallback />}>
      <ApolloProvider client={client}>
        <Router />
      </ApolloProvider>
    </ErrorBoundary>
  );
}
```

### Apollo-Specific Error Boundary

```tsx
import { useQuery } from '@apollo/client';

function QueryErrorBoundary({ children, fallback }: {
  children: ReactNode;
  fallback: (error: ApolloError, retry: () => void) => ReactNode;
}) {
  // This is a simplified example
  // In practice, use react-error-boundary or similar
  return <>{children}</>;
}

// Component with error handling
function UserProfile({ userId }: { userId: string }) {
  const { data, error, loading, refetch } = useQuery(GET_USER, {
    variables: { id: userId },
  });

  if (loading) return <Skeleton />;

  if (error) {
    return (
      <ErrorDisplay
        error={error}
        onRetry={() => refetch()}
      />
    );
  }

  return <Profile user={data.user} />;
}
```

### Per-Component Error Handling

```tsx
function SafeUserList() {
  const { data, error, loading, refetch } = useQuery(GET_USERS, {
    errorPolicy: 'all',
    notifyOnNetworkStatusChange: true,
  });

  // Handle network errors
  if (error?.networkError) {
    return (
      <Alert severity="error">
        <AlertTitle>Connection Error</AlertTitle>
        Failed to load users. Please check your internet connection.
        <Button onClick={() => refetch()}>Retry</Button>
      </Alert>
    );
  }

  // Handle GraphQL errors but still show available data
  return (
    <div>
      {error?.graphQLErrors && (
        <Alert severity="warning">
          Some data may be incomplete: {error.graphQLErrors[0].message}
        </Alert>
      )}

      {loading && <LinearProgress />}

      {data?.users && (
        <UserList users={data.users} />
      )}
    </div>
  );
}
```
