# Additional Rover Commands

Reference for Rover commands that support common workflows: templates, READMEs, licenses, graph artifacts, plugins, and shell utilities.

## rover template

Generate subgraph boilerplate from federation-compatible templates.

### template use

```bash
# Interactive wizard (prompts for language/framework)
rover template use my-new-subgraph

# Specify language
rover template use my-new-subgraph --language python

# Specify exact template
rover template use my-new-subgraph --template subgraph-typescript-apollo-server
```

### template list

```bash
# List all templates
rover template list

# Filter by language
rover template list --language python
```

Available templates include: C# (Hot Chocolate), Go (gqlgen), Java (Spring GraphQL), JavaScript/TypeScript (Apollo Server), Kotlin (GraphQL Kotlin), Python (Strawberry, Ariadne), Rust (async-graphql).

## rover readme

Manage graph variant READMEs in GraphOS Studio.

```bash
# Fetch a variant's README
rover readme fetch my-graph@production

# Save to file
rover readme fetch my-graph@production --output README.md

# Publish a README
rover readme publish my-graph@production --file ./README.md

# Publish from stdin
echo "# My Graph" | rover readme publish my-graph@production --file -
```

## rover license

Fetch offline enterprise licenses for the GraphOS Router.

```bash
rover license fetch --graph-id <apollo-graph-id>
```

Requires a GraphOS Enterprise plan with offline license support enabled.

Offline licenses are valid for the lesser of your contract duration or one year, plus a 28-day grace period. Rerun `rover license fetch` periodically to keep licenses up to date.

## rover graph-artifact

Manage graph artifacts in Apollo's OCI distribution. Artifacts include composed supergraph schemas that the GraphOS Router fetches at runtime.

### graph-artifact tag

```bash
rover graph-artifact tag <TAG> --graph-id <GRAPH_ID> --digest <DIGEST>

# Or by artifact ID
rover graph-artifact tag <TAG> --graph-id <GRAPH_ID> --graph-artifact-id <ID>
```

### graph-artifact untag

```bash
rover graph-artifact untag <TAG> --graph-id <GRAPH_ID>
```

### graph-artifact fetch

```bash
# By tag
rover graph-artifact fetch --graph-id <GRAPH_ID> --tag-name <TAG>

# By artifact ID
rover graph-artifact fetch --graph-id <GRAPH_ID> --graph-artifact-id <ID>

# By digest
rover graph-artifact fetch --graph-id <GRAPH_ID> --digest <DIGEST>
```

### graph-artifact list-tags

```bash
# All tags for a graph
rover graph-artifact list-tags --graph-id <GRAPH_ID>

# Tags for a specific artifact
rover graph-artifact list-tags --graph-id <GRAPH_ID> --digest <DIGEST>
```

## rover plugin install

Download and install officially supported plugins.

```bash
# Install latest supergraph composition binary
rover install --plugin supergraph@latest-2

# Install specific Router version
rover install --plugin router@=2.0.0

# Install Apollo MCP Server
rover install --plugin apollo-mcp-server@latest

# Accept ELv2 license non-interactively
rover install --plugin router@latest --elv2-license accept
```

Supported plugins: `supergraph`, `router`, `apollo-mcp-server`.

## rover completion

Generate shell completion scripts for tab completion.

```bash
# Bash
rover completion bash > ~/.rover-completion.bash
echo "source ~/.rover-completion.bash" >> ~/.bashrc

# Zsh
rover completion zsh > ~/.rover-completion.zsh
echo "source ~/.rover-completion.zsh" >> ~/.zshrc
```

## rover explain

Get descriptions and solutions for Rover error codes:

```bash
rover explain E029
```

## rover docs

Access Rover's documentation from the CLI:

```bash
# List available doc links
rover docs list

# Open docs in browser
rover docs open
```
