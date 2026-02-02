# TypeScript Code Generation

This guide covers setting up GraphQL Code Generator for type-safe Apollo Client usage with TypeScript.

## Installation

```bash
npm install -D @graphql-codegen/cli @graphql-codegen/typescript @graphql-codegen/typescript-operations @graphql-codegen/typed-document-node
```

## Configuration

Create a `codegen.ts` file in your project root:

```typescript
// codegen.ts
import { CodegenConfig } from "@graphql-codegen/cli";

const config: CodegenConfig = {
  overwrite: true,
  schema: "<URL_OF_YOUR_GRAPHQL_API>",
  // This assumes that all your source files are in a top-level `src/` directory - you might need to adjust this to your file structure
  documents: ["src/**/*.{ts,tsx}"],
  // Don't exit with non-zero status when there are no documents
  ignoreNoDocuments: true,
  generates: {
    // Use a path that works the best for the structure of your application
    "./src/types/__generated__/graphql.ts": {
      plugins: ["typescript", "typescript-operations", "typed-document-node"],
      config: {
        avoidOptionals: {
          // Use `null` for nullable fields instead of optionals
          field: true,
          // Allow nullable input fields to remain unspecified
          inputValue: false,
        },
        // Use `unknown` instead of `any` for unconfigured scalars
        defaultScalarType: "unknown",
        // Apollo Client always includes `__typename` fields
        nonOptionalTypename: true,
        // Apollo Client doesn't add the `__typename` field to root types so
        // don't generate a type for the `__typename` for root operation types.
        skipTypeNameForRoot: true,
      },
    },
  },
};

export default config;
```

## Enable Data Masking

To enable data masking with GraphQL Code Generator, create a type declaration file to inform Apollo Client about the generated types:

```typescript
// apollo-client.d.ts
import { GraphQLCodegenDataMasking } from "@apollo/client/masking";

declare module "@apollo/client" {
  export interface TypeOverrides
    extends GraphQLCodegenDataMasking.TypeOverrides {}
}
```

## Running Code Generation

Add a script to your `package.json`:

```json
{
  "scripts": {
    "codegen": "graphql-codegen"
  }
}
```

Run code generation:

```bash
npm run codegen
```

## Usage with Apollo Client

The typed-document-node plugin generates `TypedDocumentNode` types that Apollo Client hooks automatically infer:

```typescript
import { useQuery } from "@apollo/client/react";
import { GET_USER } from "./queries.generated";

function UserProfile({ userId }: { userId: string }) {
  // Types are automatically inferred from GET_USER
  const { data } = useQuery(GET_USER, {
    variables: { id: userId },
  });

  return <div>{data.user.name}</div>;
}
```

## Important Notes

- The typed-document-node plugin might have a bundle size tradeoff but can prevent inconsistencies and is best suited for usage with LLMs, so it is recommended for most applications.
- See the [GraphQL Code Generator documentation](https://www.apollographql.com/docs/react/development-testing/graphql-codegen#recommended-starter-configuration) for other recommended configuration patterns if required.
- Apollo Client hooks automatically infer types from `TypedDocumentNode` - never use manual generics like `useQuery<QueryType, VariablesType>()`.
