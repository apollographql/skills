# Rover Contract Commands

Commands for managing contract variants in Apollo GraphOS. Contracts create filtered views of a supergraph schema, exposing different API surfaces to different consumers.

## What Are Contracts?

A contract variant applies tag-based filters to a source variant's supergraph schema. Subgraph authors annotate types and fields with `@tag(name: "...")` directives, and the contract's include/exclude lists determine which tagged elements appear in the filtered schema. This lets you serve tailored APIs (public vs. internal, partner vs. mobile) from a single supergraph.

## contract describe

View the current configuration of a contract variant.

```bash
rover contract describe my-graph@public-api
```

**Output includes:**
- Source variant name
- Include tags
- Exclude tags
- Whether unreachable types are hidden

**Options:**
| Option | Description |
|--------|-------------|
| `<GRAPH_REF>` | The contract variant to describe (required) |

## contract publish

Publish an updated contract configuration to GraphOS and trigger a launch.

```bash
# Include only fields tagged "public", exclude "internal", hide unreachable types
rover contract publish my-graph@public-api \
  --include-tag public \
  --no-exclude-tags \
  --hide-unreachable-types

# Multiple include tags
rover contract publish my-graph@partner-api \
  --include-tag public \
  --include-tag partner \
  --no-exclude-tags \
  --hide-unreachable-types

# Exclude specific tags, include everything else
rover contract publish my-graph@external-api \
  --no-include-tags \
  --exclude-tag internal \
  --exclude-tag experimental \
  --hide-unreachable-types

# Set the source variant (required on first publish)
rover contract publish my-graph@public-api \
  --source-variant production \
  --include-tag public \
  --no-exclude-tags \
  --hide-unreachable-types

# Publish without triggering a launch
rover contract publish my-graph@public-api \
  --include-tag public \
  --no-exclude-tags \
  --hide-unreachable-types \
  --no-launch
```

**Options:**
| Option | Description |
|--------|-------------|
| `<GRAPH_REF>` | The contract variant to publish to (required) |
| `--source-variant <NAME>` | Source variant for this contract (required on first publish, cannot be changed later) |
| `--include-tag <TAG>` | Tag names to include (repeatable) |
| `--no-include-tags` | Use an empty include list (mutually exclusive with `--include-tag`) |
| `--exclude-tag <TAG>` | Tag names to exclude (repeatable) |
| `--no-exclude-tags` | Use an empty exclude list (mutually exclusive with `--exclude-tag`) |
| `--hide-unreachable-types` | Hide types that are unreachable from any root operation |
| `--no-hide-unreachable-types` | Keep unreachable types in the contract schema |
| `--no-launch` | Do not trigger a launch after publishing |

Every publish requires exactly one flag from each pair: `--include-tag` or `--no-include-tags`, `--exclude-tag` or `--no-exclude-tags`, and `--hide-unreachable-types` or `--no-hide-unreachable-types`.

## contract preview

Preview the contract schema a filter configuration would produce, without publishing it. The build runs asynchronously on GraphOS. By default, Rover polls until it completes.

```bash
# Preview a filter configuration
rover contract preview my-graph@production \
  --include-tag public \
  --no-exclude-tags \
  --hide-unreachable-types

# Start the build and return immediately
rover contract preview my-graph@production \
  --include-tag public \
  --no-exclude-tags \
  --hide-unreachable-types \
  --async

# Check the status of a previously started build
rover contract preview my-graph@production \
  --build-id abc123
```

**Options:**
| Option | Description |
|--------|-------------|
| `<GRAPH_REF>` | The variant whose supergraph to filter (required) |
| `--include-tag <TAG>` | Tag names to include (repeatable) |
| `--no-include-tags` | Use an empty include list |
| `--exclude-tag <TAG>` | Tag names to exclude (repeatable) |
| `--no-exclude-tags` | Use an empty exclude list |
| `--hide-unreachable-types` | Hide unreachable types |
| `--no-hide-unreachable-types` | Keep unreachable types |
| `--async` | Return immediately with a build ID instead of polling |
| `--build-id <ID>` | Check the status of a previous build (conflicts with all filter flags) |

When not using `--build-id`, filter flags follow the same pairing rules as `contract publish`.

## Workflow Examples

### Setting Up a Public API Contract

```bash
# 1. Tag subgraph fields in your schemas with @tag(name: "public")
# 2. Publish the contract configuration
rover contract publish my-graph@public-api \
  --source-variant production \
  --include-tag public \
  --no-exclude-tags \
  --hide-unreachable-types

# 3. Verify the result
rover contract describe my-graph@public-api
```

### Previewing Before Publishing

```bash
# Test a new filter configuration without affecting the live contract
rover contract preview my-graph@production \
  --include-tag public \
  --include-tag partner \
  --no-exclude-tags \
  --hide-unreachable-types

# If the preview looks good, publish
rover contract publish my-graph@partner-api \
  --source-variant production \
  --include-tag public \
  --include-tag partner \
  --no-exclude-tags \
  --hide-unreachable-types
```

### Updating Contract Filters

```bash
# Add a new tag to the existing contract
rover contract publish my-graph@public-api \
  --include-tag public \
  --include-tag beta \
  --no-exclude-tags \
  --hide-unreachable-types
```

## Common Errors

**E039 - Not a contract variant:**
The specified variant is not a contract variant. Verify the `graph@variant` is correct and that the variant is configured as a contract in GraphOS Studio.

**E040 - Contract publish failed:**
The contract configuration could not be published. Check the error message for details on invalid inputs.

## When to Use Contracts

- **Public vs. internal APIs:** Expose a subset of your supergraph to external consumers.
- **Partner-specific APIs:** Give each partner access to only the fields they need.
- **Platform APIs:** Serve different schemas to mobile, web, or IoT clients.
- **Staged rollouts:** Preview contract changes with `contract preview` before publishing.
