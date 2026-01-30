# Fragments Reference

GraphQL fragments define a set of fields for a specific type. In Apollo Client, fragments are especially powerful when colocated with components to define each component's data requirements independently, creating a clear separation of concerns and enabling better component composition.

## Table of Contents

- [What Are Fragments](#what-are-fragments)
- [Basic Fragment Syntax](#basic-fragment-syntax)
- [Fragment Colocation](#fragment-colocation)
- [Fragment Reading Hooks](#fragment-reading-hooks)
- [Data Masking](#data-masking)
- [Fragment Registry](#fragment-registry)
- [TypeScript Integration](#typescript-integration)
- [Best Practices](#best-practices)

## What Are Fragments

A GraphQL fragment defines a set of fields for a specific GraphQL type. Fragments are defined on a specific GraphQL type and can be included in operations using the spread operator (`...`).

In Apollo Client, fragments serve a specific purpose:

**Fragments are for colocation, not reuse.** Each component should declare its data needs in a dedicated fragment. This allows components to independently evolve their data requirements without creating artificial dependencies between unrelated parts of your application.

Fragments enable:

1. **Component colocation**: Define the exact data requirements for a component alongside the component code
2. **Independent evolution**: Change a component's data needs without affecting other components
3. **Code organization**: Compose fragments together to build complete queries that mirror your component hierarchy

## Basic Fragment Syntax

### Defining a Fragment

```typescript
import { gql } from '@apollo/client';

const USER_FRAGMENT = gql`
  fragment UserFields on User {
    id
    name
    email
    avatarUrl
  }
`;
```

Every fragment includes:
- A unique name (`UserFields`)
- The type it operates on (`User`)
- The fields to select

### Using Fragments in Queries

Include fragments in queries using the spread operator:

```typescript
const GET_USER = gql`
  query GetUser($id: ID!) {
    user(id: $id) {
      ...UserFields
    }
  }
  
  ${USER_FRAGMENT}
`;
```

When using GraphQL Code Generator with the recommended configuration (typescript, typescript-operations, and typed-document-node plugins), fragments defined in your source files are automatically picked up and generated into typed document nodes. The generated fragment documents already include the fragment definition, so you don't need to interpolate them manually into queries.

## Fragment Colocation

Fragment colocation is the practice of defining fragments in the same file as the component that uses them. This creates a clear contract between components and their data requirements.

### Why Colocate Fragments

- **Locality**: Data requirements live next to the code that uses them
- **Maintainability**: Changes to component UI and data needs happen together
- **Type safety**: TypeScript can infer exact types from colocated fragments
- **Independence**: Components can evolve their data requirements without affecting other components

### Colocation Pattern

The recommended pattern for colocating fragments with components:

```tsx
import { gql, FragmentType } from '@apollo/client';
import { useSuspenseFragment } from '@apollo/client/react';

// Fragment definition
// This will be picked up by Codegen to create `UserCard_UserFragmentDoc` in `./fragments.generated.ts`.
// As that generated fragment document is correctly typed, we use that in the code going forward.
// This fragment will never be consumed in runtime code, so it is wrapped in `if (false)` so the bundler can omit it when bundling.
if (false) {
  gql`
    fragment UserCard_user on User {
      id
      name
      email
      avatarUrl
    }
  `;
}

// This has been created from above fragment definition by CodeGen and is a correctly typed `TypedDocumentNode`
import { UserCard_UserFragmentDoc } from './fragments.generated.ts';

// Component receives the (partially masked) parent object
export function UserCard({ 
  user 
}: { 
  user: FragmentType<typeof UserCard_UserFragmentDoc> 
}) {
  // Creates a subscription to the fragment in the cache
  const { data } = useSuspenseFragment({
    fragment: UserCard_UserFragmentDoc,
    fragmentName: "UserCard_user",
    from: user,
  });

  return (
    <div>
      <img src={data.avatarUrl} alt={data.name} />
      <h2>{data.name}</h2>
      <p>{data.email}</p>
    </div>
  );
}
```

### Naming Convention

A suggested naming pattern for fragments follows this convention:

```
{ComponentName}_{propName}
```

Where `propName` is the name of the prop the component receives containing the fragment data.

Examples:
- `UserCard_user` - Fragment for the `user` prop in the UserCard component
- `PostList_posts` - Fragment for the `posts` prop in the PostList component
- `CommentItem_comment` - Fragment for the `comment` prop in the CommentItem component

This convention makes it clear which component owns which fragment. However, you can choose a different naming convention based on your project's needs.

### Composing Fragments

Parent components compose child fragments to build complete queries:

```tsx
// Child component
import { gql } from '@apollo/client';

if (false) {
  gql`
    fragment UserAvatar_user on User {
      id
      avatarUrl
      name
    }
  `;
}

// Parent component composes child fragments
if (false) {
  gql`
    fragment UserProfile_user on User {
      id
      name
      email
      bio
      ...UserAvatar_user
    }
  `;
}

// Page-level query composes all fragments
if (false) {
  gql`
    query UserProfilePage($id: ID!) {
      user(id: $id) {
        ...UserProfile_user
      }
    }
  `;
}
```

This creates a hierarchy that mirrors your component tree.

## Fragment Reading Hooks

Apollo Client provides hooks to read fragment data within components. These hooks work with data masking to ensure components only access the data they explicitly requested.

### useSuspenseFragment

For components using Suspense and concurrent features:

```tsx
import { useSuspenseFragment } from '@apollo/client/react';
import { FragmentType } from '@apollo/client';
import { UserCard_UserFragmentDoc } from './fragments.generated';

function UserCard({ 
  user 
}: { 
  user: FragmentType<typeof UserCard_UserFragmentDoc> 
}) {
  const { data } = useSuspenseFragment({
    fragment: UserCard_UserFragmentDoc,
    fragmentName: "UserCard_user",
    from: user,
  });

  return <div>{data.name}</div>;
}
```

### useFragment

For components not using Suspense:

```tsx
import { useFragment } from '@apollo/client/react';
import { FragmentType } from '@apollo/client';
import { UserCard_UserFragmentDoc } from './fragments.generated';

function UserCard({ 
  user 
}: { 
  user: FragmentType<typeof UserCard_UserFragmentDoc> 
}) {
  const { data, complete } = useFragment({
    fragment: UserCard_UserFragmentDoc,
    fragmentName: "UserCard_user",
    from: user,
  });

  if (!complete) {
    return <div>Loading...</div>;
  }

  return <div>{data.name}</div>;
}
```

The `complete` field indicates whether all fragment data is available in the cache.

### Hook Options

Both hooks accept these options:

```typescript
{
  // The fragment document (required)
  fragment: TypedDocumentNode,
  
  // The fragment name (required)
  fragmentName: string,
  
  // The source data containing the fragment (required)
  from: FragmentType<typeof fragment>,
  
  // Variables for the fragment (optional)
  variables?: Variables,
  
  // Custom cache behavior (optional)
  canonizeResults?: boolean,
}
```

## Data Masking

Data masking is a feature that prevents components from accessing data they didn't explicitly request through their fragments. This enforces proper data boundaries and prevents over-rendering.

### Enabling Data Masking

Enable data masking when creating your Apollo Client:

```typescript
import { ApolloClient, InMemoryCache } from '@apollo/client';

const client = new ApolloClient({
  cache: new InMemoryCache(),
  dataMasking: true, // Enable data masking
});
```

### How Data Masking Works

With data masking enabled:

1. Fragments return opaque `FragmentType` objects
2. Components must use `useFragment` or `useSuspenseFragment` to unmask data
3. Components can only access fields defined in their own fragments
4. TypeScript enforces these boundaries at compile time

Without data masking:

```tsx
// ❌ Without data masking - component can access any data from parent
function UserCard({ user }: { user: User }) {
  // Can access any User field, even if not in fragment
  return <div>{user.privateData}</div>;
}
```

With data masking:

```tsx
// ✅ With data masking - component can only access its fragment data
import { UserCard_UserFragmentDoc } from './fragments.generated';

function UserCard({ 
  user 
}: { 
  user: FragmentType<typeof UserCard_UserFragmentDoc> 
}) {
  const { data } = useSuspenseFragment({
    fragment: UserCard_UserFragmentDoc,
    from: user,
  });
  
  // TypeScript error: 'privateData' doesn't exist on fragment type
  // return <div>{data.privateData}</div>;
  
  // Only fields from the fragment are accessible
  return <div>{data.name}</div>;
}
```

### Benefits of Data Masking

- **Prevents over-rendering**: Components only re-render when their specific data changes
- **Enforces boundaries**: Components can't accidentally depend on data they don't own
- **Better refactoring**: Safe to modify parent queries without breaking child components
- **Type safety**: TypeScript catches attempts to access unavailable fields

## Fragment Registry

The fragment registry allows you to register fragments globally, making them available throughout your application without explicit imports.

### Creating a Fragment Registry

```typescript
import { ApolloClient, InMemoryCache } from '@apollo/client';
import { createFragmentRegistry } from '@apollo/client/cache';

export const fragmentRegistry = createFragmentRegistry();

const client = new ApolloClient({
  cache: new InMemoryCache({
    fragments: fragmentRegistry,
  }),
});
```

### Registering Fragments

Register fragments after defining them:

```typescript
import { gql } from '@apollo/client';
import { fragmentRegistry } from './apollo/client';

const USER_FRAGMENT = gql`
  fragment UserFields on User {
    id
    name
    email
  }
`;

fragmentRegistry.register(USER_FRAGMENT);
```

With colocated fragments:

```tsx
import { fragmentRegistry } from '@/apollo/client';
import { UserCard_UserFragmentDoc } from './fragments.generated';

// Register the fragment globally
fragmentRegistry.register(UserCard_UserFragmentDoc);
```

### Using Registered Fragments

Once registered, fragments can be referenced by name in queries without explicit imports:

```tsx
// Fragment is available by name because it's registered
const GET_USER = gql`
  query GetUser($id: ID!) {
    user(id: $id) {
      ...UserCard_user
    }
  }
`;
```

### When to Use Fragment Registry

The fragment registry is most useful when:

- Using colocated fragments extensively
- You want fragments available across your application
- Lazy loading components that define fragments

Avoid the fragment registry when using GraphQL Code Generator's client preset, as it precompiles all fragments.

## TypeScript Integration

Apollo Client provides strong TypeScript support for fragments through GraphQL Code Generator.

### Generated Types

GraphQL Code Generator produces typed fragment documents:

```typescript
// Generated file: fragments.generated.ts
export type UserCard_UserFragment = {
  __typename: 'User';
  id: string;
  name: string;
  email: string;
  avatarUrl: string;
} & { ' $fragmentName'?: 'UserCard_UserFragment' };

export const UserCard_UserFragmentDoc: TypedDocumentNode<
  UserCard_UserFragment,
  never
>;
```

### Type-Safe Fragment Usage

Use `FragmentType` to accept masked fragment data:

```tsx
import { FragmentType } from '@apollo/client';
import { UserCard_UserFragmentDoc } from './fragments.generated';

function UserCard({ 
  user 
}: { 
  user: FragmentType<typeof UserCard_UserFragmentDoc> 
}) {
  const { data } = useSuspenseFragment({
    fragment: UserCard_UserFragmentDoc,
    from: user,
  });
  
  // 'data' is fully typed as UserCard_UserFragment
  return <div>{data.name}</div>;
}
```

### Fragment Type Inference

TypeScript infers types from fragment documents automatically:

```tsx
import { UserCard_UserFragmentDoc } from './fragments.generated';

// Types are inferred from the fragment
const { data } = useSuspenseFragment({
  fragment: UserCard_UserFragmentDoc,
  from: user,
});

// data.name is string
// data.email is string
// data.nonExistentField is a TypeScript error
```

### Parent-Child Type Safety

When passing fragment data from parent to child:

```tsx
// Parent query
const { data } = useSuspenseQuery(GET_USER);

// TypeScript ensures the query includes UserCard_user fragment
// before allowing it to be passed to UserCard
<UserCard user={data.user} />
```

## Best Practices

### Prefer Colocation Over Reuse

**Fragments are for colocation, not reuse.** Each component should declare its data needs in a dedicated fragment, even if multiple components currently need the same fields.

Sharing fragments between components just because they happen to need the same fields today creates artificial dependencies. When one component's requirements change, the shared fragment must be updated, causing all components using it to over-fetch data they don't need.

```tsx
// ✅ Good: Each component has its own fragment
if (false) {
  gql`
    fragment UserCard_user on User {
      id
      name
      email
      avatarUrl
    }
  `;
  
  gql`
    fragment UserListItem_user on User {
      id
      name
      email
    }
  `;
}

// If UserCard later needs 'bio', only UserCard_user changes
// UserListItem doesn't over-fetch 'bio'
```

```tsx
// ❌ Avoid: Sharing a generic fragment across components
const COMMON_USER_FIELDS = gql`
  fragment CommonUserFields on User {
    id
    name
    email
  }
`;

// UserCard and UserListItem both use CommonUserFields
// When UserCard needs 'bio', adding it to CommonUserFields
// causes UserListItem to over-fetch unnecessarily
```

This independence allows each component to evolve its data requirements without affecting unrelated parts of your application.

### One Query Per Page

Compose all page data requirements into a single query at the page level:

```tsx
// ✅ Good: Single page-level query
if (false) {
  gql`
    query UserProfilePage($id: ID!) {
      user(id: $id) {
        ...UserHeader_user
        ...UserPosts_user
        ...UserFriends_user
      }
    }
  `;
}
```

```tsx
// ❌ Avoid: Multiple queries in different components
function UserProfile() {
  const { data: userData } = useQuery(GET_USER);
  const { data: postsData } = useQuery(GET_USER_POSTS);
  const { data: friendsData } = useQuery(GET_USER_FRIENDS);
  // ...
}
```

### Use Fragment-Reading Hooks in Components

Non-page components should use `useFragment` or `useSuspenseFragment`:

```tsx
// ✅ Good: Component reads fragment data
import { UserCard_UserFragmentDoc } from './fragments.generated';

function UserCard({ user }: { user: FragmentType<typeof UserCard_UserFragmentDoc> }) {
  const { data } = useSuspenseFragment({
    fragment: UserCard_UserFragmentDoc,
    from: user,
  });
  return <div>{data.name}</div>;
}
```

```tsx
// ❌ Avoid: Component uses query hook
function UserCard({ userId }: { userId: string }) {
  const { data } = useQuery(GET_USER, { variables: { id: userId } });
  return <div>{data.user.name}</div>;
}
```

### Include __typename for Normalization

Always include `__typename` in fragments for proper cache normalization:

```tsx
// ✅ Good: Includes __typename
if (false) {
  gql`
    fragment UserCard_user on User {
      __typename
      id
      name
      email
    }
  `;
}
```

GraphQL Code Generator automatically includes `__typename` when properly configured.

### Request Only Required Fields

Keep fragments minimal and only request fields the component actually uses:

```tsx
// ✅ Good: Only necessary fields
if (false) {
  gql`
    fragment UserListItem_user on User {
      id
      name
    }
  `;
}
```

```tsx
// ❌ Avoid: Requesting unused fields
if (false) {
  gql`
    fragment UserListItem_user on User {
      id
      name
      email
      bio
      friends {
        id
        name
      }
      posts {
        id
        title
      }
    }
  `;
}
```

### Use @defer for Below-the-Fold Content

Defer slow fields that aren't immediately visible:

```tsx
if (false) {
  gql`
    query ProductPage($id: ID!) {
      product(id: $id) {
        id
        name
        price
        ...ProductReviews_product @defer
      }
    }
  `;
}
```

This allows the page to render quickly while reviews load in the background.

### Handle Client-Only Fields

Use the `@client` directive for fields resolved locally:

```tsx
if (false) {
  gql`
    fragment TodoItem_todo on Todo {
      id
      text
      completed
      isSelected @client
    }
  `;
}
```

### Avoid Deeply Nested Fragments

Keep fragments focused on their component's immediate needs:

```tsx
// ✅ Good: Focused fragment
if (false) {
  gql`
    fragment UserCard_user on User {
      id
      name
      avatar {
        url
        alt
      }
    }
  `;
}
```

```tsx
// ❌ Avoid: Deeply nested data
if (false) {
  gql`
    fragment UserCard_user on User {
      id
      name
      posts {
        id
        title
        comments {
          id
          text
          author {
            id
            name
          }
        }
      }
    }
  `;
}
```

### Enable Data Masking for New Applications

Always enable data masking in new applications:

```typescript
const client = new ApolloClient({
  cache: new InMemoryCache(),
  dataMasking: true,
});
```

This enforces proper boundaries from the start and prevents accidental coupling between components.

## Apollo Client Data Masking vs GraphQL-Codegen Fragment Masking

Apollo Client's data masking and GraphQL Code Generator's fragment masking are different features that serve different purposes:

### GraphQL-Codegen Fragment Masking

GraphQL Code Generator's fragment masking (when using the client preset) is a **type-level** feature:

- Masks data only at the TypeScript type level
- The actual runtime data remains fully accessible on the object
- Using their `useFragment` hook simply "unmasks" the data on a type level
- Does not prevent accidental access to data at runtime
- Parent components receive all data and pass it down

### Apollo Client Data Masking

Apollo Client's data masking is a **runtime** feature with significant performance benefits:

- Removes data at the runtime level, not just the type level
- The `useFragment` and `useSuspenseFragment` hooks create cache subscriptions
- Parent objects are sparse and only contain unmasked data
- Prevents accidental access to data that should be masked

### Key Benefits of Apollo Client Data Masking

**1. No Accidental Data Access**

With runtime data masking, masked fields are not present in the parent object at all. You cannot accidentally access them, even if you bypass TypeScript type checking.

**2. Fewer Re-renders**

Apollo Client's approach creates more efficient subscriptions:

- **Without data masking**: Parent component subscribes to all fields (including masked ones). When a masked child field changes, the parent re-renders to pass that runtime data down the tree.
  
- **With data masking**: Parent component only subscribes to its own unmasked fields. Subscriptions on masked fields happen lower in the React component tree when the child component calls `useSuspenseFragment`. When a masked field changes, only the child component that subscribed to it re-renders.

### Example

```tsx
function ParentComponent() {
  const { data } = useSuspenseQuery(GET_USER);
  
  // With Apollo Client data masking:
  // - data.user only contains unmasked fields
  // - Parent doesn't re-render when child-specific fields change
  
  return <UserCard user={data.user} />;
}

function UserCard({ user }: { user: FragmentType<typeof UserCard_UserFragmentDoc> }) {
  // Creates a cache subscription specifically for UserCard_user fields
  const { data } = useSuspenseFragment({
    fragment: UserCard_UserFragmentDoc,
    from: user,
  });
  
  // Only this component re-renders when these fields change
  return <div>{data.name}</div>;
}
```

This granular subscription approach improves performance in large applications with deeply nested component trees.
