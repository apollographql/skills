# Additional Rover Commands

Reference for Rover commands that support project scaffolding, API key management, plugin installation, and other utility tasks.

## rover template

Scaffold a new project from an official Apollo template.

### template list

List available templates:

```bash
rover template list
```

### template use

Generate a project from a template:

```bash
rover template use my-project --template subgraph-javascript
```

The command creates a new directory with the template's files. Run `rover template list` to see available template IDs.

## rover readme

Manage the README displayed for a graph variant in Apollo Studio.

### readme fetch

```bash
rover readme fetch my-graph@production
```

Prints the variant's README content to stdout.

### readme publish

```bash
rover readme publish my-graph@production --file ./README.md
```

Publishes the contents of the specified file as the variant's README in Studio.

## rover api-key

Create, list, rotate, rename, and delete API keys for a GraphOS organization. Requires authentication with a credential that has the appropriate organization permissions.

### api-key create

```bash
# Create an operator key
rover api-key create <ORG_ID> operator "CI deploy key"

# Create a subgraph key
rover api-key create <ORG_ID> subgraph "products-subgraph-key"

# Create a client-credential pair (OAuth 2.0 client-credentials grant)
rover api-key create <ORG_ID> client-credentials "my-service"
```

Creating a key prints the secret once. Save it immediately. Rover does not display it again.

### api-key list

```bash
rover api-key list <ORG_ID>
```

Lists all API keys (operator, subgraph, and client-credential pairs) for the organization.

### api-key rename

```bash
rover api-key rename <ORG_ID> <KEY_ID> "new-name"
```

Renames an operator or subgraph API key. Client-credential pairs cannot be renamed. To change a pair's name, create a new one and delete the old one.

### api-key rotate

```bash
rover api-key rotate <ORG_ID> <CLIENT_ID>
```

Rotates the secret for a client-credential pair. Only client-credential pairs support rotation. Operator and subgraph keys do not have a rotate equivalent.

### api-key delete

```bash
rover api-key delete <ORG_ID> <KEY_ID>
```

Deletes an API key or client-credential pair. This action cannot be undone.

## rover plugin

Manage officially supported plugins that Rover downloads and runs: `router`, `supergraph`, and `apollo-mcp-server`.

### plugin install

```bash
# Install a specific version
rover plugin install router@=1.57.1

# Install a specific supergraph composition plugin
rover plugin install supergraph@=2.9.3

# Force reinstall (overwrites existing)
rover plugin install router@=1.57.1 --force

# Accept the ELv2 license non-interactively
rover plugin install router@=1.57.1 --elv2-license accept
```

Plugins are installed to `~/.rover/bin/` by default. Commands like `rover dev` and `rover supergraph compose` install plugins automatically when needed. Use `rover plugin install` to pre-install in CI or air-gapped environments.

**Version formats:**

| Format | Meaning |
|--------|---------|
| `=1.57.1` | Exact version |
| `1` | Latest 1.x release |
| `latest-2` | Latest 2.x release |

## rover license

Fetch an offline enterprise license for self-hosted Apollo Router deployments.

### license fetch

```bash
rover license fetch my-graph@production
```

Prints the offline license JWT to stdout. Redirect to a file for use with the Router:

```bash
rover license fetch my-graph@production > license.jwt
```

Offline license support must be enabled on your Studio organization. Contact your Apollo representative if you receive error E044.

## rover graph-artifact

Manage graph artifacts (persisted query manifests and other build outputs) stored in GraphOS.

### graph-artifact fetch

```bash
rover graph-artifact fetch my-graph@production --artifact-id <ID>
```

### graph-artifact list-tags

```bash
# List tags for a graph
rover graph-artifact list-tags my-graph@production

# List tags for a specific artifact by digest
rover graph-artifact list-tags my-graph@production --digest <DIGEST>
```

### graph-artifact tag

```bash
rover graph-artifact tag my-graph@production --digest <DIGEST> --tag "stable"
```

### graph-artifact untag

```bash
rover graph-artifact untag my-graph@production --tag "stable"
```

## rover completion

Generate shell completion scripts for tab-completing Rover commands and options.

### bash

```bash
# Add to ~/.bashrc
eval "$(rover completion bash)"

# Or write to a file
rover completion bash > ~/.rover/completions.bash
source ~/.rover/completions.bash
```

### zsh

```bash
# Add to ~/.zshrc
eval "$(rover completion zsh)"

# Or write to a completions directory
rover completion zsh > ~/.zfunc/_rover
```

## rover explain

Look up a Rover error code to see its description, common causes, and suggested fixes.

```bash
rover explain E001
rover explain E029
```

Use this when Rover prints an error code (e.g., `error[E029]`) to understand why the error occurred and how to resolve it.

## rover docs

Access Rover's documentation from the command line.

### docs list

```bash
rover docs list
```

Prints all available documentation topic shortlinks.

### docs open

```bash
# Open a specific topic in your browser
rover docs open start
rover docs open configuring
rover docs open migration
```

The topic argument matches the shortlinks shown by `rover docs list`.
