# Apollo MCP Server Tools Reference

## Table of Contents

- [Introspection Tools](#introspection-tools)
  - [introspect](#introspect)
  - [search](#search)
  - [validate](#validate)
  - [execute](#execute)
- [Minify Notation](#minify-notation)
- [Custom Tools](#custom-tools)

---

## Introspection Tools

Apollo MCP Server provides four built-in tools for schema exploration and operation execution.

### introspect

Explore schema types in detail with configurable depth.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `type` | String | required | Type name to introspect |
| `depth` | Int | 1 | Recursion depth for related types |
| `minify` | Boolean | false | Use compact notation |

**Examples:**

```
# Basic type introspection
introspect(type: "User")

# Deep introspection with related types
introspect(type: "User", depth: 3)

# Minified output for token efficiency
introspect(type: "User", minify: true)
```

**Output (normal):**
```graphql
type User {
  id: ID!
  name: String!
  email: String
  posts: [Post!]!
  createdAt: DateTime!
}
```

**Output (minified):**
```
T User { id:ID! name:s! email:s posts:[Post!]! createdAt:DateTime! }
```

**Depth Behavior:**

- `depth: 1` - Only the requested type
- `depth: 2` - Requested type + directly referenced types
- `depth: 3` - Two levels of related types
- Maximum recommended: 5

### search

Find types in the schema matching a query.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `query` | String | required | Search term |
| `leafDepth` | Int | 1 | Depth for leaf type expansion |
| `minify` | Boolean | false | Use compact notation |

**Behavior:**

- Returns maximum 5 matching results
- Searches type names, field names, and descriptions
- Case-insensitive matching

**Examples:**

```
# Find user-related types
search(query: "user")

# Search with expanded leaf types
search(query: "product", leafDepth: 2)
```

**Output:**
```
Found 3 types matching "user":
- User (type)
- UserInput (input)
- UserConnection (type)
```

### validate

Check if a GraphQL operation is valid against the schema.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `operation` | String | required | GraphQL operation to validate |

**Validates:**

- Syntax correctness
- Schema compliance (fields exist, types match)
- Variable definitions
- Fragment validity

**Examples:**

```
validate(operation: """
  query GetUser($id: ID!) {
    user(id: $id) {
      id
      name
      nonExistentField
    }
  }
""")
```

**Output (error):**
```
Validation failed:
- Field "nonExistentField" not found on type "User"
```

**Output (success):**
```
Operation is valid.
Variables required: { id: ID! }
```

### execute

Run ad-hoc GraphQL operations against the endpoint.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `operation` | String | required | GraphQL operation |
| `variables` | Object | {} | Operation variables |

**Mutation Mode:**

Behavior depends on `overrides.mutation_mode` configuration:

| Mode | Query | Mutation |
|------|-------|----------|
| `all` | Execute | Execute |
| `explicit` | Execute | Require confirmation |
| `none` | Execute | Block |

**Examples:**

```
# Query execution
execute(
  operation: "query { users { id name } }"
)

# With variables
execute(
  operation: """
    query GetUser($id: ID!) {
      user(id: $id) { id name }
    }
  """,
  variables: { id: "123" }
)

# Mutation (requires appropriate mutation_mode)
execute(
  operation: """
    mutation CreateUser($input: CreateUserInput!) {
      createUser(input: $input) { id }
    }
  """,
  variables: { input: { name: "Alice", email: "alice@example.com" } }
)
```

---

## Minify Notation

Compact notation reduces token usage by 40-60%. Enable globally or per-request.

### Type Abbreviations

| Symbol | Meaning |
|--------|---------|
| `T` | type |
| `I` | input |
| `E` | enum |
| `U` | union |
| `IF` | interface |

### Scalar Abbreviations

| Symbol | Meaning |
|--------|---------|
| `s` | String |
| `i` | Int |
| `f` | Float |
| `b` | Boolean |
| `ID` | ID (unchanged) |

### Modifiers

| Symbol | Meaning |
|--------|---------|
| **!** | Non-null (required) |
| **[]** | List |
| **[!]** | List of non-null |
| **[]!** | Non-null list |
| **[!]!** | Non-null list of non-null |

### Examples

**Normal:**
```graphql
type Product {
  id: ID!
  name: String!
  price: Float!
  description: String
  tags: [String!]!
  variants: [ProductVariant!]
}
```

**Minified:**
```
T Product { id:ID! name:s! price:f! description:s tags:[s!]! variants:[ProductVariant!] }
```

---

## Custom Tools

Each GraphQL operation becomes an MCP tool with:

- **Tool name**: Operation name (e.g., `GetUser`, `CreateProduct`)
- **Parameters**: Operation variables become tool parameters
- **Description**: Generated from operation or custom via directive

### Tool Naming

```graphql
# Tool name: GetUserById
query GetUserById($id: ID!) {
  user(id: $id) { id name }
}

# Tool name: CreateProduct
mutation CreateProduct($input: ProductInput!) {
  createProduct(input: $input) { id }
}
```

### Adding Descriptions

Use comments for tool descriptions:

```graphql
# Fetches a user by their unique identifier.
# Returns user profile including name and email.
query GetUser($id: ID!) {
  user(id: $id) {
    id
    name
    email
  }
}
```

The comment becomes the MCP tool description, helping AI agents understand when to use each tool.
