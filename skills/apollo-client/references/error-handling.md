# Error Handling Reference (Apollo Client 4.x)

Apollo Client 4.x introduces significant improvements to error handling with specific error classes and more precise typing.

## Table of Contents

- [Understanding Errors](#understanding-errors)
- [Error Types](#error-types)
- [Identifying Error Types](#identifying-error-types)
- [GraphQL Error Policies](#graphql-error-policies)
- [Error Links](#error-links)
- [Retry Logic](#retry-logic)
- [Error Boundaries](#error-boundaries)

## Understanding Errors

Errors in Apollo Client fall into two main categories: **GraphQL errors** and **network errors**. Each category has specific error classes that provide detailed information about what went wrong.

### GraphQL Errors

GraphQL errors are related to server-side execution of a GraphQL operation:

- **Syntax errors** (e.g., malformed query)
- **Validation errors** (e.g., query includes a non-existent schema field)
- **Resolver errors** (e.g., error while populating a query field)

If a syntax or validation error occurs, the server doesn't execute the operation. If resolver errors occur, the server can still return partial data.

Example server response with GraphQL error:

```json
{
  "errors": [
    {
      "message": "Cannot query field \"nonexistentField\" on type \"Query\".",
      "locations": [{ "line": 2, "column": 3 }],
      "extensions": {
        "code": "GRAPHQL_VALIDATION_FAILED"
      }
    }
  ],
  "data": null
}
```

In Apollo Client 4.x, GraphQL errors are represented by the [`CombinedGraphQLErrors`](https://apollographql.com/docs/react/api/errors/CombinedGraphQLErrors) error type.

### Network Errors

Network errors occur when attempting to communicate with your GraphQL server:

- `4xx` or `5xx` HTTP response status codes
- Network unavailability
- JSON parsing failures
- Custom errors from Apollo Link request handlers

## Error Types

Apollo Client 4.x provides specific error classes for different error scenarios:

### CombinedGraphQLErrors

Represents GraphQL errors returned by the server. Most common error type in applications.

```tsx
import { CombinedGraphQLErrors } from '@apollo/client/errors';

function UserProfile({ userId }: { userId: string }) {
  const { data, error } = useQuery(GET_USER, {
    variables: { id: userId },
  });

  if (error && CombinedGraphQLErrors.is(error)) {
    // Handle GraphQL errors
    return (
      <div>
        {error.graphQLErrors.map((err, i) => (
          <p key={i}>GraphQL Error: {err.message}</p>
        ))}
      </div>
    );
  }

  return data ? <Profile user={data.user} /> : null;
}
```

### CombinedProtocolErrors

Represents fatal transport-level errors during multipart HTTP subscription execution.

### ServerError

Occurs when the server responds with a non-200 HTTP status code.

```tsx
import { ServerError } from '@apollo/client/errors';

if (error && ServerError.is(error)) {
  console.error('Server error:', error.statusCode, error.result);
}
```

### ServerParseError

Occurs when the server response cannot be parsed as valid JSON.

```tsx
import { ServerParseError } from '@apollo/client/errors';

if (error && ServerParseError.is(error)) {
  console.error('Invalid JSON response:', error.bodyText);
}
```

### LocalStateError

Represents errors in local state configuration or execution.

### UnconventionalError

Wraps non-standard errors (e.g., thrown symbols or objects) to ensure consistent error handling.

## Identifying Error Types

Every Apollo Client error class provides a static `is` method that reliably determines whether an error is of that specific type. This is more robust than `instanceof` because it avoids false positives/negatives.

```ts
import {
  CombinedGraphQLErrors,
  CombinedProtocolErrors,
  LocalStateError,
  ServerError,
  ServerParseError,
  UnconventionalError,
} from '@apollo/client/errors';

function handleError(error: unknown) {
  if (CombinedGraphQLErrors.is(error)) {
    // Handle GraphQL errors
    console.error('GraphQL errors:', error.graphQLErrors);
  } else if (CombinedProtocolErrors.is(error)) {
    // Handle multipart subscription protocol errors
  } else if (LocalStateError.is(error)) {
    // Handle errors thrown by the LocalState class
  } else if (ServerError.is(error)) {
    // Handle server HTTP errors
    console.error('Server error:', error.statusCode);
  } else if (ServerParseError.is(error)) {
    // Handle JSON parse errors
  } else if (UnconventionalError.is(error)) {
    // Handle errors thrown by irregular types
  } else {
    // Handle other errors
  }
}
```

## GraphQL Error Policies

If a GraphQL operation produces errors, the server's response might still include partial data:

```json
{
  "data": {
    "getInt": 12,
    "getString": null
  },
  "errors": [
    {
      "message": "Failed to get string!"
    }
  ]
}
```

By default, Apollo Client throws away partial data and populates the `error` field. You can use partial results by defining an **error policy**:

| Policy   | Description                                                                                                                                                                           |
| -------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `none`   | (Default) If the response includes errors, they are returned in `error` and response `data` is set to `undefined` even if the server returns `data`.                                 |
| `ignore` | Errors are ignored (`error` is not populated), and any returned `data` is cached and rendered as if no errors occurred. `data` may be `undefined` if a network error occurs.          |
| `all`    | Both `data` and `error` are populated and any returned `data` is cached, enabling you to render both partial results and error information.                                          |

### Setting an Error Policy

```tsx
const MY_QUERY = gql`
  query WillFail {
    badField  # This field's resolver produces an error
    goodField # This field is populated successfully
  }
`;

function ShowingSomeErrors() {
  const { loading, error, data } = useQuery(MY_QUERY, { errorPolicy: 'all' });

  if (loading) return <span>loading...</span>;

  return (
    <div>
      <h2>Good: {data?.goodField}</h2>
      {error && <pre>Bad: {error.message}</pre>}
    </div>
  );
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

Use the `onError` link to handle errors globally across your application.

### Basic Error Link

```typescript
import { onError } from '@apollo/client/link/error';
import { ApolloLink } from '@apollo/client';

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
    console.error(`[Network error]:`, networkError);
  }
});
```

### Composing Links

```typescript
import { ApolloClient, InMemoryCache, ApolloLink } from '@apollo/client';
import { HttpLink } from '@apollo/client/link/http';
import { onError } from '@apollo/client/link/error';

const httpLink = new HttpLink({
  uri: '/graphql',
});

const errorLink = onError(({ graphQLErrors, networkError }) => {
  // Error handling...
});

const client = new ApolloClient({
  cache: new InMemoryCache(),
  link: ApolloLink.from([errorLink, httpLink]),
});
```

### Retrying Operations with Error Link

```typescript
import { onError } from '@apollo/client/link/error';
import { Observable } from 'rxjs';

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
