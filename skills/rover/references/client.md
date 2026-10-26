# Rover Client Commands

Commands for validating client-side GraphQL operations against a graph's published schema in Apollo GraphOS.

## client check

Validate that all GraphQL operations in `.graphql` files are valid against a graph's published schema.

```bash
# Basic check against a graph variant
rover client check my-graph@production --include "src/**/*.graphql"

# Multiple include patterns
rover client check my-graph@staging \
  --include "src/**/*.graphql" \
  --include "lib/**/*.graphql"

# Exclude generated files
rover client check my-graph@production \
  --include "src/**/*.graphql" \
  --exclude "src/__generated__/**"
```

**What it validates:**
- Every operation's fields, arguments, and types exist in the published schema
- Required arguments are provided
- Fragment references resolve correctly
- Variable types match their usage

**Requirements:**
- All operations must have names. Anonymous operations are rejected with an error.
- Run the command from your client application's root directory.
- Requires authentication (`APOLLO_KEY` or `rover config auth`).

**Options:**
| Option | Description |
|--------|-------------|
| `--include <GLOB>` | Glob pattern(s) for `.graphql` files to scan (required, repeatable) |
| `--exclude <GLOB>` | Glob pattern(s) to exclude from scanning (repeatable) |

**Example output:**
```
Validated 4 operations (3 files scanned)
GetTeamGrid: src/components/TeamGrid.graphql:4:1
  FAILURE Field "league" must not have a selection since type "SportsLeague" has no subfields.

4 total operations validated
1 failure
```

**Exit codes:**
- `0` - All operations passed validation
- Non-zero - One or more operations failed validation

## client extract

Extract GraphQL operations from TypeScript source files (tagged template literals) into standalone `.graphql` files.

```bash
# Extract operations to a directory
rover client extract --out-dir graphql
```

Use this when your operations are embedded in TypeScript source files as `gql` tagged template literals rather than stored in separate `.graphql` files. After extraction, run `rover client check` against the output directory.

**Options:**
| Option | Description |
|--------|-------------|
| `--out-dir <DIR>` | Directory to write extracted `.graphql` files to |

## Workflow: TypeScript Projects

For projects that embed operations in TypeScript with `gql` tags:

```bash
# 1. Extract operations from source files
rover client extract --out-dir graphql

# 2. Validate extracted operations against the schema
rover client check my-graph@staging --include "graphql/**/*.graphql"
```

## CI/CD Integration

Incorporate `rover client check` into your continuous delivery pipeline to validate operations before they go live.

### GitHub Actions

```yaml
# .github/workflows/check.yml
- name: Validate client operations
  run: |
    rover client check my-graph@production \
      --include "src/**/*.graphql"
  env:
    APOLLO_KEY: ${{ secrets.APOLLO_KEY }}
```

### Check Against the Right Variant

Always check operations against the schema variant for the environment you deploy to:

```bash
# Check against production schema before deploying to production
rover client check my-graph@production --include "src/**/*.graphql"

# Check against staging schema during development
rover client check my-graph@staging --include "src/**/*.graphql"
```

If you omit the variant from the graph ref, Rover uses the default variant named `current`.
