# Review checklist

Prompts to apply to each changed or added coordinate. Each one defers to an existing skill. Load that skill for the rule itself. This file only says what to look for.

Everything in this checklist is model judgment. None of it is produced by `LintSchema`.

## Naming (`graphql-schema`)

- Do new types, fields, arguments and enum values follow the naming conventions in the `graphql-schema` naming reference?
- Are names consistent with neighboring types in the same subgraph and with the rest of the supergraph?
- Are names from the client's perspective, and free of storage or implementation terms?
- Do mutation names describe a business operation?

## Nullability and types (`graphql-schema`)

- Is every nullability choice intentional? Check new `!` and nullable fields against what the backing data can guarantee.
- Do new lists use the `[Type!]!` pattern?
- Are fixed value sets enums, and identifiers `ID`?
- Do new arguments and input fields have a default or are they nullable, so existing clients keep validating?
- Do mutations use a single input argument and a dedicated input type?

## Pagination (`graphql-schema`)

- Can any new list field grow without bound? If so, does it return a connection and give `first` a default page size?
- Do new connections follow the pattern in the `graphql-schema` pagination reference?

## Error modeling (`graphql-schema`)

- Do new mutations return a payload that carries expected failures as data, following the errors reference?
- Is the error approach consistent with existing mutations in the subgraph?

## Security exposure (`graphql-schema`)

- Does any new field expose internal identifiers, personal data or administrative capability? Check against the `graphql-schema` security reference.
- If the answer depends on which data is sensitive, ask the user. Do not guess.

## Entities and keys (`apollo-federation`)

- Does each new entity have a `@key` on a stable, unique field or fields?
- Is a `@key` change compatible with how other subgraphs reference the entity?
- Is a reference-only entity declared with `resolvable: false` where appropriate?
- Are entity contributions split sensibly between subgraphs, with each subgraph owning a coherent slice?

## Shared fields and ownership (`apollo-federation`)

- Is each `@shareable` field or type resolved identically by every subgraph that declares it?
- Is each `@external` field actually used by a `@key`, `@requires`, `@provides` or `@fromContext` in the same subgraph? A key field marked `@external` in an `extend type` is used and must stay
- Do `@requires` and `@provides` selections name fields that exist in the owning subgraph?
- Is each `@override` part of a planned migration, with the source subgraph updated to match?
- Is `@inaccessible` used where a field must exist for composition but not appear in the API schema?

## Evolution

- Is a removed or replaced field deprecated first, with a useful `reason`?
- Does the change set include anything the `proposal-variant-diff` skill would classify as breaking? If so, say the review does not cover impact on clients and point to that skill.
