# State Management Reference

## Table of Contents

- [Reactive Variables](#reactive-variables)
- [Local-Only Fields](#local-only-fields)
- [Type Policies for Local State](#type-policies-for-local-state)
- [Combining Remote and Local State](#combining-remote-and-local-state)
- [useReactiveVar Hook](#usereactivevar-hook)

## Reactive Variables

Reactive variables are a way to store local state outside of the Apollo Client cache while still triggering reactive updates.

**Important**: Reactive variables are still variables storing a value. They only notify `ApolloClient` instances when the variable changes, but they do not have one separate value per ApolloClient instance. In a multi-user environment like during SSR, global or module-level reactive variables could be shared between users and cause data leaks. In frameworks that use SSR, always avoid storing reactive variables as globals.

### Creating Reactive Variables

```typescript
import { makeVar } from '@apollo/client';

// Simple reactive variable
export const isLoggedInVar = makeVar<boolean>(false);

// Object reactive variable
export const cartItemsVar = makeVar<CartItem[]>([]);

// Complex state
interface AppState {
  theme: 'light' | 'dark';
  sidebarOpen: boolean;
  notifications: Notification[];
}

export const appStateVar = makeVar<AppState>({
  theme: 'light',
  sidebarOpen: true,
  notifications: [],
});
```

### Reading Reactive Variables

```typescript
// Direct read (non-reactive)
const isLoggedIn = isLoggedInVar();

// Reactive read in component
import { useReactiveVar } from '@apollo/client';

function AuthButton() {
  const isLoggedIn = useReactiveVar(isLoggedInVar);

  return isLoggedIn ? (
    <button onClick={() => isLoggedInVar(false)}>Logout</button>
  ) : (
    <button onClick={() => isLoggedInVar(true)}>Login</button>
  );
}
```

### Updating Reactive Variables

```typescript
// Set new value
isLoggedInVar(true);

// Update based on current value
cartItemsVar([...cartItemsVar(), newItem]);

// Update object state
appStateVar({
  ...appStateVar(),
  theme: 'dark',
});

// Helper function pattern
export function toggleSidebar() {
  const current = appStateVar();
  appStateVar({ ...current, sidebarOpen: !current.sidebarOpen });
}

export function addNotification(notification: Notification) {
  const current = appStateVar();
  appStateVar({
    ...current,
    notifications: [...current.notifications, notification],
  });
}
```

## Local-Only Fields

Local-only fields are fields defined in queries but resolved entirely on the client using the `@client` directive.

**Important**: To use any `@client` fields, you need to add `LocalState` to the `ApolloClient` initialization:

```typescript
import { ApolloClient, InMemoryCache } from '@apollo/client';
import { LocalState } from '@apollo/client/local-state';

const client = new ApolloClient({
  cache: new InMemoryCache(),
  localState: new LocalState({}),
  // ... other options
});
```

### Basic @client Fields

```tsx
const GET_USER_WITH_LOCAL = gql`
  query GetUserWithLocal($id: ID!) {
    user(id: $id) {
      id
      name
      email
      # Local-only fields
      isSelected @client
      displayName @client
    }
  }
`;

function UserCard({ userId }: { userId: string }) {
  const { data } = useQuery(GET_USER_WITH_LOCAL, {
    variables: { id: userId },
  });

  return (
    <div className={data?.user.isSelected ? 'selected' : ''}>
      <h2>{data?.user.displayName}</h2>
      <p>{data?.user.email}</p>
    </div>
  );
}
```

### Defining Local Field Resolvers

Local field resolvers are defined in entity-level type policies (different from query-level `@client` resolvers):

```typescript
const cache = new InMemoryCache({
  typePolicies: {
    User: {
      fields: {
        // Simple local field from reactive variable
        isSelected: {
          read(_, { readField }) {
            const id = readField('id');
            return selectedUsersVar().includes(id);
          },
        },

        // Computed local field
        displayName: {
          read(_, { readField }) {
            const name = readField('name');
            const email = readField('email');
            return name || email?.split('@')[0] || 'Anonymous';
          },
        },
      },
    },
  },
});
```

## Type Policies for Local State

### Query-Level Local Fields

Query-level local fields can be defined using `LocalState` resolvers:

```typescript
import { LocalState } from '@apollo/client/local-state';

const client = new ApolloClient({
  cache: new InMemoryCache(),
  localState: new LocalState({
    resolvers: {
      Query: {
        isLoggedIn: () => isLoggedInVar(),
        cartItems: () => cartItemsVar(),
        notification: (_, { id }) => notificationsVar().find((n) => n.id === id),
        currentUser: (_, __, { cache }) => {
          const userId = currentUserIdVar();
          if (!userId) return null;
          return cache.readFragment({
            id: cache.identify({ __typename: 'User', id: userId }),
            fragment: gql`fragment CurrentUser on User { id name email }`,
          });
        },
      },
    },
  }),
});
```

### Using Local Query Fields

```tsx
const GET_AUTH_STATE = gql`
  query GetAuthState {
    isLoggedIn @client
    currentUser @client {
      id
      name
      email
    }
  }
`;

function AuthStatus() {
  const { data } = useQuery(GET_AUTH_STATE);

  if (!data?.isLoggedIn) {
    return <LoginButton />;
  }

  return <UserMenu user={data.currentUser} />;
}
```

## Combining Remote and Local State

### Mixing Remote and Local Fields

```tsx
const GET_PRODUCTS = gql`
  query GetProducts {
    products {
      id
      name
      price
      # Local fields
      quantity @client
      isInCart @client
    }
  }
`;

const cache = new InMemoryCache({
  typePolicies: {
    Product: {
      fields: {
        quantity: {
          read(_, { readField }) {
            const id = readField('id');
            const cartItem = cartItemsVar().find((item) => item.productId === id);
            return cartItem?.quantity ?? 0;
          },
        },

        isInCart: {
          read(_, { readField }) {
            const id = readField('id');
            return cartItemsVar().some((item) => item.productId === id);
          },
        },
      },
    },
  },
});
```

### Local Mutations

Define local mutation resolvers using `LocalState`:

```tsx
import { LocalState } from '@apollo/client/local-state';

const client = new ApolloClient({
  cache: new InMemoryCache(),
  localState: new LocalState({
    resolvers: {
      Mutation: {
        addToCart: (_, { productId, quantity }) => {
          const current = cartItemsVar();
          const existing = current.find((item) => item.productId === productId);

          if (existing) {
            cartItemsVar(
              current.map((item) =>
                item.productId === productId
                  ? { ...item, quantity: item.quantity + quantity }
                  : item
              )
            );
          } else {
            cartItemsVar([...current, { productId, quantity }]);
          }
          return true;
        },
      },
    },
  }),
});

const ADD_TO_CART = gql`
  mutation AddToCart($productId: ID!, $quantity: Int!) {
    addToCart(productId: $productId, quantity: $quantity) @client
  }
`;

// Better approach: Use reactive variable directly with a custom hook
function useAddToCart() {
  return (productId: string, quantity: number) => {
    const current = cartItemsVar();
    const existing = current.find((item) => item.productId === productId);

    if (existing) {
      cartItemsVar(
        current.map((item) =>
          item.productId === productId
            ? { ...item, quantity: item.quantity + quantity }
            : item
        )
      );
    } else {
      cartItemsVar([...current, { productId, quantity }]);
    }
  };
}
```

### Persisting Local State

```typescript
// Save to localStorage when reactive variable changes
const cartItemsVar = makeVar<CartItem[]>(
  JSON.parse(localStorage.getItem('cart') || '[]')
);

// Create a wrapper that persists
export function updateCart(items: CartItem[]) {
  cartItemsVar(items);
  localStorage.setItem('cart', JSON.stringify(items));
}

// Use a listener on the reactive variable for automatic persistence
// This requires careful implementation to avoid memory leaks
function subscribeToVariable<T>(
  weakRef: WeakRef<ReactiveVar<T>>,
  callback: (value: T) => void
) {
  const reactiveVar = weakRef.deref();
  if (!reactiveVar) return;
  
  const onNextChange = reactiveVar.onNextChange(() => {
    const currentVar = weakRef.deref();
    if (currentVar) {
      callback(currentVar());
      onNextChange();
    }
  });
}

// Create reactive variable with persistence
const cartItemsVar = makeVar<CartItem[]>(
  JSON.parse(localStorage.getItem('cart') || '[]')
);

subscribeToVariable(
  new WeakRef(cartItemsVar),
  (items) => localStorage.setItem('cart', JSON.stringify(items))
);
```

## useReactiveVar Hook

The `useReactiveVar` hook subscribes a component to reactive variable updates.

### Basic Usage

```tsx
import { useReactiveVar } from '@apollo/client';

function ThemeToggle() {
  const theme = useReactiveVar(themeVar);

  return (
    <button
      onClick={() => themeVar(theme === 'light' ? 'dark' : 'light')}
    >
      Current: {theme}
    </button>
  );
}
```

### With Derived State

```tsx
function CartSummary() {
  const cartItems = useReactiveVar(cartItemsVar);

  // Derived values are computed on each render
  const totalItems = cartItems.reduce((sum, item) => sum + item.quantity, 0);
  const totalPrice = cartItems.reduce(
    (sum, item) => sum + item.price * item.quantity,
    0
  );

  return (
    <div>
      <p>Items: {totalItems}</p>
      <p>Total: ${totalPrice.toFixed(2)}</p>
    </div>
  );
}
```

### Multiple Reactive Variables

```tsx
function AppLayout() {
  const theme = useReactiveVar(themeVar);
  const sidebarOpen = useReactiveVar(sidebarOpenVar);
  const isLoggedIn = useReactiveVar(isLoggedInVar);

  return (
    <div className={`app ${theme}`}>
      {isLoggedIn && sidebarOpen && <Sidebar />}
      <main>
        <Outlet />
      </main>
    </div>
  );
}
```

### Conditional Subscriptions

```tsx
function NotificationBadge() {
  // Component re-renders only when notifications change
  const notifications = useReactiveVar(notificationsVar);
  const unreadCount = notifications.filter((n) => !n.read).length;

  if (unreadCount === 0) return null;

  return <span className="badge">{unreadCount}</span>;
}
```
