# Federation Directives

Complete reference for all Apollo Federation 2.x directives.

## @key

Designates an object type as an entity with a unique key for cross-subgraph resolution.

### Syntax

```graphql
type Product @key(fields: "id") {
  id: ID!
  name: String!
  price: Int
}
```

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `fields` | String! | — | Selection set of key fields |
| `resolvable` | Boolean | `true` | Whether this subgraph can resolve the entity |

### Key Field Rules

- Must uniquely identify the entity
- Cannot include union/interface fields
- Cannot include fields with arguments
- Use non-nullable fields when possible

### Compound Keys

Use multiple fields when a single field isn't unique:

```graphql
type User @key(fields: "username domain") {
  username: String!
  domain: String!
}
```

### Nested Fields in Keys

```graphql
type User @key(fields: "id organization { id }") {
  id: ID!
  organization: Organization!
}
```

### Multiple Keys

Define multiple keys when different subgraphs use different identifiers:

```graphql
type Product @key(fields: "id") @key(fields: "sku") {
  id: ID!
  sku: String!
  name: String!
}
```

The router uses the most efficient key for resolution.

### Differing Keys Across Subgraphs

Subgraphs can use different keys, but must share at least one:

```graphql
# Products subgraph
type Product @key(fields: "sku") @key(fields: "upc") {
  sku: ID!
  upc: String!
  name: String!
}

# Inventory subgraph
type Product @key(fields: "upc") {
  upc: String!
  inStock: Boolean!
}
```

### Non-Resolvable Keys

Use `resolvable: false` to reference entities without resolving:

```graphql
type Product @key(fields: "id", resolvable: false) {
  id: ID!
}
```

No reference resolver needed for non-resolvable keys.

## @shareable

Allows multiple subgraphs to resolve the same field.

### Syntax

```graphql
type Position @shareable {
  x: Int!
  y: Int!
}
```

### Rules

- If marked `@shareable` in any subgraph, must be `@shareable` or `@external` in all
- For entities, all subgraphs must return identical values for shared fields
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

## @external

Marks a field as resolved by another subgraph. Used with `@requires`, `@provides`, and entity stubs.

### Syntax

```graphql
type Product @key(fields: "id") {
  id: ID!
  weight: Int @external
  shippingCost: Int @requires(fields: "weight")
}
```

### Usage

- With `@requires` — declare fields needed for computation
- With `@provides` — declare fields this subgraph can conditionally resolve
- With `resolvable: false` — not needed on entity stubs (key fields only)

## @requires

Defines computed fields that depend on values from other subgraphs.

### Syntax

```graphql
type Product @key(fields: "id") {
  id: ID!
  size: Int @external
  weight: Int @external
  shippingEstimate: String @requires(fields: "size weight")
}
```

The router fetches `size` and `weight` from the owning subgraph first, then calls this subgraph with those values available.

### Nested @requires

```graphql
shippingEstimate: String @requires(fields: "dimensions { size weight }")
```

### @requires with Arguments (Federation 2.1.2+)

```graphql
weight(units: String): Int @external
shippingEstimate: String @requires(fields: "weight(units:\"KILOGRAMS\")")
```

## @provides

Declares that a field can resolve an `@external` field at a specific query path.

### Syntax

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

### Rules

- Provided field must be marked `@external`
- Field must be `@shareable` or `@external` in all subgraphs defining it
- Field must be `@shareable` in at least one other subgraph

## @override

Migrates a field from one subgraph to another.

### Syntax

```graphql
extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.7",
        import: ["@key", "@override"])

type Bill @key(fields: "id") {
  id: ID!
  amount: Int! @override(from: "Payments")
}
```

The router immediately starts resolving `amount` from this subgraph instead of Payments.

### Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `from` | String! | — | Name of the subgraph to override |
| `label` | String | — | Progressive override label (Enterprise) |

### Progressive @override (Enterprise)

Gradually migrate traffic using percentages:

```graphql
# Start with 1%
amount: Int! @override(from: "Payments", label: "percent(1)")

# Increase to 50%
amount: Int! @override(from: "Payments", label: "percent(50)")

# Complete migration
amount: Int! @override(from: "Payments", label: "percent(100)")
```

### Rules

- Cannot override `@external` fields
- Cannot override fields with `@provides` or `@requires`
- Cannot override from self
- Cannot use on interface fields
- `from` must match subgraph name exactly

## @inaccessible

Hides a field or type from the public API schema while keeping it available internally for composition.

### Syntax

```graphql
type Position @shareable {
  x: Int!
  y: Int!
  z: Int! @inaccessible  # hidden from API schema
}
```

### Usage

Primary use: safely add shared fields across subgraphs in stages. Mark the field `@inaccessible` until all subgraphs define it, then remove the directive.

## @interfaceObject

Allows a subgraph to add fields to all implementations of an entity interface without knowing the individual types. Requires Federation 2.3+.

### Syntax

```graphql
# Subgraph A - defines entity interface
interface Media @key(fields: "id") {
  id: ID!
  title: String!
}

type Book implements Media @key(fields: "id") {
  id: ID!
  title: String!
  author: String!
}

# Subgraph B - adds fields to all implementations
type Media @key(fields: "id") @interfaceObject {
  id: ID!
  reviews: [Review!]!
}
```

Composition adds `reviews` to `Media` interface and all implementations.

### Rules

- All implementing entities must use the same `@key`(s) as the interface
- The defining subgraph must define all implementations
- `@interfaceObject` subgraphs cannot define individual implementations
