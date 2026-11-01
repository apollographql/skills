# Demand Control

Cost-based query protection that estimates and optionally enforces operation cost limits. Prevents expensive operations from overwhelming subgraph resources.

## Overview

Demand control assigns a cost to each incoming operation based on its structure (types, fields, list sizes) and compares it against a configurable maximum. Two modes control behavior:

- **`measure`**: Estimates cost and records it in telemetry without rejecting any operations. Use this first to observe real traffic patterns.
- **`enforce`**: Rejects operations that exceed the configured `max` cost.

Demand control is disabled by default. Requires Router v1.48.0+ (basic), v1.53.0+ (`@cost` directive), v2.12.0+ (subgraph-level limits, `sizedFields`, nested paths).

## Configuration

### Minimal setup (measure mode)

```yaml
demand_control:
  enabled: true
  mode: measure
  strategy:
    static_estimated:
      list_size: 10
      max: 1000.0
```

### Full configuration

```yaml
demand_control:
  enabled: true
  mode: enforce
  strategy:
    static_estimated:
      list_size: 10
      max: 1000.0
      actual_cost_mode: by_subgraph    # "by_subgraph" (default v2.12+) or "by_response_shape"
      subgraph:                         # per-subgraph limits (v2.12.0+)
        all:
          list_size: 10
          max: 500.0
        subgraphs:
          products:
            list_size: 20
            max: 800.0
          analytics:
            list_size: 5
            max: 200.0
```

### Per-subgraph limits (v2.12.0+)

When a subgraph's cost exceeds its individual `max`, the router skips calls to that subgraph only — it does not reject the entire query. Other subgraphs still execute, and the response composes as if the over-budget subgraph returned null.

## Schema Directives

### `@cost`

Overrides the default cost weight for a type or field. Default weights: Query=0, Mutation=10, Subscription=0, Object/Interface/Union=1, Scalar/Enum=0.

```graphql
extend schema
  @link(url: "https://specs.apollo.dev/cost/v0.1",
        import: ["@cost", "@listSize"])

type Address @cost(weight: 5) {
  zipCode: Int!
  city: String!
}

type Query {
  expensiveSearch(q: String!): [Result!]! @cost(weight: 25)
}
```

### `@listSize`

Controls the assumed size of list fields for cost estimation.

| Argument | Type | Description |
|----------|------|-------------|
| `assumedSize` | `Int` | Static list size estimate |
| `slicingArguments` | `[String!]` | Arguments that control list size (e.g., `limit`, `first`) |
| `sizedFields` | `[String!]` | Child list fields that use this list size (v2.12.0+) |
| `requireOneSlicingArgument` | `Boolean` | Require at least one slicing argument |

```graphql
type Query {
  users(limit: Int = 10): [User!]!
    @listSize(slicingArguments: ["limit"])

  search(input: SearchInput!): SearchResults!
    @listSize(
      slicingArguments: ["input.pagination.first"]
      sizedFields: ["results { page }"]
    )

  topProducts: [Product!]!
    @listSize(assumedSize: 5)
}
```

Nested dot-separated paths in `slicingArguments` (e.g., `"input.pagination.first"`) require v2.12.0+.

## Telemetry

### Instruments

| Instrument | Description |
|-----------|-------------|
| `cost.actual` | Actual cost after execution |
| `cost.estimated` | Estimated cost before execution |
| `cost.delta` | Difference between estimated and actual cost |

### Attributes (supergraph scope)

| Attribute | Description |
|-----------|-------------|
| `cost.actual` | Actual operation cost |
| `cost.estimated` | Estimated operation cost |
| `cost.delta` | Estimated minus actual |
| `cost.result` | `COST_OK` or `COST_ESTIMATED_TOO_EXPENSIVE` |

### Selectors

Use in custom events or instruments:

```yaml
telemetry:
  instrumentation:
    instruments:
      supergraph:
        cost.estimated:
          type: histogram
          unit: cost
          description: "Estimated operation cost"
          value:
            cost: estimated
```

## Coprocessor Context Keys

| Key | Description |
|-----|-------------|
| `apollo::demand_control::estimated_cost` | Estimated cost |
| `apollo::demand_control::actual_cost` | Actual cost |
| `apollo::demand_control::result` | `COST_OK` or `COST_TOO_EXPENSIVE` |
| `apollo::demand_control::estimated_cost_by_subgraph` | Cost map per subgraph |
| `apollo::demand_control::actual_cost_by_subgraph` | Actual cost map per subgraph |
| `apollo::demand_control::result_by_subgraph` | Result map per subgraph |
| `apollo::demand_control::strategy` | Active strategy name |

## Rhai Context Keys

| Constant | Description |
|----------|-------------|
| `Router.APOLLO_COST_ESTIMATED_KEY` | Estimated cost |
| `Router.APOLLO_COST_ACTUAL_KEY` | Actual cost |
| `Router.APOLLO_COST_STRATEGY_KEY` | Strategy name |
| `Router.APOLLO_COST_RESULT_KEY` | Cost result |

## Rollout Strategy

1. Start with `mode: measure` and a generous `max` to observe costs without rejecting traffic
2. Review cost distributions in telemetry to find a reasonable threshold
3. Set per-subgraph limits for subgraphs with different cost profiles
4. Switch to `mode: enforce` once thresholds are validated
