# Rover Client Commands

Validate client GraphQL operations against your schema and extract embedded GraphQL documents from source files.

## client check

Validate every GraphQL operation in your client project against a published schema in GraphOS.

```bash
rover client check my-graph@staging \
  --include "src/**/*.graphql"
```

### File Discovery

Specify glob patterns to control which files are scanned:

```bash
rover client check my-graph@staging \
  --include "src/**/*.graphql" \
  --exclude "src/__generated__/**"
```

Use `--root-dir` to scan from a different location:

```bash
rover client check my-graph@staging \
  --root-dir /path/to/client \
  --include "**/*.graphql"
```

### Operation Requirements

All operations must have explicit names. Anonymous operations cause an error:

```graphql
# Invalid — errors
{ user { name } }

# Valid
query GetUser {
  user { name }
}
```

### Fragment Handling

Rover deduplicates identical fragments across files. If two files define a fragment with the same name but different bodies, `client check` returns an error.

### Options

| Option | Description |
|--------|-------------|
| `[GRAPH_REF]` | Graph ref (`graph@variant`) to validate against |
| `--include <PATTERN>` | Glob pattern for `.graphql` files. Repeatable |
| `--exclude <PATTERN>` | Glob pattern for files to exclude. Repeatable |
| `--root-dir <DIR>` | Root directory to scan from (default: cwd) |
| `--format <FORMAT>` | Output format: `plain` (default) or `json` |

### Exit Codes

- `0` — all operations valid
- `1` — validation failures or parse errors

### CI/CD Example

```yaml
# .github/workflows/ci.yml
- name: Validate client operations
  run: |
    rover client check my-graph@production \
      --include "src/**/*.graphql"
  env:
    APOLLO_KEY: ${{ secrets.APOLLO_KEY }}
```

## client extract

Extract embedded GraphQL documents from source files into standalone `.graphql` files.

```bash
rover client extract --out-dir graphql
```

### Supported Languages

| Language | Extensions | Detection |
|----------|-----------|-----------|
| TypeScript | `.ts`, `.tsx` | `gql` and `graphql` tagged template literals |
| Swift | `.swift` | Triple-quoted strings (`"""..."""`) |
| Kotlin | `.kt`, `.kts` | Triple-quoted strings (`"""..."""`) |

### File Discovery

```bash
rover client extract \
  --include "src/**/*.ts" \
  --exclude "src/__generated__/**" \
  --language ts --language swift
```

### Output

Rover writes extracted documents to `--out-dir` (default: `graphql`), preserving relative paths:

```
src/components/UserCard.ts  →  graphql/src/components/UserCard.graphql
```

If a `.graphql` file already exists at the target path, Rover writes to `<name>.generated.graphql` instead. Pass `--overwrite` to replace existing files.

### Options

| Option | Description |
|--------|-------------|
| `--include <PATTERN>` | Glob pattern for source files. Repeatable |
| `--exclude <PATTERN>` | Glob pattern for files to exclude. Repeatable |
| `--language <LANG>` | Restrict to `ts`, `swift`, or `kotlin`. Repeatable |
| `--root-dir <DIR>` | Root directory to scan from (default: cwd) |
| `--out-dir <DIR>` | Output directory (default: `graphql`) |
| `--overwrite` | Overwrite existing `.graphql` files |

### Skipped Documents

Rover skips documents it cannot statically extract (template interpolations, syntax errors) but still exits with code `0`. Each skipped document is listed with its source path, line number, and reason.

## Combined Workflow

Extract operations from source code, generate a persisted query manifest, then publish:

```bash
rover client extract --out-dir graphql --overwrite
rover persisted-queries generate --manifest-path pqm.json
rover persisted-queries publish my-graph@prod --manifest ./pqm.json
```
