# Rover LSP Command

Start a language server for schema editing tools. The LSP provides real-time composition diagnostics as you edit subgraph schemas.

## Basic Usage

```bash
# Start the language server (communicates over stdin/stdout)
rover lsp

# With a specific supergraph config
rover lsp --supergraph-config supergraph.yaml

# Custom polling interval for introspection-based subgraphs
rover lsp --supergraph-config supergraph.yaml --polling-interval 10
```

The LSP reads `supergraph.yaml` to discover subgraph schemas, watches for file changes, and reports composition diagnostics to the editor.

## Options

| Option | Description | Default |
|--------|-------------|---------|
| `--supergraph-config <PATH>` | Path to supergraph config file | Auto-detected |
| `--polling-interval, -i <SECONDS>` | Interval for polling introspection-based subgraphs | 5 |
| `--skip-update` | Skip plugin auto-update checks | false |
| `--elv2-license <accept\|warn>` | Accept ELv2 license non-interactively | Prompt |

## Editor Integration

The LSP communicates over stdin/stdout using the Language Server Protocol. Configure your editor to launch `rover lsp` as a language server for `.graphql` files.

### VS Code

Add to your VS Code settings or use an extension that supports custom language servers:

```json
{
  "languageServer": {
    "rover": {
      "command": "rover",
      "args": ["lsp", "--supergraph-config", "supergraph.yaml"],
      "filetypes": ["graphql"]
    }
  }
}
```

## What It Provides

- **Composition diagnostics** as you edit subgraph schemas
- **Real-time feedback** on schema changes that would break composition
- **File watching** for schema files referenced in `supergraph.yaml`

## Prerequisites

- Rover installed and on your `PATH`
- A `supergraph.yaml` file in your project
- ELv2 license acceptance (prompted on first use)
