# Sharing Types and Fields

By default, each field can only be resolved by one subgraph. Use these patterns to share resolution across subgraphs.

## Value Types with @shareable

Mark types as `@shareable` to allow multiple subgraphs to resolve them:

```graphql
# Subgraph A
type Position @shareable {
  x: Int!
  y: Int!
}

# Subgraph B
type Position @shareable {
  x: Int!
  y: Int!
}
```

### @shareable Rules

- If marked `@shareable` in any subgraph, must be `@shareable` or `@external` in all
- Resolvers must return identical results across subgraphs
- Key fields are automatically shareable

### Field-Level @shareable

```graphql
type Product @key(fields: "id") {
  id: ID!
  name: String! @shareable
  price: Int
}
```

### @shareable with extend

`@shareable` only applies to fields in the same declaration:

```graphql
type Position @shareable {
  x: Int!  # shareable
  y: Int!  # shareable
}

extend type Position {
  z: Int!  # NOT shareable - needs explicit @shareable
}
```

## Differing Shared Fields

### Return Types

Nullable can coerce to non-nullable:

```graphql
# Subgraph A
type Position @shareable {
  x: Int!  # non-nullable
}

# Subgraph B
type Position @shareable {
  x: Int   # nullable - OK, supergraph uses nullable
}
```

Incompatible types fail composition:

```graphql
# INVALID - String vs Int
type Event @shareable {
  timestamp: Int!   # Subgraph A
  timestamp: String! # Subgraph B - composition fails
}
```

### Arguments

- Required in one subgraph can be optional in others
- Cannot be omitted if required anywhere
- Optional arguments omitted from any subgraph are omitted from supergraph

```graphql
# Subgraph A
type Building @shareable {
  height(units: String!): Int!  # required
}

# Subgraph B
type Building @shareable {
  height(units: String): Int!   # optional - OK
}
```

## Conditional Resolution with @provides

Use when a subgraph can resolve a field only at specific query paths:

```graphql
type Product @key(fields: "id") {
  id: ID!
  name: String! @external
}

type Query {
  outOfStockProducts: [Product!]! @provides(fields: "name")
  discontinuedProducts: [Product!]!  # cannot resolve name here
}
```

### @provides Rules

- Provided field must be marked `@external`
- Field must be `@shareable` or `@external` in all subgraphs defining it
- Field must be `@shareable` in at least one other subgraph

## Adding New Shared Fields

Problem: Adding a field to one subgraph breaks composition if others don't have it.

### Solution: Use @inaccessible

```graphql
# Step 1: Add field with @inaccessible
# Subgraph A
type Position @shareable {
  x: Int!
  y: Int!
  z: Int! @inaccessible  # hidden from API schema
}

# Subgraph B (not updated yet)
type Position @shareable {
  x: Int!
  y: Int!
}
```

```graphql
# Step 2: Add field to Subgraph B
# Subgraph B
type Position @shareable {
  x: Int!
  y: Int!
  z: Int!
}

# Step 3: Remove @inaccessible from Subgraph A
type Position @shareable {
  x: Int!
  y: Int!
  z: Int!  # now visible
}
```

## Unions and Interfaces

Shared by default, definitions can differ:

```graphql
# Subgraph A
union Media = Book | Movie

# Subgraph B
union Media = Book | Podcast

# Supergraph
union Media = Book | Movie | Podcast
```

### Interface Challenges

Adding interface fields requires updating all implementations across all subgraphs. Use entity interfaces (`@key` on interface + `@interfaceObject`) to avoid this.

## Input Types

Merged using intersection - only mutual fields preserved:

```graphql
# Subgraph A
input UserInput {
  name: String!
  age: Int
}

# Subgraph B
input UserInput {
  name: String!
  email: String
}

# Supergraph - only common field
input UserInput {
  name: String!
}
```
