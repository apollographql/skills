# Apollo GraphQL Agent Skills

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Skills](https://img.shields.io/badge/skills-9-green.svg)](#skills)

A collection of skills for AI coding agents working with Apollo GraphQL tools and technologies.

Apollo Skills follow the [Agent Skills](https://agentskills.io/) format and are available on [skills.sh](https://skills.sh/).

## Installation

Install skills using the [Skills CLI](https://skills.sh/docs/cli):

```bash
npx skills add apollographql/skills
```

The CLI guides you through an interactive installation:

1. **Select skills** - Choose which skills to install
2. **Select agents** - Pick target agents (Claude Code, Codex, Cursor, Gemini CLI, Goose, OpenCode)
3. **Installation scope** - Project (committed with your code) or Global
4. **Installation method** - Symlink (recommended) or Copy

```
◇  Found 9 skills
│
◆  Select skills to install
│  ◼ apollo-client
│  ◼ apollo-connectors
│  ◼ apollo-server
│  ○ ...
└
```

## Available Skills

### apollo-connectors

Write Apollo Connectors schemas to integrate REST APIs into GraphQL.

**Install:**

```bash
npx skills add apollographql/skills@apollo-connectors
```

**Use when:**

- Connecting REST APIs to a GraphQL supergraph
- Writing `@source` and `@connect` directives
- Implementing entity resolvers with batching
- Validating connector schemas with `rover`

**Categories covered:**

- Selection mapping grammar
- HTTP methods and headers
- Variable interpolation (`$args`, `$this`, `$config`)
- Entity patterns and `@key` directives
- Batch requests with `@listSize`

**Examples:**

- "Connect my REST API to my GraphQL schema"
- "Write a connector for this OpenAPI spec"
- "Add entity resolvers with batching for my users endpoint"

**References:**
[SKILL.md](skills/apollo-connectors/SKILL.md) ·
[Grammar](skills/apollo-connectors/references/grammar.md) ·
[Methods](skills/apollo-connectors/references/methods.md) ·
[Variables](skills/apollo-connectors/references/variables.md) ·
[Entities](skills/apollo-connectors/references/entities.md) ·
[Validation](skills/apollo-connectors/references/validation.md) ·
[Troubleshooting](skills/apollo-connectors/references/troubleshooting.md)

---

### apollo-mcp-server

Configure and use Apollo MCP Server to connect AI agents with GraphQL APIs.

**Install:**

```bash
npx skills add apollographql/skills@apollo-mcp-server
```

**Use when:**

- Setting up Apollo MCP Server for Claude or other AI agents
- Defining MCP tools from GraphQL operations
- Using introspection tools (introspect, search, validate, execute)
- Troubleshooting MCP server connectivity issues

**Categories covered:**

- Server configuration (endpoints, schemas, headers)
- Built-in tools and compact notation
- Operation sources (files, collections, persisted queries)
- Authentication and security
- Health checks and debugging

**Examples:**

- "Set up Apollo MCP Server for my GraphQL endpoint"
- "Configure MCP tools from my GraphQL operations"
- "Debug MCP server connection issues"

**References:**
[SKILL.md](skills/apollo-mcp-server/SKILL.md) ·
[Tools](skills/apollo-mcp-server/references/tools.md) ·
[Configuration](skills/apollo-mcp-server/references/configuration.md) ·
[Troubleshooting](skills/apollo-mcp-server/references/troubleshooting.md)

---

### apollo-server

Build GraphQL servers with Apollo Server 4.x, including schemas, resolvers, authentication, and plugins.

**Install:**

```bash
npx skills add apollographql/skills@apollo-server
```

**Use when:**

- Setting up a new Apollo Server project
- Writing resolvers or defining GraphQL schemas
- Implementing authentication or authorization
- Creating plugins or custom data sources
- Troubleshooting Apollo Server errors or performance issues

**Categories covered:**

- Quick start setup (standalone and Express)
- Schema definition and type system
- Resolver patterns and best practices
- Context and authentication
- Plugins and lifecycle hooks
- Data sources and DataLoader
- Error handling and formatting

**Examples:**

- "Create an Apollo Server with user authentication"
- "Write resolvers for my GraphQL schema"
- "Add a custom plugin to log all queries"

**References:**
[SKILL.md](skills/apollo-server/SKILL.md) ·
[Resolvers](skills/apollo-server/references/resolvers.md) ·
[Context & Auth](skills/apollo-server/references/context-and-auth.md) ·
[Plugins](skills/apollo-server/references/plugins.md) ·
[Data Sources](skills/apollo-server/references/data-sources.md) ·
[Error Handling](skills/apollo-server/references/error-handling.md) ·
[Troubleshooting](skills/apollo-server/references/troubleshooting.md)

---

### apollo-client

Build React applications with Apollo Client 4.x for GraphQL data management, caching, and local state.

**Install:**

```bash
npx skills add apollographql/skills@apollo-client
```

**Use when:**

- Setting up Apollo Client in a React project
- Writing GraphQL queries or mutations with hooks
- Configuring caching or cache policies
- Managing local state with reactive variables
- Troubleshooting Apollo Client errors or performance issues

**Categories covered:**

- Quick start setup (install, client, provider, query)
- useQuery and useLazyQuery hooks
- useMutation with optimistic UI
- InMemoryCache and type policies
- Reactive variables and local state
- Error handling and error links
- Performance optimization

**Examples:**

- "Set up Apollo Client in my React app"
- "Implement optimistic UI for my mutation"
- "Configure cache policies for my queries"

**References:**
[SKILL.md](skills/apollo-client/SKILL.md) ·
[Queries](skills/apollo-client/references/queries.md) ·
[Mutations](skills/apollo-client/references/mutations.md) ·
[Caching](skills/apollo-client/references/caching.md) ·
[State Management](skills/apollo-client/references/state-management.md) ·
[Error Handling](skills/apollo-client/references/error-handling.md) ·
[Troubleshooting](skills/apollo-client/references/troubleshooting.md)

---

### rover

Manage GraphQL schemas and run local supergraph development with Apollo Rover CLI.

**Install:**

```bash
npx skills add apollographql/skills@rover
```

**Use when:**

- Publishing or fetching subgraph schemas to/from GraphOS
- Composing supergraph schemas locally
- Running local supergraph development with rover dev
- Validating schemas with check and lint commands

**Categories covered:**

- Subgraph commands (fetch, publish, check, lint)
- Graph commands (monograph management)
- Supergraph composition
- Local development with rover dev
- Authentication and configuration

**Examples:**

- "Publish my subgraph schema to GraphOS"
- "Run rover dev to test my supergraph locally"
- "Check my schema changes before deploying"

**References:**
[SKILL.md](skills/rover/SKILL.md) ·
[Subgraphs](skills/rover/references/subgraphs.md) ·
[Graphs](skills/rover/references/graphs.md) ·
[Supergraphs](skills/rover/references/supergraphs.md) ·
[Dev](skills/rover/references/dev.md) ·
[Configuration](skills/rover/references/configuration.md)

---

### graphql-schema

Design GraphQL schemas following industry best practices for type design, naming, pagination, errors, and security.

**Install:**

```bash
npx skills add apollographql/skills@graphql-schema
```

**Use when:**

- Designing a new GraphQL schema or API
- Reviewing existing schema for improvements
- Deciding on type structures or nullability
- Implementing pagination or error patterns
- Ensuring security in schema design

**Categories covered:**

- Type design patterns (interfaces, unions, custom scalars)
- Naming conventions for types, fields, and arguments
- Cursor-based pagination (Connection pattern)
- Error modeling and result types
- Security best practices (depth limiting, complexity, authorization)

**Examples:**

- "Design a GraphQL schema for my e-commerce API"
- "Review my schema for best practices"
- "Add cursor-based pagination to my queries"

**References:**
[SKILL.md](skills/graphql-schema/SKILL.md) ·
[Types](skills/graphql-schema/references/types.md) ·
[Naming](skills/graphql-schema/references/naming.md) ·
[Pagination](skills/graphql-schema/references/pagination.md) ·
[Errors](skills/graphql-schema/references/errors.md) ·
[Security](skills/graphql-schema/references/security.md)

---

### graphql-operations

Write GraphQL operations (queries, mutations, fragments) following best practices for client-side development.

**Install:**

```bash
npx skills add apollographql/skills@graphql-operations
```

**Use when:**

- Writing GraphQL queries or mutations
- Organizing operations with fragments
- Optimizing data fetching patterns
- Setting up type generation or linting
- Reviewing operations for efficiency

**Categories covered:**

- Query patterns and optimization
- Mutation patterns and error handling
- Fragment organization and colocation
- Variable usage and types
- Tooling (GraphQL Code Generator, ESLint, IDE extensions)

**Examples:**

- "Write a query with pagination"
- "Organize my operations with fragments"
- "Set up GraphQL Code Generator for type safety"

**References:**
[SKILL.md](skills/graphql-operations/SKILL.md) ·
[Queries](skills/graphql-operations/references/queries.md) ·
[Mutations](skills/graphql-operations/references/mutations.md) ·
[Fragments](skills/graphql-operations/references/fragments.md) ·
[Variables](skills/graphql-operations/references/variables.md) ·
[Tooling](skills/graphql-operations/references/tooling.md)

---

### rust-best-practices

Write idiomatic Rust code following Apollo GraphQL's best practices handbook.

**Install:**

```bash
npx skills add apollographql/skills@rust-best-practices
```

**Use when:**

- Writing new Rust code or functions
- Reviewing or refactoring existing Rust code
- Deciding between borrowing vs cloning or ownership patterns
- Implementing error handling with Result types
- Optimizing Rust code for performance
- Writing tests or documentation for Rust projects

**Categories covered:**

- Coding style and idioms (borrowing, Option/Result, iterators)
- Clippy and linting discipline
- Performance optimization and profiling
- Error handling with thiserror and anyhow
- Testing strategies and snapshot testing
- Generics, static and dynamic dispatch
- Type state pattern for compile-time safety
- Documentation best practices
- Pointer types and thread safety

**Examples:**

- "Review this Rust code for best practices"
- "Help me decide between cloning and borrowing here"
- "Add proper error handling to this function"

**References:**
[SKILL.md](skills/rust-best-practices/SKILL.md) ·
[Style](skills/rust-best-practices/references/style.md) ·
[Errors](skills/rust-best-practices/references/errors.md) ·
[Performance](skills/rust-best-practices/references/performance.md) ·
[Testing](skills/rust-best-practices/references/testing.md) ·
[Advanced](skills/rust-best-practices/references/advanced.md)

---

### skill-creator

Guide for creating effective skills for Apollo GraphQL and GraphQL development.

**Install:**

```bash
npx skills add apollographql/skills@skill-creator
```

**Use when:**

- Creating a new skill for this repository
- Updating an existing skill's structure or content
- Learning skill best practices and patterns
- Writing SKILL.md files or reference documentation

**Categories covered:**

- SKILL.md format and frontmatter fields
- Directory structure and reference files
- Description writing for agent activation triggers
- Progressive disclosure and context optimization
- Apollo Voice writing style guidelines
- Validation checklist for new skills

**Examples:**

- "Create a new skill for Apollo Federation"
- "Help me write a SKILL.md for my custom skill"
- "Review my skill structure for best practices"

**References:**
[SKILL.md](skills/skill-creator/SKILL.md) ·
[Apollo Skills](skills/skill-creator/references/apollo-skills.md)

---

## Usage

Skills activate automatically once installed. The agent uses them when relevant tasks are detected.

You can also explicitly invoke a skill depending on your tool:

| Tool           | Automatic | Explicit Invocation                                     |
| -------------- | --------- | ------------------------------------------------------- |
| Claude Code    | Yes       | Slash command (e.g., `/graphql-schema`)                 |
| GitHub Copilot | Yes       | `/agent` for custom agents, `@github` for GitHub skills |
| Cursor         | Yes       | Rules matched by file patterns (no direct invocation)   |
| Windsurf       | Yes       | Slash command for workflows (e.g., `/workflow-name`)    |

## Skill Structure

Each skill contains:

- `SKILL.md` - Instructions for the agent (required)
- `references/` - Supporting documentation (optional)

## Resources

- [Apollo Client Documentation](https://www.apollographql.com/docs/react/)
- [Apollo Server Documentation](https://www.apollographql.com/docs/apollo-server/)
- [Apollo Connectors Documentation](https://www.apollographql.com/docs/graphos/schema-design/connectors/)
- [Apollo MCP Server](https://www.apollographql.com/docs/apollo-mcp-server/)
- [Rover CLI Documentation](https://www.apollographql.com/docs/rover/)
- [Rust Best Practices Handbook](https://github.com/apollographql/rust-best-practices)

## Disclaimer

The code in this repository is experimental and for reference purposes only. Community feedback is welcome but this project is not officially supported in the same way that repositories in the official [Apollo GraphQL GitHub organization](https://github.com/apollographql) are. If you need help you can file an issue on this repository, [contact Apollo](https://www.apollographql.com/contact-sales) to talk to an expert, or create a ticket directly in Apollo Studio.
