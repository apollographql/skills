# Nullability: `@nonnull` → `@semanticNonNull` + `@catch`

In v5, the legacy client-side `@nonnull` directive is now an error. The replacement model splits the concern into two orthogonal directives:

- `@semanticNonNull` — applied at the **schema** level. Says "this field will not be null *unless there is an error*." Lets the schema author signal stronger nullability without breaking GraphQL's "errors propagate by nulling the field" rule.
- `@catch` — applied at the **operation** level. Tells the codegen how to surface a per-field error to your Kotlin code: as `null`, as a `Result<T, Error>`, or by throwing.

For background, see the [nullability documentation](https://www.apollographql.com/docs/kotlin/advanced/nullability).

## Step 1 — replace `@nonnull` in the schema

If you own the schema:

```graphql
# Before
type User {
  email: String @nonnull
}

# After
type User {
  email: String @semanticNonNull
}
```

If you don't own the schema, extend it in `extra.graphqls`:

```graphql
extend type User @semanticNonNullField(name: "email")
```

You'll also want to `@link` the nullability spec in your schema/extras. Follow the nullability docs for the current `@link` URL.

## Step 2 — opt into error handling in operations via `@catch`

By default a `@semanticNonNull` field is generated as nullable (so errors can null it out without throwing). Use `@catch` on the operation to change the generated shape per field:

```graphql
query GetUser {
  user {
    # Default: nullable String — null on error
    email @catch(to: NULL)

    # Result<String, Error> — caller checks for error explicitly
    email @catch(to: RESULT)

    # Non-null String — throws on error at access time
    email @catch(to: THROW)
  }
}
```

Pick `RESULT` when the calling code needs to render partial data; `NULL` when the field is genuinely optional UX-wise; `THROW` only when an error on that field should abort the operation.

You can also set a default `@catch` at the schema or operation level — see the upstream docs.

## Migration recipe

1. Search the repo: `rg -n "@nonnull"`.
2. For each hit:
   - If it's in a schema file you own → change to `@semanticNonNull`.
   - If it's in an operation (`*.graphql` or `*.graphqls` that contains queries/mutations) → it was being applied client-side; move the equivalent to the schema as `@semanticNonNull` (or `@semanticNonNullField` extension) and add `@catch(to: NULL)` (or whichever flavor matches the old behavior) on the operation field.
3. Rebuild. The codegen errors will tell you about anything still using the old directive.
