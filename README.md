# Apollo GraphQL Agent Skills

A collection of skills for AI coding agents working with Apollo GraphQL tools and technologies.

Skills follow the [Agent Skills](https://agentskills.io/) format.

## Available Skills

### apollo-connectors

Write Apollo Connectors schemas to integrate REST APIs into GraphQL.

**Install:**
```bash
# Skills CLI
npx skills add https://github.com/apollographql/skills --skill apollo-connectors

# Claude Code
/install-skill https://github.com/apollographql/skills --skill apollo-connectors

# Manual: Copy skills/apollo-connectors to your .claude/skills directory
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
# Skills CLI
npx skills add https://github.com/apollographql/skills --skill apollo-mcp-server

# Claude Code
/install-skill https://github.com/apollographql/skills --skill apollo-mcp-server

# Manual: Copy skills/apollo-mcp-server to your .claude/skills directory
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
# Skills CLI
npx skills add https://github.com/apollographql/skills --skill apollo-server

# Claude Code
/install-skill https://github.com/apollographql/skills --skill apollo-server

# Manual: Copy skills/apollo-server to your .claude/skills directory
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
# Skills CLI
npx skills add https://github.com/apollographql/skills --skill apollo-client

# Claude Code
/install-skill https://github.com/apollographql/skills --skill apollo-client

# Manual: Copy skills/apollo-client to your .claude/skills directory
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

**References:**
[SKILL.md](skills/apollo-client/SKILL.md) ·
[Queries](skills/apollo-client/references/queries.md) ·
[Mutations](skills/apollo-client/references/mutations.md) ·
[Caching](skills/apollo-client/references/caching.md) ·
[State Management](skills/apollo-client/references/state-management.md) ·
[Error Handling](skills/apollo-client/references/error-handling.md) ·
[Troubleshooting](skills/apollo-client/references/troubleshooting.md)

---

## Usage

Skills activate automatically once installed. The agent uses them when relevant tasks are detected.

**Examples:**
```
Connect my REST API at api.example.com/users to my GraphQL schema
```
```
Set up Apollo MCP Server for my GraphQL endpoint
```
```
Help me write a connector for this OpenAPI spec
```
```
Create an Apollo Server with user authentication and a posts API
```

## Skill Structure

Each skill contains:
- `SKILL.md` - Instructions for the agent (required)
- `references/` - Supporting documentation (optional)

## Resources

- [Agent Skills Standard](https://agentskills.io/)
- [Apollo Client Documentation](https://www.apollographql.com/docs/react/)
- [Apollo Server Documentation](https://www.apollographql.com/docs/apollo-server/)
- [Apollo Connectors Documentation](https://www.apollographql.com/docs/graphos/schema-design/connectors/)
- [Apollo MCP Server](https://www.apollographql.com/docs/apollo-mcp-server/)

## License

Apache-2.0
