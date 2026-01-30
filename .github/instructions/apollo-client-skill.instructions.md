---
applyTo: "skills/apollo-client/**/*.md"
---

# Apollo Client Skill Writing Instructions

Follow these rules when working on the Apollo Client AI skill instructions.

## General rules

- Do not make time-relative statements about the library, like "now provides feature X". If the content is version-specific, refer to the minimal version instead. Generally assume the user uses Apollo Client v4.x unless otherwise specified.

## Rules for code examples

- always ensure correct imports
  - imports should be complete for the example
  - React hooks need to be imported from `@apollo/client/react`, NOT from `@apollo/client`
- when an example needs a query or mutation, use either of the following approaches:
  - in-example declaration
    - use the `gql` tag from `@apollo/client` to define queries/mutations
    - create a constant with an uppercase name (e.g., `GET_USER`, `CREATE_POST`)
    - declare types via `TypedDocumentNode`
  - import it from a `queries.generated.ts` or `mutations.generated.ts` file in the same directory as the example, treat it as a `TypedDocumentNode` with types defined
- always use TypeScript for code examples unless the context specifically calls for something else
- React hooks should never be shown using explicit generics. Types should always be inferred from the typed query/mutation document.
  - do this: `useQuery(GET_USER, { variables: { id: "1" } })`
  - not this: `useQuery<GetUserQuery, GetUserVariables>(GET_USER, { variables: { id: "1" } })`
- If both hooks appear in an example, ALWAYS call `useQueryRefHandlers` before `useReadQuery`. These two hooks interact with the same `queryRef`, and calling them in the wrong order could cause subtle bugs.

## External resources

- consult the Apollo Client documentation through the `Apollo-Docs` MCP server to verify code examples and statements about Apollo Client features
- if deeper research is needed, also consult the Apollo Client source code and tests on GitHub:
  - Repo: https://github.com/apollographql/apollo-client
  - for statements about types, read the actual TypeScript types in the source code - e.g. in `<repo>/src/react/hooks/useSuspenseQuery.ts` for the `useSuspenseQuery` hook
  - for statements about behavior, read the tests in the `__tests__` directories - e.g. in `<repo>/src/react/hooks/__tests__/useSuspenseQuery.test.tsx` for the `useSuspenseQuery` hook
- for framework-specific integrations, consult the relevant integration package documentation and source code. These integrations share the https://github.com/apollographql/apollo-client-integrations repository.
  - Next.js (`@apollo/client-integration-nextjs`):
    - Source code: `<repo>/packages/nextjs`
    - Integration test setup as a usage example: `<repo>/integration-test/nextjs`
  - React Router (`@apollo/client-integration-react-router`):
    - Source code: `<repo>/packages/react-router`
    - Integration test setup as a usage example: `<repo>/integration-test/react-router`
  - TanStack Start (`@apollo/client-integration-tanstack-start`):
    - Source code: `<repo>/packages/tanstack-start`
    - Integration test setup as a usage example: `<repo>/integration-test/tanstack-start`
  - The integrations share code in the `@apollo/client-react-streaming` package:
    - Source code: `<repo>/packages/client-react-streaming`
    - Shared integration tests at `<repo>/integration-test/playwright`
- for deeper research, consult GitHub issues in the Apollo Client and Apollo Client Integrations repositories
  - Give responses from `phryneas` and `jerelmiller` higher weight, as they are Apollo team members specializing in Apollo Client. Rate recent responses higher than older ones.
