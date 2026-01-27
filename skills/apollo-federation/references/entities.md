# Entities

Entities are objects that can be uniquely identified by key fields and resolved across subgraphs.

## Defining Entities with @key

Apply `@key` to designate an object type as an entity:

```graphql
type Product @key(fields: "id") {
  id: ID!
  name: String!
  price: Int
}
```

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

## Reference Resolvers

Every subgraph contributing unique fields must implement `__resolveReference`:

```javascript
const resolvers = {
  Product: {
    __resolveReference(representation) {
      // representation contains @key fields + __typename
      return fetchProductById(representation.id);
    }
  }
};
```

### Multiple Keys Resolution

```javascript
__resolveReference(representation) {
  if (representation.sku) {
    return fetchProductBySku(representation.sku);
  }
  return fetchProductById(representation.id);
}
```

### Avoiding N+1 Problems

Use data loaders:

```javascript
const productLoader = new DataLoader(ids =>
  fetchProductsByIds(ids)
);

__resolveReference(representation) {
  return productLoader.load(representation.id);
}
```

## Contributing Entity Fields

Multiple subgraphs can contribute different fields:

```graphql
# Products subgraph
type Product @key(fields: "id") {
  id: ID!
  name: String!
  price: Int
}

# Inventory subgraph
type Product @key(fields: "id") {
  id: ID!
  inStock: Boolean!
}
```

Each subgraph must define a reference resolver.

## Computed Fields with @requires

Define fields that depend on values from other subgraphs:

```graphql
type Product @key(fields: "id") {
  id: ID!
  size: Int @external
  weight: Int @external
  shippingEstimate: String @requires(fields: "size weight")
}
```

The router fetches `size` and `weight` first, then passes them to the resolver:

```javascript
shippingEstimate(product) {
  return computeEstimate(product.size, product.weight);
}
```

### Nested @requires

```graphql
shippingEstimate: String @requires(fields: "dimensions { size weight }")
```

### @requires with Arguments (Federation 2.1.2+)

```graphql
weight(units: String): Int @external
shippingEstimate: String @requires(fields: "weight(units:\"KILOGRAMS\")")
```

## Referencing Without Contributing

Use `resolvable: false` to reference entities without resolving:

```graphql
type Review @key(fields: "id") {
  id: ID!
  product: Product!
}

type Product @key(fields: "id", resolvable: false) {
  id: ID!
}
```

No reference resolver needed for non-resolvable keys.

## Entity Interfaces (Federation 2.3+)

Apply `@key` to interfaces to create entity interfaces:

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
```

### Adding Fields with @interfaceObject

```graphql
# Subgraph B - adds fields to all implementations
type Media @key(fields: "id") @interfaceObject {
  id: ID!
  reviews: [Review!]!
}
```

Composition adds `reviews` to `Media` interface and all implementations.

### Entity Interface Rules

- All implementing entities must use the same `@key`(s) as the interface
- The defining subgraph must define all implementations
- `@interfaceObject` subgraphs cannot define individual implementations
