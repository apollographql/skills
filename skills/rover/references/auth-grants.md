# Rover Auth Grants Command

Manage OAuth grants for users in a GraphOS organization.

## auth grants revoke

Revoke every grant a user holds under an organization's OAuth clients, including Rover's own OAuth client and every client-credential pair in the organization.

```bash
# Revoke all grants for a user (with confirmation prompt)
rover auth grants revoke \
  --org <ORGANIZATION_ID> \
  --user <USER_ID> \
  --all

# Skip confirmation prompt
rover auth grants revoke \
  --org <ORGANIZATION_ID> \
  --user <USER_ID> \
  --all \
  --confirm
```

## Options

| Option | Description |
|--------|-------------|
| `--org <ORGANIZATION_ID>` | Organization ID (required) |
| `--user <USER_ID>` | User ID whose grants to revoke (required) |
| `--all` | Revoke every grant the user holds (required) |
| `--confirm` | Skip the confirmation prompt |

## Output

The command reports per-client outcomes in a table showing which grants were revoked and which failed.

With `--format json`, the output includes `organization_id`, `user_id`, `user_is_member`, and a `clients` array with per-client results.

## Error Codes

| Code | Description |
|------|-------------|
| E062 | Confirmation required but running in non-interactive mode without `--confirm` |
| E063 | Partial failure (some grants revoked, some failed) |

## When to Use

- Offboarding a team member from a GraphOS organization
- Revoking compromised user access across all OAuth clients
- Cleaning up grants after rotating client credentials
