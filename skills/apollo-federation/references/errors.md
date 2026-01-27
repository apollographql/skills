# Composition Errors

Common errors when composing subgraph schemas into a supergraph.

## Field Sharing Errors

### INVALID_FIELD_SHARING

**Cause:** Field resolved by multiple subgraphs without `@shareable`.

**Fix:** Add `@shareable` to the field in all subgraphs:

```graphql
# Before - fails
type Position {
  x: Int!
}

# After - works
type Position @shareable {
  x: Int!
}
```

### SHAREABLE_HAS_MISMATCHED_RUNTIME_TYPES

**Cause:** Shareable field has incompatible types across subgraphs.

**Fix:** Ensure types are compatible (nullable can coerce to non-nullable, not vice versa).

## External Field Errors

### EXTERNAL_MISSING_ON_BASE

**Cause:** `@external` field not defined in any other subgraph.

**Fix:** Define the field in the originating subgraph, or remove `@external`.

### EXTERNAL_UNUSED

**Cause:** `@external` field not used by `@key`, `@requires`, or `@provides`.

**Fix:** Either use the field in a directive or remove it.

### EXTERNAL_TYPE_MISMATCH

**Cause:** `@external` field type doesn't match the original definition.

**Fix:** Align the type with the originating subgraph.

## Key Errors

### KEY_FIELDS_SELECT_INVALID_TYPE

**Cause:** `@key` includes a field returning list, interface, or union.

**Fix:** Use only scalar, enum, or object fields in keys.

### KEY_FIELDS_HAS_ARGS

**Cause:** `@key` includes a field with arguments.

**Fix:** Key fields cannot have arguments.

### KEY_INVALID_FIELDS

**Cause:** Invalid syntax or unknown fields in `@key`.

**Fix:** Check field names and syntax: `@key(fields: "id")` or `@key(fields: "id organization { id }")`.

### INTERFACE_KEY_NOT_ON_IMPLEMENTATION

**Cause:** Entity interface has `@key` but an implementation doesn't.

**Fix:** All implementations must have the same `@key`(s) as the interface.

## Provides/Requires Errors

### PROVIDES_FIELDS_MISSING_EXTERNAL

**Cause:** `@provides` field not marked `@external`.

**Fix:** Mark the provided field as `@external`:

```graphql
type Product @key(fields: "id") {
  id: ID!
  name: String! @external  # Required
}

type Query {
  products: [Product!]! @provides(fields: "name")
}
```

### REQUIRES_FIELDS_MISSING_EXTERNAL

**Cause:** `@requires` field not marked `@external`.

**Fix:** Mark required fields as `@external`:

```graphql
type Product @key(fields: "id") {
  id: ID!
  weight: Int @external  # Required
  shippingCost: Int @requires(fields: "weight")
}
```

## Override Errors

### OVERRIDE_FROM_SELF_ERROR

**Cause:** `@override(from: "...")` references its own subgraph.

**Fix:** Use the name of the other subgraph.

### OVERRIDE_SOURCE_HAS_OVERRIDE

**Cause:** Overridden field also has `@override` applied.

**Fix:** Only one subgraph can override a field.

### OVERRIDE_COLLISION_WITH_ANOTHER_DIRECTIVE

**Cause:** `@override` used with `@external`, `@provides`, or `@requires`.

**Fix:** Cannot override external or provided/required fields.

## Type Errors

### FIELD_TYPE_MISMATCH

**Cause:** Same field has incompatible types across subgraphs.

**Fix:** Align types. Nullable fields can accept non-nullable, but not vice versa.

### TYPE_KIND_MISMATCH

**Cause:** Same type name but different kinds (e.g., object vs interface).

**Fix:** Use consistent type definitions across subgraphs.

### EMPTY_MERGED_ENUM_TYPE

**Cause:** Enum has no values common to all subgraphs.

**Fix:** Ensure at least one shared value, or use `@inaccessible` for subgraph-specific values.

## Inaccessible Errors

### REFERENCED_INACCESSIBLE

**Cause:** `@inaccessible` element referenced by visible element.

**Fix:** Also mark the referencing element `@inaccessible`, or remove `@inaccessible`.

### ONLY_INACCESSIBLE_CHILDREN

**Cause:** Type has only `@inaccessible` fields.

**Fix:** Add at least one accessible field to the type.

## Satisfiability Errors

### SATISFIABILITY_ERROR

**Cause:** Query cannot be satisfied by available subgraphs.

**Fix:** Ensure traversable path exists between subgraphs. Common causes:
- Missing `@key` on entity
- Missing shared key field between subgraphs
- `resolvable: false` when resolution is needed

## Debugging Tips

1. Run `rover supergraph compose --config supergraph.yaml` locally
2. Check error codes in [Apollo docs](https://apollographql.com/docs/graphos/schema-design/federated-schemas/reference/errors)
3. Use `rover subgraph check` to validate against production
4. Review `@key` fields are consistent across subgraphs
5. Verify all `@external` fields exist in originating subgraph
