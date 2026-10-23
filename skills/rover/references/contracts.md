# Rover Contract Commands

Commands for managing GraphOS contract variants. Contracts create filtered views of a supergraph schema using tag-based include/exclude rules.

## contract publish

Publish a new contract or update an existing contract's configuration:

```bash
rover contract publish my-graph@my-contract-variant \
  --source-variant my-source-variant \
  --include-tag foo \
  --include-tag bar \
  --exclude-tag baz \
  --hide-unreachable-types
```

### Options

| Option | Description | Required |
|--------|-------------|----------|
| `--source-variant` | Source variant to filter from | Required on first publish |
| `--include-tag` | Tag name to include (repeatable) | One of `--include-tag` or `--no-include-tags` |
| `--no-include-tags` | Use an empty include list | One of `--include-tag` or `--no-include-tags` |
| `--exclude-tag` | Tag name to exclude (repeatable) | One of `--exclude-tag` or `--no-exclude-tags` |
| `--no-exclude-tags` | Use an empty exclude list | One of `--exclude-tag` or `--no-exclude-tags` |
| `--hide-unreachable-types` | Hide types unreachable from root fields | One of the hide options |
| `--no-hide-unreachable-types` | Keep unreachable types | One of the hide options |
| `--no-launch` | Do not trigger a launch after updating | Optional |

### Tag Name Rules

Tag names must:
- Begin with a letter or underscore
- Include only letters, numbers, underscores, hyphens, or slashes
- Have a maximum of 128 characters

## contract describe

Fetch and display the configuration of a contract variant:

```bash
rover contract describe my-graph@my-contract-variant
```

Output includes:
- Source variant
- Included tags
- Excluded tags
- Whether unreachable types are hidden

## contract preview

Preview the result of applying contract filters without publishing:

```bash
rover contract preview my-graph@my-source-variant \
  --include-tag foo \
  --exclude-tag bar \
  --hide-unreachable-types
```

This composes the contract schema locally and shows the result without modifying the graph registry.

## CI/CD Example

```bash
# Publish contract configuration
rover contract publish my-graph@partner-api \
  --source-variant production \
  --include-tag partner \
  --no-exclude-tags \
  --hide-unreachable-types
```
