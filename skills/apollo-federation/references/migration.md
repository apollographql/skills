# Field Migration

Migrate fields between subgraphs using `@override`.

## Basic Migration with @override

Move `Bill.amount` from Payments to Billing subgraph:

### Step 1: Add Field with @override

```graphql
# Billing subgraph (new)
extend schema
  @link(url: "https://specs.apollo.dev/federation/v2.7",
        import: ["@key", "@override"])

type Bill @key(fields: "id") {
  id: ID!
  amount: Int! @override(from: "Payments")
}
```

The router immediately starts resolving `amount` from Billing.

### Step 2: Remove from Original

```graphql
# Payments subgraph
type Bill @key(fields: "id") {
  id: ID!
  # amount: Int!  -- removed
  payment: Payment
}
```

### Step 3: Remove @override

```graphql
# Billing subgraph
type Bill @key(fields: "id") {
  id: ID!
  amount: Int!  # @override no longer needed
}
```

## Progressive @override (Enterprise)

Gradually migrate traffic using percentages:

### Step 1: Start with Small Percentage

```graphql
type Bill @key(fields: "id") {
  id: ID!
  amount: Int! @override(from: "Payments", label: "percent(1)")
}
```

1% of requests resolve from Billing, 99% from Payments.

### Step 2: Gradually Increase

```graphql
# Increase to 10%
amount: Int! @override(from: "Payments", label: "percent(10)")

# Then 50%
amount: Int! @override(from: "Payments", label: "percent(50)")

# Finally 100%
amount: Int! @override(from: "Payments", label: "percent(100)")
```

### Step 3: Complete Migration

Remove field from original subgraph, then remove `@override`.

## @override Rules

- Cannot override `@external` fields
- Cannot override fields with `@provides` or `@requires`
- Cannot override from self
- Cannot use on interface fields
- `from` must match subgraph name exactly

## Progressive @override Best Practices

### Query Plan Caching

Each unique label creates additional query plans. Mitigate by:

- Don't leave progressive `@override` indefinitely
- Share labels across fields migrating together
- Use a small set of known percentages (`percent(5)`, `percent(25)`, `percent(50)`)

### Migrating Multiple Fields

Apply same label to fields migrating together:

```graphql
type Bill @key(fields: "id") {
  id: ID!
  amount: Int! @override(from: "Payments", label: "percent(10)")
  dueDate: Date! @override(from: "Payments", label: "percent(10)")
}
```

## Migrating Entire Entities

Apply `@override` to all fields:

```graphql
type Bill @key(fields: "id") {
  id: ID!
  amount: Int! @override(from: "Payments")
  dueDate: Date! @override(from: "Payments")
  status: BillStatus! @override(from: "Payments")
}
```

## Custom Override Control

Use coprocessors or Rhai scripts to dynamically control override labels via feature flags instead of publishing schema changes.

Implement `SupergraphService` and:
1. Read `apollo_override::unresolved_labels` context
2. Resolve labels via feature flag service
3. Set `apollo_override::labels_to_override` context
