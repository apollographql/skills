---
applyTo: "skills/{apollo-client,apollo-server,graphql-operations}/**/*.md"
---

# JavaScript/TypeScript Code Formatting Instructions

Follow these rules when working on skills that contain JavaScript or TypeScript code examples.

## Code Formatting

- **ALWAYS** format JavaScript and TypeScript code examples with Prettier before every commit
- Run `npm run format` from the repository root to format all code
- Prettier configuration is defined in `.prettierrc` at the repository root
- Code formatting rules:
  - Use 2 spaces for indentation
  - Use double quotes for strings
  - Use semicolons
  - Trailing commas in ES5-compatible locations
  - Line length limit of 80 characters

## Formatting Before Commits

Before committing changes to any JavaScript/TypeScript code examples in markdown files:

1. Run `npm run format` to automatically format all files
2. Review the formatted output to ensure code examples remain readable
3. Commit the formatted changes

Alternatively, use `npm run format:check` to verify formatting without making changes.

## Code Blocks in Markdown

When editing JavaScript/TypeScript code blocks in markdown files:

- Prettier will automatically format code blocks with language identifiers: `javascript`, `typescript`, `js`, `ts`, `jsx`, `tsx`
- Ensure code blocks are properly marked with the correct language identifier
- Preserve the readability of code examples after formatting

## Skills Covered

This formatting requirement applies to the following skills:

- `apollo-client` - React applications with Apollo Client
- `apollo-server` - GraphQL servers with Apollo Server
- `graphql-operations` - GraphQL operations and queries
