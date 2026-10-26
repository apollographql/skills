# Rover Init Command

Initialize a new federated graph project with `rover init`. This interactive wizard authenticates with GraphOS, creates a graph in the registry, downloads a starter template, and scaffolds a ready-to-run project directory.

## Basic Usage

```bash
# Interactive mode (prompts for every option)
rover init

# Initialize with MCP server capabilities
rover init --mcp

# Specify an output directory
rover init --path ./my-project
```

`rover init` requires authentication. If you have not signed in, the wizard prompts you to authenticate before continuing.

## Interactive Flow

When run without flags, `rover init` walks through these steps:

1. **Authentication** — verifies your GraphOS credentials (via `rover auth login`, `rover config auth` or `APOLLO_KEY`).
2. **Project type** — choose to create a new graph or add a subgraph to an existing one.
3. **Organization** — select which GraphOS organization owns the graph.
4. **Use case** — pick a starting template based on your data source.
5. **Template** — download the selected template files.
6. **Project name** — enter a name for your project.
7. **Graph ID** — confirm or customize the graph identifier in GraphOS.
8. **Preview** — review the files that will be created.
9. **Create** — scaffold the project, register the graph in GraphOS, and generate an API key.

## Project Types

| Type | Description |
|------|-------------|
| **Create new** | Scaffold a brand-new federated graph from a template. |
| **Add subgraph** | Add a new subgraph to an existing federated graph. |

## Use Cases (Templates)

| Use case | Template | Best for |
|----------|----------|----------|
| **Connectors** | `start-with-rest` | Connecting REST APIs to your graph via Apollo Connectors. |
| **GraphQL** | `start-with-typescript` | Wrapping existing GraphQL endpoints into a federated subgraph. |

## What Gets Created

A typical `rover init` run produces:

```
my-project/
├── supergraph.yaml         # Supergraph composition config
├── schema.graphql          # Starter subgraph schema
├── .env                    # APOLLO_KEY and APOLLO_GRAPH_REF
├── package.json            # (if TypeScript template)
└── src/                    # Subgraph server source
```

The wizard also:
- Registers the graph in GraphOS under your selected organization.
- Creates a service API key scoped to the new graph.
- Saves credentials to a `.env` file in the project directory.

## MCP Mode

Use `--mcp` to scaffold a project with an Apollo MCP Server, making your graph's capabilities accessible to AI agents.

```bash
rover init --mcp
```

### MCP Setup Types

The MCP flow prompts you to choose between two setup paths:

| Setup | Description |
|-------|-------------|
| **New project** | Create a new graph with MCP server from a template (REST Connectors or GraphQL). |
| **Existing graph** | Add MCP server capabilities to a graph already registered in GraphOS. |

### New Project MCP Flow

1. Select a data source template (REST Connectors or GraphQL).
2. Choose your organization.
3. Name the project and confirm the graph ID.
4. Preview and confirm file creation.
5. The wizard creates the graph, generates an API key, and scaffolds MCP files.

**Files created (in addition to standard project files):**

```
my-project/
├── .apollo/
│   ├── mcp.local.yaml        # Local MCP server config
│   └── mcp.claude.yaml       # Claude Desktop MCP config
├── mcp.Dockerfile             # Container image for MCP server
├── claude_desktop_config.json  # Ready-to-use Claude Desktop config
├── .env                        # Credentials (APOLLO_KEY, APOLLO_GRAPH_REF)
└── supergraph.yaml             # Composition config
```

### Existing Graph MCP Flow

1. Select an existing graph and variant from your organizations.
2. Rover fetches the supergraph schema and subgraph list from GraphOS.
3. Preview and confirm the MCP files to be added.
4. The wizard generates MCP configuration, a Dockerfile, and a `.env` file.

```bash
# With a specific graph (skip the selection prompt)
rover init --mcp --graph-id my-graph@production
```

### Starting the MCP Server

After `rover init --mcp` completes, start the server:

```bash
# Linux/macOS
set -a && source .env && set +a && rover dev --supergraph-config supergraph.yaml --mcp .apollo/mcp.local.yaml

# Windows PowerShell
Get-Content .env | ForEach-Object { $name, $value = $_.split('=',2); [System.Environment]::SetEnvironmentVariable($name, $value) }
rover dev --supergraph-config supergraph.yaml --mcp .apollo/mcp.local.yaml
```

The router runs at `http://localhost:4000` and the MCP server at `http://localhost:5050`.

### Containerized MCP Deployment

```bash
docker build -f mcp.Dockerfile -t my-project-mcp .
docker run --env-file .env -p5050:5050 my-project-mcp
```

## Options Reference

| Option | Description |
|--------|-------------|
| `--mcp` | Enable MCP server scaffolding. |
| `--path <PATH>` | Output directory for the project (default: current directory). |
| `--project-type <TYPE>` | Skip the project type prompt (`create-new` or `add-subgraph`). |
| `--organization <ORG>` | Pre-select an organization by name or ID. |
| `--project-name <NAME>` | Pre-set the project name. |
| `--graph-id <ID>` | Pre-set the graph ID (format: `graph-id` or `graph-id@variant`). |
| `--project-use-case <CASE>` | Pre-select the use case (`connectors` or `graphql-template`). |

## Prerequisites

- Rover installed and on your `PATH`.
- GraphOS authentication configured (`rover auth login`, `rover config auth` or `APOLLO_KEY` environment variable).
- An empty directory for new projects (non-MCP flow checks that the directory is empty).

## Troubleshooting

### Directory Not Empty

```
Cannot initialize because the current directory is not empty
```

Run `rover init` from an empty directory, or use `--path` to specify one.

### Authentication Failure

If the wizard fails at the authentication step, run `rover auth login`, `rover config auth` or set `APOLLO_KEY` first, then retry.

### Graph ID Already Taken

If the generated graph ID conflicts with an existing graph, the wizard prompts you to choose a different one. You can retry up to three times before the command exits.
