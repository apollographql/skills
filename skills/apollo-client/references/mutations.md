# Mutations Reference

## Table of Contents

- [useMutation Hook](#usemutation-hook)
- [Mutation Variables](#mutation-variables)
- [Loading and Error States](#loading-and-error-states)
- [Optimistic UI](#optimistic-ui)
- [Cache Updates](#cache-updates)
- [Refetch Queries](#refetch-queries)
- [Error Handling](#error-handling)

## useMutation Hook

The `useMutation` hook is used to execute GraphQL mutations.

### Basic Usage

```tsx
import { useMutation, gql } from '@apollo/client';

const ADD_TODO = gql`
  mutation AddTodo($text: String!) {
    addTodo(text: $text) {
      id
      text
      completed
    }
  }
`;

function AddTodo() {
  const [addTodo, { data, loading, error }] = useMutation(ADD_TODO);

  return (
    <form
      onSubmit={(e) => {
        e.preventDefault();
        const form = e.currentTarget;
        const text = new FormData(form).get('text') as string;
        addTodo({ variables: { text } });
        form.reset();
      }}
    >
      <input name="text" placeholder="Add todo" />
      <button type="submit" disabled={loading}>Add</button>
      {error && <p>Error: {error.message}</p>}
    </form>
  );
}
```

### Return Tuple

```typescript
const [
  mutateFunction, // Function to call to execute mutation
  {
    data,         // Mutation result data
    loading,      // True while mutation is in flight
    error,        // ApolloError if mutation failed
    called,       // True if mutation has been called
    reset,        // Reset mutation state
    client,       // Apollo Client instance
  },
] = useMutation(MUTATION);
```

## Mutation Variables

### Variables in Options

```tsx
const [createUser] = useMutation(CREATE_USER, {
  variables: {
    input: {
      name: 'Default User',
      email: 'default@example.com',
    },
  },
});

// Call with default variables
await createUser();

// Override variables
await createUser({
  variables: {
    input: {
      name: 'Custom User',
      email: 'custom@example.com',
    },
  },
});
```

### TypeScript Types

```typescript
interface CreateUserData {
  createUser: {
    id: string;
    name: string;
    email: string;
  };
}

interface CreateUserVariables {
  input: {
    name: string;
    email: string;
  };
}

const [createUser] = useMutation<CreateUserData, CreateUserVariables>(
  CREATE_USER
);

const { data } = await createUser({
  variables: {
    input: { name: 'John', email: 'john@example.com' },
  },
});

// data.createUser is fully typed
```

## Loading and Error States

### Handling in UI

```tsx
function CreatePost() {
  const [createPost, { loading, error, data, reset }] = useMutation(CREATE_POST);

  if (data) {
    return (
      <div>
        <p>Post created: {data.createPost.title}</p>
        <button onClick={reset}>Create another</button>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit}>
      <input name="title" disabled={loading} />
      <textarea name="content" disabled={loading} />
      <button type="submit" disabled={loading}>
        {loading ? 'Creating...' : 'Create Post'}
      </button>
      {error && (
        <div className="error">
          <p>Failed to create post: {error.message}</p>
          <button onClick={reset}>Try again</button>
        </div>
      )}
    </form>
  );
}
```

### Async/Await Pattern

```tsx
async function handleSubmit(formData: FormData) {
  try {
    const { data } = await createPost({
      variables: {
        input: {
          title: formData.get('title'),
          content: formData.get('content'),
        },
      },
    });
    console.log('Created:', data.createPost);
    router.push(`/posts/${data.createPost.id}`);
  } catch (error) {
    console.error('Failed to create post:', error);
    // Error is also available in mutation result
  }
}
```

## Optimistic UI

Optimistic UI immediately reflects the expected result of a mutation before the server responds.

### Basic Optimistic Response

```tsx
const [addTodo] = useMutation(ADD_TODO, {
  optimisticResponse: {
    addTodo: {
      __typename: 'Todo',
      id: 'temp-id',
      text: 'New todo',
      completed: false,
    },
  },
});
```

### Dynamic Optimistic Response

```tsx
function TodoList() {
  const [addTodo] = useMutation(ADD_TODO);

  const handleAdd = (text: string) => {
    addTodo({
      variables: { text },
      optimisticResponse: {
        addTodo: {
          __typename: 'Todo',
          id: `temp-${Date.now()}`,
          text,
          completed: false,
        },
      },
    });
  };

  return <AddTodoForm onAdd={handleAdd} />;
}
```

### Optimistic Response with Cache Update

```tsx
const [toggleTodo] = useMutation(TOGGLE_TODO, {
  optimisticResponse: ({ id }) => ({
    toggleTodo: {
      __typename: 'Todo',
      id,
      completed: true, // Assume success
    },
  }),
  update: (cache, { data }) => {
    // This runs twice: once with optimistic data, once with server data
    cache.modify({
      id: cache.identify(data.toggleTodo),
      fields: {
        completed: () => data.toggleTodo.completed,
      },
    });
  },
});
```

## Cache Updates

### Using update Function

```tsx
const [addTodo] = useMutation(ADD_TODO, {
  update: (cache, { data }) => {
    // Read existing todos from cache
    const existingTodos = cache.readQuery<{ todos: Todo[] }>({
      query: GET_TODOS,
    });

    // Write updated list back to cache
    cache.writeQuery({
      query: GET_TODOS,
      data: {
        todos: [...(existingTodos?.todos ?? []), data.addTodo],
      },
    });
  },
});
```

### cache.modify

```tsx
const [deleteTodo] = useMutation(DELETE_TODO, {
  update: (cache, { data }) => {
    cache.modify({
      fields: {
        todos: (existingTodos: Reference[], { readField }) => {
          return existingTodos.filter(
            (todoRef) => readField('id', todoRef) !== data.deleteTodo.id
          );
        },
      },
    });
  },
});
```

### cache.evict

```tsx
const [deleteUser] = useMutation(DELETE_USER, {
  update: (cache, { data }) => {
    // Remove the user object from cache entirely
    cache.evict({ id: cache.identify(data.deleteUser) });
    // Clean up dangling references
    cache.gc();
  },
});
```

### Updating Related Queries

```tsx
const [createPost] = useMutation(CREATE_POST, {
  update: (cache, { data }) => {
    // Update author's post count
    cache.modify({
      id: cache.identify({ __typename: 'User', id: data.createPost.authorId }),
      fields: {
        postCount: (existing) => existing + 1,
        posts: (existing, { toReference }) => [
          ...existing,
          toReference(data.createPost),
        ],
      },
    });

    // Add to feed
    cache.modify({
      fields: {
        feed: (existing, { toReference }) => [
          toReference(data.createPost),
          ...existing,
        ],
      },
    });
  },
});
```

## Refetch Queries

### Basic Refetch

```tsx
const [addTodo] = useMutation(ADD_TODO, {
  refetchQueries: [
    { query: GET_TODOS },
    { query: GET_TODO_COUNT },
  ],
});
```

### Conditional Refetch

```tsx
const [addTodo] = useMutation(ADD_TODO, {
  refetchQueries: (result) => {
    if (result.data?.addTodo.priority === 'HIGH') {
      return [{ query: GET_HIGH_PRIORITY_TODOS }];
    }
    return [{ query: GET_TODOS }];
  },
});
```

### Refetch Active Queries

```tsx
const [addTodo] = useMutation(ADD_TODO, {
  refetchQueries: 'active', // Refetch all active queries
  // Or: 'all' to refetch all queries (including inactive)
});
```

### awaitRefetchQueries

```tsx
const [addTodo] = useMutation(ADD_TODO, {
  refetchQueries: [{ query: GET_TODOS }],
  awaitRefetchQueries: true, // Wait for refetch before resolving mutation
});
```

### onQueryUpdated

```tsx
const [addTodo] = useMutation(ADD_TODO, {
  update: (cache, { data }) => {
    // Update cache...
  },
  onQueryUpdated: (observableQuery) => {
    // Called for each query affected by cache update
    console.log(`Query ${observableQuery.queryName} was updated`);
    return observableQuery.refetch(); // Optionally refetch
  },
});
```

## Error Handling

### Error Policy

```tsx
const [createUser] = useMutation(CREATE_USER, {
  errorPolicy: 'all', // Return both data and errors
});

const { data, errors } = await createUser({
  variables: { input },
});

// Handle partial success
if (data?.createUser) {
  console.log('User created:', data.createUser);
}
if (errors) {
  console.warn('Some errors occurred:', errors);
}
```

### onError Callback

```tsx
const [createUser] = useMutation(CREATE_USER, {
  onError: (error) => {
    // Handle error globally
    toast.error(`Failed to create user: ${error.message}`);

    // Log to error tracking service
    Sentry.captureException(error);
  },
  onCompleted: (data) => {
    toast.success(`User ${data.createUser.name} created!`);
  },
});
```

### Field-Level Errors

```tsx
const [createUser] = useMutation(CREATE_USER, {
  errorPolicy: 'all',
});

const handleSubmit = async (input: CreateUserInput) => {
  const { data, errors } = await createUser({
    variables: { input },
  });

  // Handle GraphQL validation errors
  const fieldErrors = errors?.reduce((acc, error) => {
    const field = error.extensions?.field as string;
    if (field) {
      acc[field] = error.message;
    }
    return acc;
  }, {} as Record<string, string>);

  if (fieldErrors?.email) {
    setEmailError(fieldErrors.email);
  }
};
```
