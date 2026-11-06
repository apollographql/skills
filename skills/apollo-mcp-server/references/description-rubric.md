# Description rubric

Whether a description exists can be reported by `LintSchema` where the graph's description rule (`ALL_ELEMENTS_REQUIRE_DESCRIPTION`) is enabled. Whether a description is useful is assessed by the agent. The platform does not judge it. Say which is which in every report.

## Coverage

Count, per subgraph, the elements that have a description and the total:

| Element | Counted |
|---|---|
| Object, interface, union, enum, input and custom scalar types | Each type, including the root `Query` and `Mutation` types |
| Fields on object and interface types | Each field |
| Arguments | Each argument |
| Input fields | Each input field |
| Enum values | Each value |
| Directive definitions | Each directive the SDL defines. Do not count directives imported through `@link` |

Lint output seen so far did not report undocumented arguments, so count arguments yourself and do not rely on lint for them. Cross-check your other counts against the description diagnostics lint returned.

Exclude federation-generated and introspection types (`_Entity`, `_Service`, `_Any`, and names beginning with `__`) from the counts. Report coverage per element kind and overall.

Prioritize coverage on the root `Query` and `Mutation` fields and their arguments, then on the types they return, because agents act on those first.

## Quality criteria

A description is adequate when it tells an agent something it cannot get from the name and type. Check each of these where it applies:

- **Intent**: what the field is for and when to use it instead of a similar field
- **Units**: currency, time zone, percentage versus ratio, bytes versus kilobytes, seconds versus milliseconds
- **Formats**: date and time format, ID format, expected string patterns, case sensitivity
- **Constraints**: allowed ranges, maximum lengths, required combinations of arguments, rate or size limits
- **Defaults and null**: what a default means, and what `null` means for a nullable field
- **Side effects**: for mutations, what changes, what is irreversible, and what the payload returns
- **Relationships**: which entity a key or ID refers to

### Weak and strong

| Coordinate | Weak | Strong |
|---|---|---|
| `Order.total` | "The total." | "Order total including tax and shipping, in minor units of `Order.currency` (for example cents)." |
| `Query.orders(status:)` | "Filter by status." | "Return only orders in this status. Omit to return orders in all statuses." |
| `OrderStatus.PENDING` | "Pending." | "Payment not yet captured. The order can still be cancelled without a refund." |
| `Mutation.cancelOrder` | "Cancels an order." | "Cancels an order that has not shipped. Irreversible. Returns the updated order, or an error payload if the order has shipped." |
| `Customer.createdAt` | "Creation time." | "When the customer record was created, as an ISO 8601 timestamp in UTC." |

A description that restates the name or the type (`"The order ID"` on `Order.id`) counts as present for coverage and weak for quality. Report both numbers.

## Enums and input types

- Every enum has a description, and every value has a description that says what selecting it does
- Every input type and input field is described, including accepted formats and which fields are required together
- Enum and input documentation matters most for arguments on root fields, because agents construct these values directly

## Naming ambiguity

Look for names an agent could confuse or misuse:

- Two fields that sound alike but return different things (`price` and `cost`, `user` and `account`)
- Generic names that need context (`data`, `value`, `info`, `type`, `status` without an enum)
- Abbreviations and internal jargon not explained in a description
- The same concept named differently across subgraphs, or different concepts sharing a name
- Boolean fields whose true value is ambiguous (`hidden`, `disabled` versus `enabled`)

Use the `graphql-schema` naming guidance for the conventions. Report each finding as a coordinate with a suggested rename or a description that removes the ambiguity.

## Rating

Give each subgraph a rating from the findings above. State the coverage figures and findings that drove it, since the rating is a judgment.

| Rating | Meaning |
|---|---|
| Ready | Root fields and arguments are well described, enums and inputs are documented, and no significant naming ambiguity |
| Nearly ready | Minor gaps outside the root fields, or a few ambiguous names |
| Not ready | Root fields or arguments are undocumented, or enums and inputs are largely undocumented, or names are routinely ambiguous |
