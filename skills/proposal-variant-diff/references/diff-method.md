# Diff method

There is no diff tool in the GraphOS MCP server. Produce the diff from two SDL documents returned by `GetSubgraphSchema`.

## Normalize first

Before comparing, normalize both documents so that formatting and ordering do not show up as changes.

- Ignore whitespace, comments and the order of definitions, fields, arguments, enum values and directive applications
- Treat `extend type` and `type` for the same name as one definition
- Ignore the federation `@link` import list ordering. Do report a changed `@link` URL (federation version) as a change
- Compare descriptions as text. A description-only change is a non-breaking change, listed separately

## Index by schema coordinate

Index every element by coordinate and compare the two indexes:

| Element | Coordinate |
|---|---|
| Type, interface, union, enum, input, scalar | `Name` |
| Field | `Type.field` |
| Argument | `Type.field(arg:)` |
| Input field | `InputType.field` |
| Enum value | `Enum.VALUE` |
| Directive definition | `@name` |
| Directive application | `Coordinate @name(args)` |

A coordinate present only in the head is added. Present only in the base is removed. Present in both with a different definition is changed.

## What to compare for a changed element

- Type of a field, argument or input field, including list wrapping and nullability (`String` to `String!`, `[ID!]!` to `[ID]!`)
- Default values of arguments and input fields
- Interfaces a type implements, and members of a union
- Enum values added or removed
- Directive applications, including federation directives (`@key` fields, `@shareable`, `@external`, `@requires`, `@provides`, `@override`, `@inaccessible`) and arguments of those directives
- `@deprecated` added, removed or with a changed `reason`
- Repeatable and location changes on directive definitions

## Breaking versus non-breaking

This table is a starting classification from the schema alone. The check results can raise or lower the severity for a specific graph, and any disagreement goes in the report.

| Change | Classification | Notes |
|---|---|---|
| Remove a type, field, argument, enum value or input field | Breaking | Breaking if any client selects or sends it |
| Change a field's type | Breaking | Includes list to non-list |
| Output field `T` to `T!` | Non-breaking | Clients receive fewer nulls |
| Output field `T!` to `T` | Breaking | Clients may not handle null |
| Argument or input field `T` to `T!` | Breaking | Unless a default value is added |
| Argument or input field `T!` to `T` | Non-breaking | |
| Add a required argument or input field with no default | Breaking | Existing operations fail validation |
| Add an optional argument or input field, or one with a default | Non-breaking | |
| Add a type, field or output enum value | Non-breaking | Adding an enum value can break clients with exhaustive switches. Mention it |
| Remove an enum value from an input enum | Breaking | |
| Add a member to a union or an implementation to an interface | Non-breaking, but flag | Clients with exhaustive handling may break |
| Remove a member from a union or an implementation from an interface | Breaking | |
| Change an argument's default value | Potentially breaking | Changes behavior for clients that omit the argument |
| Add `@deprecated` | Non-breaking | Report it. Clients should migrate |
| Remove `@deprecated` | Non-breaking | |
| Add `@inaccessible` to a field or type | Breaking for the API schema | The element disappears from the API schema |
| Change `@key` fields | Composition-impacting | Rely on the check's composition result |
| Add or remove `@shareable`, `@external`, `@override` | Composition-impacting | Rely on the check's composition result |
| Change a description | Non-breaking | |

Where the table says "composition-impacting", do not classify from the diff alone. Report what changed and defer to the composition errors from `GetCheckResults`. For the rules behind those errors, use the `apollo-federation` skill.

## Output ordering

Group by subgraph, then by kind (types, fields, arguments, directives, enum values), then alphabetically by coordinate. Show before and after for every changed element, for example `Order.total: Float! -> Float`.
