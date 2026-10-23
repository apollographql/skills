# Rover init Command

Initialize a new federated graph or MCP server project with a single interactive command.

## Basic Usage

```bash
# Start the interactive wizard
rover init

# Initialize an MCP server project
rover init --mcp
```

The wizard walks through:
1. Authentication with GraphOS
2. Organization selection
3. Use case selection
4. Project name and graph ID
5. Local file scaffolding

When complete, you get a new graph in GraphOS, local configuration files, boilerplate code, and credentials.

## Options

Pass options directly to skip wizard prompts:

```bash
rover init \
  --project-type create-new \
  --org-id my-org-id \
  --project-use-case connectors \
  --project-name "My Graph" \
  --graph-id my-graph
```

| Option | Description | Values |
|--------|-------------|--------|
| `--project-type` | Create a new graph or add a subgraph | `create-new`, `add-subgraph` |
| `--org-id` | GraphOS organization ID | Your org ID |
| `--project-use-case` | Preconfigure for specific patterns | `connectors`, `graph-ql-template` |
| `--project-name` | Name for the new graph | Any string |
| `--graph-id` | Unique graph identifier in GraphOS | Must be unique |
| `--mcp` | Initialize an MCP server project | Flag |

## Use Cases

### Start with REST APIs (Connectors)

Select this option to integrate REST APIs using Apollo Connectors. Generates a project with connector configuration and schema.

### Start with recommended libraries

Select this option for non-REST data sources. Sets up a graph using the Apollo Server library.

## MCP Server Initialization

```bash
rover init --mcp
```

Creates starter files for an Apollo MCP Server:
- MCP config YAML for local and staging
- Starter MCP tools based on your GraphQL API operations
- `.env` files for running the GraphQL API and MCP Server
- Local configuration and boilerplate code
- Optional `mcp.Dockerfile`

### MCP Options

```bash
rover init --mcp \
  --project-type create-new \
  --org-id my-org-id \
  --project-name "My MCP Graph" \
  --graph-id my-mcp-graph
```

## Generated Output

After completing the wizard, `rover init` generates:

- **Graph ID** — unique identifier for the graph
- **Graph ref** — formatted as `graph-id@current`
- **Graph API key** — store securely (cannot be retrieved later)
- **Local project files** — schema, configuration, boilerplate code
- **`GETTING_STARTED.md`** — next steps documentation

## Next Steps

Run `rover dev` with the generated configuration:

```bash
rover dev --supergraph-config supergraph.yaml
```

For TypeScript projects, start the subgraph server first:

```bash
npm ci
npm start
# Then in another terminal:
rover dev --supergraph-config supergraph.yaml
```
