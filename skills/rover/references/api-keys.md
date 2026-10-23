# Rover API Key Commands

Create and manage API keys and client-credential pairs for your GraphOS organization.

## api-key create

Create a new API key:

```bash
# Create an operator key (full access)
rover api-key create <ORGANIZATION_ID> operator <KEY_NAME>

# Create a subgraph key (limited access)
rover api-key create <ORGANIZATION_ID> subgraph <KEY_NAME>

# Create a subgraph key with specific permissions
rover api-key create <ORGANIZATION_ID> subgraph <KEY_NAME> \
  --subgraph-config subgraph-config.yaml
```

### Subgraph Configuration

The subgraph config file maps graph variants to subgraph names:

```yaml
graph-id:
  variant-name:
    - subgraph-name-1
    - subgraph-name-2
```

### Client-Credential Pairs

```bash
rover api-key create <ORGANIZATION_ID> client-credentials <NAME> \
  --graph-id my-graph
```

Options for client-credentials:
- `--graph-id` — graph to grant access to (repeatable)
- `--secret-lifetime-days` — how long the secret remains valid

## api-key list

List all API keys for an organization:

```bash
rover api-key list <ORGANIZATION_ID>

# Filter by key type
rover api-key list <ORGANIZATION_ID> --type operator
rover api-key list <ORGANIZATION_ID> --type client-credentials
```

Output includes: key ID, name, creation date, expiration date, and key type.

| Option | Description |
|--------|-------------|
| `--type <TYPE>` | Filter by `operator`, `subgraph`, or `client-credentials`. Repeatable |
| `--limit <N>` | Max number of results (default: 100) |

## api-key delete

Delete an existing API key or client-credential pair:

```bash
rover api-key delete <ORGANIZATION_ID> <KEY_ID>
```

This action cannot be undone.

## api-key rename

Rename an existing API key (not client-credential pairs):

```bash
rover api-key rename <ORGANIZATION_ID> <KEY_ID> <NEW_KEY_NAME>
```

Client-credential pairs cannot be renamed. Create a new pair and delete the old one instead.

## api-key rotate

Rotate a client-credential pair's secret:

```bash
rover api-key rotate <ORGANIZATION_ID> <CLIENT_ID>

# With a grace period for the old secret
rover api-key rotate <ORGANIZATION_ID> <CLIENT_ID> \
  --grace-period-days 7
```

| Option | Description |
|--------|-------------|
| `--grace-period-days` | Days the previous secret remains valid (default: 0) |
