# Suspense Hooks Reference

> **Note**: Suspense hooks are the recommended approach for data fetching in modern React applications (React 18+). They provide cleaner code, better loading state handling, and enable streaming SSR.

## Table of Contents

- [useSuspenseQuery Hook](#usesuspensequery-hook)
- [useBackgroundQuery and useReadQuery](#usebackgroundquery-and-usereadquery)
- [useLoadableQuery](#useloadablequery)
- [Suspense Boundaries and Error Handling](#suspense-boundaries-and-error-handling)
- [Transitions](#transitions)
- [Avoiding Request Waterfalls](#avoiding-request-waterfalls)
- [Fragment Hooks](#fragment-hooks)
- [Fetch Policies](#fetch-policies)
- [Conditional Queries](#conditional-queries)

## useSuspenseQuery Hook

The `useSuspenseQuery` hook is the Suspense-ready replacement for `useQuery`. It initiates a network request and causes the component calling it to suspend while the request is made. Unlike `useQuery`, it does not return `loading` or `error` states—these are handled by React's Suspense boundaries and error boundaries.

### Basic Usage

```tsx
import { Suspense } from 'react';
import { gql, TypedDocumentNode } from '@apollo/client';
import { useSuspenseQuery } from '@apollo/client/react';

interface DogData {
  dog: {
    id: string;
    name: string;
    breed: string;
  };
}

interface DogVariables {
  id: string;
}

const GET_DOG: TypedDocumentNode<DogData, DogVariables> = gql`
  query GetDog($id: String!) {
    dog(id: $id) {
      id
      name
      breed
    }
  }
`;

function App() {
  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Dog id="3" />
    </Suspense>
  );
}

function Dog({ id }: { id: string }) {
  const { data } = useSuspenseQuery(GET_DOG, {
    variables: { id },
  });

  // data is always defined when this component renders
  return <div>Name: {data.dog.name}</div>;
}
```

### Return Object

```typescript
const {
  data,           // Query result data (always defined)
  dataState,      // "complete" | "streaming" | "partial" | "empty"
  error,          // ApolloError (if errorPolicy allows)
  networkStatus,  // Detailed network state (1-8)
  client,         // Apollo Client instance
  refetch,        // Function to re-execute query
  fetchMore,      // Function for pagination
} = useSuspenseQuery(QUERY, options);
```

### Key Differences from useQuery

- **No `loading` boolean**: Component suspends instead of returning `loading: true`
- **`data` always defined**: When the component renders, `data` is guaranteed to be present
- **No inline error handling**: Errors are caught by error boundaries, not returned in the hook result (unless using a custom `errorPolicy`)
- **Suspense boundaries**: Must wrap component with `<Suspense>` to handle loading state

### Changing Variables

When variables change, `useSuspenseQuery` automatically re-runs the query. If the data is not in the cache, the component suspends again.

```tsx
function DogSelector() {
  const { data } = useSuspenseQuery(GET_DOGS);
  const [selectedDog, setSelectedDog] = useState(data.dogs[0].id);

  return (
    <>
      <select value={selectedDog} onChange={(e) => setSelectedDog(e.target.value)}>
        {data.dogs.map((dog) => (
          <option key={dog.id} value={dog.id}>
            {dog.name}
          </option>
        ))}
      </select>
      <Suspense fallback={<div>Loading...</div>}>
        <Dog id={selectedDog} />
      </Suspense>
    </>
  );
}

function Dog({ id }: { id: string }) {
  const { data } = useSuspenseQuery(GET_DOG, {
    variables: { id },
  });

  return (
    <>
      <div>Name: {data.dog.name}</div>
      <div>Breed: {data.dog.breed}</div>
    </>
  );
}
```

### Rendering Partial Data

Use `returnPartialData` to render immediately with partial cache data instead of suspending.

```tsx
function Dog({ id }: { id: string }) {
  const { data } = useSuspenseQuery(GET_DOG, {
    variables: { id },
    returnPartialData: true,
  });

  return (
    <>
      <div>Name: {data.dog.name}</div>
      {data.dog.breed && <div>Breed: {data.dog.breed}</div>}
    </>
  );
}
```

## useBackgroundQuery and useReadQuery

Use `useBackgroundQuery` with `useReadQuery` to avoid request waterfalls by starting a query in a parent component and reading the result in a child component. This pattern enables the parent to start fetching data before the child component renders.

### Basic Usage

```tsx
import { Suspense } from 'react';
import { useBackgroundQuery, useReadQuery } from '@apollo/client/react';

function Parent() {
  // Start fetching immediately
  const [queryRef] = useBackgroundQuery(GET_DOG, {
    variables: { id: '3' },
  });

  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Child queryRef={queryRef} />
    </Suspense>
  );
}

function Child({ queryRef }: { queryRef: QueryRef<DogData> }) {
  // Read the query result
  const { data } = useReadQuery(queryRef);

  return <div>Name: {data.dog.name}</div>;
}
```

### When to Use

- **Avoiding waterfalls**: Start fetching data in a parent before child components render
- **Preloading data**: Begin fetching before the component that needs the data is ready
- **Parallel queries**: Start multiple queries at once in a parent component

### Return Values

`useBackgroundQuery` returns a tuple:

```typescript
const [
  queryRef,     // QueryRef to pass to useReadQuery
  { refetch, fetchMore, subscribeToMore }  // Helper functions
] = useBackgroundQuery(QUERY, options);
```

`useReadQuery` returns the query result:

```typescript
const {
  data,           // Query result data (always defined)
  dataState,      // "complete" | "streaming" | "partial" | "empty"
  error,          // ApolloError (if errorPolicy allows)
  networkStatus,  // Detailed network state (1-8)
} = useReadQuery(queryRef);
```

## useLoadableQuery

Use `useLoadableQuery` to imperatively load a query in response to a user interaction (like a button click) rather than on component mount.

### Basic Usage

```tsx
import { Suspense } from 'react';
import { useLoadableQuery, useReadQuery } from '@apollo/client/react';

const GET_GREETING = gql`
  query GetGreeting($language: String!) {
    greeting(language: $language) {
      message
    }
  }
`;

function App() {
  const [loadGreeting, queryRef] = useLoadableQuery(GET_GREETING);

  return (
    <>
      <button onClick={() => loadGreeting({ variables: { language: 'english' } })}>
        Load Greeting
      </button>
      <Suspense fallback={<div>Loading...</div>}>
        {queryRef && <Greeting queryRef={queryRef} />}
      </Suspense>
    </>
  );
}

function Greeting({ queryRef }: { queryRef: QueryRef<GreetingData> }) {
  const { data } = useReadQuery(queryRef);

  return <div>{data.greeting.message}</div>;
}
```

### Return Values

```typescript
const [
  loadQuery,      // Function to load the query
  queryRef,       // QueryRef (null until loadQuery is called)
  { refetch, fetchMore, subscribeToMore, reset }  // Helper functions
] = useLoadableQuery(QUERY, options);
```

### When to Use

- **User-triggered fetching**: Load data in response to user actions
- **Lazy loading**: Defer data fetching until it's actually needed
- **Progressive disclosure**: Load data for UI elements that may not be initially visible

## Suspense Boundaries and Error Handling

### Suspense Boundaries

Wrap components that use Suspense hooks with `<Suspense>` boundaries to handle loading states. Place boundaries strategically to control the granularity of loading indicators.

```tsx
function App() {
  return (
    <>
      {/* Top-level loading for entire page */}
      <Suspense fallback={<PageSpinner />}>
        <Header />
        <Content />
      </Suspense>
    </>
  );
}

function Content() {
  return (
    <>
      <MainSection />
      {/* Granular loading for sidebar */}
      <Suspense fallback={<SidebarSkeleton />}>
        <Sidebar />
      </Suspense>
    </>
  );
}
```

### Error Boundaries

Suspense hooks throw errors to React error boundaries instead of returning them. Use error boundaries to handle GraphQL errors.

```tsx
import { ErrorBoundary } from 'react-error-boundary';

function App() {
  return (
    <ErrorBoundary
      fallback={({ error }) => (
        <div>
          <h2>Something went wrong</h2>
          <p>{error.message}</p>
        </div>
      )}
    >
      <Suspense fallback={<div>Loading...</div>}>
        <Dog id="3" />
      </Suspense>
    </ErrorBoundary>
  );
}
```

### Custom Error Policies

Use `errorPolicy` to control how errors are handled:

```tsx
function Dog({ id }: { id: string }) {
  const { data, error } = useSuspenseQuery(GET_DOG, {
    variables: { id },
    errorPolicy: 'all', // Return both data and errors
  });

  return (
    <>
      <div>Name: {data?.dog?.name ?? 'Unknown'}</div>
      {error && <div>Warning: {error.message}</div>}
    </>
  );
}
```

## Transitions

Use React transitions to avoid showing loading UI when updating state. Transitions keep the previous UI visible while new data is fetching.

### Using startTransition

```tsx
import { useState, Suspense, startTransition } from 'react';

function DogSelector() {
  const { data } = useSuspenseQuery(GET_DOGS);
  const [selectedDog, setSelectedDog] = useState(data.dogs[0].id);

  return (
    <>
      <select
        value={selectedDog}
        onChange={(e) => {
          // Wrap state update in startTransition
          startTransition(() => {
            setSelectedDog(e.target.value);
          });
        }}
      >
        {data.dogs.map((dog) => (
          <option key={dog.id} value={dog.id}>
            {dog.name}
          </option>
        ))}
      </select>
      <Suspense fallback={<div>Loading...</div>}>
        <Dog id={selectedDog} />
      </Suspense>
    </>
  );
}
```

### Using useTransition

Use `useTransition` to get an `isPending` flag for visual feedback during transitions.

```tsx
import { useState, Suspense, useTransition } from 'react';

function DogSelector() {
  const [isPending, startTransition] = useTransition();
  const { data } = useSuspenseQuery(GET_DOGS);
  const [selectedDog, setSelectedDog] = useState(data.dogs[0].id);

  return (
    <>
      <select
        style={{ opacity: isPending ? 0.5 : 1 }}
        value={selectedDog}
        onChange={(e) => {
          startTransition(() => {
            setSelectedDog(e.target.value);
          });
        }}
      >
        {data.dogs.map((dog) => (
          <option key={dog.id} value={dog.id}>
            {dog.name}
          </option>
        ))}
      </select>
      <Suspense fallback={<div>Loading...</div>}>
        <Dog id={selectedDog} />
      </Suspense>
    </>
  );
}
```

## Avoiding Request Waterfalls

Request waterfalls occur when a child component waits for the parent to finish rendering before it can start fetching its own data. Use `useBackgroundQuery` to avoid this.

### Problem: Waterfall Pattern

```tsx
// ❌ Bad: Child can't start fetching until Parent finishes
function Parent() {
  const { data } = useSuspenseQuery(GET_DOGS);

  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Child dogId={data.dogs[0].id} />
    </Suspense>
  );
}

function Child({ dogId }: { dogId: string }) {
  // This query can't start until Parent's query completes
  const { data } = useSuspenseQuery(GET_DOG_DETAILS, {
    variables: { id: dogId },
  });

  return <div>{data.dog.breed}</div>;
}
```

### Solution: Start Queries in Parallel

```tsx
// ✅ Good: Both queries start immediately
function Parent() {
  const { data } = useSuspenseQuery(GET_DOGS);
  const [dogDetailsRef] = useBackgroundQuery(GET_DOG_DETAILS, {
    variables: { id: data.dogs[0].id },
  });

  return (
    <Suspense fallback={<div>Loading...</div>}>
      <Child queryRef={dogDetailsRef} />
    </Suspense>
  );
}

function Child({ queryRef }: { queryRef: QueryRef<DogDetailsData> }) {
  const { data } = useReadQuery(queryRef);

  return <div>{data.dog.breed}</div>;
}
```

## Fragment Hooks

Use fragment hooks (`useFragment` and `useSuspenseFragment`) to read fragment data in child components. This enables proper component colocation and data masking.

### useFragment

`useFragment` reads fragment data from the cache without suspending. Use it for non-Suspense applications or when you want to read cached data without triggering loading states.

```tsx
import { gql } from '@apollo/client';
import { useFragment } from '@apollo/client/react';

const DOG_FRAGMENT = gql`
  fragment DogInfo on Dog {
    id
    name
    breed
  }
`;

function DogCard({ id }: { id: string }) {
  const { data, complete } = useFragment({
    fragment: DOG_FRAGMENT,
    from: {
      __typename: 'Dog',
      id,
    },
  });

  if (!complete) {
    return <div>Loading...</div>;
  }

  return (
    <div>
      <h3>{data.name}</h3>
      <p>{data.breed}</p>
    </div>
  );
}
```

### Component Colocation with Fragments

```tsx
// Parent component fetches complete query
const GET_DOGS = gql`
  query GetDogs {
    dogs {
      id
      ...DogInfo
    }
  }
  ${DOG_FRAGMENT}
`;

function DogList() {
  const { data } = useSuspenseQuery(GET_DOGS);

  return (
    <ul>
      {data.dogs.map((dog) => (
        <li key={dog.id}>
          <DogCard id={dog.id} />
        </li>
      ))}
    </ul>
  );
}

// Child component uses fragment
function DogCard({ id }: { id: string }) {
  const { data } = useFragment({
    fragment: DOG_FRAGMENT,
    from: { __typename: 'Dog', id },
  });

  return (
    <div>
      <h3>{data.name}</h3>
      <p>{data.breed}</p>
    </div>
  );
}
```

## Fetch Policies

Suspense hooks support the same fetch policies as `useQuery`, controlling how the query interacts with the cache.

| Policy | Description |
|--------|-------------|
| `cache-first` | Return cached data if available, otherwise fetch (default) |
| `cache-only` | Only return cached data, never fetch (not supported by `useSuspenseQuery`) |
| `cache-and-network` | Return cached data immediately, then fetch and update |
| `network-only` | Always fetch, update cache, ignore cached data |
| `no-cache` | Always fetch, never read or write cache |

### Usage Examples

```tsx
// Always fetch fresh data
const { data } = useSuspenseQuery(GET_NOTIFICATIONS, {
  fetchPolicy: 'network-only',
});

// Prefer cached data
const { data } = useSuspenseQuery(GET_CATEGORIES, {
  fetchPolicy: 'cache-first',
});

// Show cached data while fetching fresh data
const { data } = useSuspenseQuery(GET_POSTS, {
  fetchPolicy: 'cache-and-network',
});
```

## Conditional Queries

### Using skipToken

Use `skipToken` to conditionally skip queries without TypeScript issues:

```tsx
import { skipToken } from '@apollo/client';

function UserProfile({ userId }: { userId: string | null }) {
  const { data } = useSuspenseQuery(
    GET_USER,
    !userId ? skipToken : {
      variables: { id: userId },
    }
  );

  return userId ? <Profile user={data?.user} /> : <p>Select a user</p>;
}
```

### Conditional Rendering

Alternatively, use conditional rendering to control when Suspense hooks are called:

```tsx
function UserProfile({ userId }: { userId: string | null }) {
  if (!userId) {
    return <p>Select a user</p>;
  }

  return (
    <Suspense fallback={<div>Loading...</div>}>
      <UserDetails userId={userId} />
    </Suspense>
  );
}

function UserDetails({ userId }: { userId: string }) {
  const { data } = useSuspenseQuery(GET_USER, {
    variables: { id: userId },
  });

  return <Profile user={data.user} />;
}
```

### SSR Considerations

For server-side rendering, you may need to skip certain queries:

```tsx
const { data } = useSuspenseQuery(GET_USER_LOCATION, {
  skip: typeof window === 'undefined',
});
```

> **Note**: Using `skipToken` is preferred over `skip` as it provides better type safety and avoids issues with required variables.
