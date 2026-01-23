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

## Skill Structure

Each skill contains:
- `SKILL.md` - Instructions for the agent (required)
- `references/` - Supporting documentation (optional)

## Resources

- [Agent Skills Standard](https://agentskills.io/)
- [Apollo Connectors Documentation](https://www.apollographql.com/docs/graphos/schema-design/connectors/)
- [Apollo MCP Server](https://www.apollographql.com/docs/apollo-mcp-server/)

## License

Apache-2.0
