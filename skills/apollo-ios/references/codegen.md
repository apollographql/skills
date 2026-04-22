# Code Generation

This reference covers the `apollo-codegen-config.json` file, CLI commands, custom scalars, test mocks, Swift 6 compatibility flags, and build-time automation.

If you don't yet have a codegen config, start with [setup.md](setup.md), which walks through the three project-configuration questions and generates a working config from your answers.

## Mental model

`.graphql` operation files + `schema.graphqls` → `apollo-ios-cli generate` → Swift types conforming to `SelectionSet` / `GraphQLOperation` (plus cache types, test mocks, etc.).

The CLI reads `apollo-codegen-config.json` to determine where inputs live, where outputs go, and what options to apply. The [official Codegen Configuration page](https://www.apollographql.com/docs/ios/code-generation/codegen-configuration) is the source of truth for every field.

## `apollo-codegen-config.json` top-level keys

```json
{
  "schemaNamespace": "MyAPI",
  "input": { /* where .graphqls and .graphql files live */ },
  "output": { /* where generated Swift goes */ },
  "options": { /* codegen behavior tweaks */ },
  "schemaDownload": { /* optional: config for `fetch-schema` command */ },
  "operationManifest": { /* optional: APQ operation manifest output */ },
  "experimentalFeatures": { /* optional: opt-in experiments */ }
}
```

### `input`

- `schemaSearchPaths: [String]` — glob patterns resolved relative to the config file for schema files (`.graphqls`). Include extension files (such as `@typePolicy` declarations) here.
- `operationSearchPaths: [String]` — glob patterns for `.graphql` operation and fragment files.

```json
"input": {
  "schemaSearchPaths": ["**/*.graphqls"],
  "operationSearchPaths": ["**/*.graphql"]
}
```

### `output.schemaTypes`

Controls where the schema module (shared types, cache keys, etc.) is generated.

| Field | Required | Meaning |
|---|---|---|
| `path` | yes | Output directory. |
| `moduleType` | yes | `embeddedInTarget` / `swiftPackage` / `other`. See [setup.md Q2](setup.md#q2-which-schema-moduletype). |

Examples:

```json
"schemaTypes": {
  "path": "./MyApp/MyAPI",
  "moduleType": {
    "embeddedInTarget": {
      "name": "MyApp",
      "accessModifier": "internal"
    }
  }
}
```

```json
"schemaTypes": {
  "path": "./MyAPI",
  "moduleType": { "swiftPackage": {} }
}
```

### `output.operations`

Controls where generated operation types are written.

```json
"operations": { "inSchemaModule": {} }
```

Alternative forms:

```json
"operations": { "relative": { "subpath": "Operations" } }
```

```json
"operations": { "absolute": { "path": "./Shared/Operations" } }
```

### `output.testMocks`

Controls generation of `Mock<Type>` helpers that you use in unit tests.

```json
"testMocks": { "none": {} }
```

Emits no mocks. Use this if you don't need test mocks.

```json
"testMocks": { "swiftPackage": { "targetName": "MyAPITestMocks" } }
```

Emits a sibling test-mocks target in the schema SPM package.

```json
"testMocks": { "absolute": { "path": "./MyAppTests/Mocks" } }
```

Emits mocks at a specific location.

See [testing.md](testing.md) for how to use the generated mocks.

## `options`

All fields optional — defaults are sensible for most projects.

- `schemaDocumentation: "include" | "exclude"` — keep or strip GraphQL doc comments in generated types.
- `deprecatedEnumCases: "include" | "exclude"` — emit deprecated schema enum cases.
- `warningsOnDeprecatedUsage: "include" | "exclude"` — `@available(*, deprecated, …)` on deprecated fields.
- `selectionSetInitializers` — control which selection sets get public memberwise initializers (e.g. for building test fixtures).
- `operationDocumentFormat` — one of `"definition"` (include the query source in generated code) or `"operationId"` (include only the hash, useful with APQ).
- `schemaCustomization.customTypeNames` — rename generated types, enums, and input-object fields (see below).
- `conversionStrategies.enumCases` — `"camelCase"` (default) or `"none"`.
- `pruneGeneratedFiles: Bool` — delete stale files from `schemaTypes.path` before generating.
- `markTypesNonisolated: Bool` — **critical for Swift 6** (see below).

### `options.markTypesNonisolated`

When `true`, generated types are emitted with `nonisolated` modifiers. This prevents compilation errors in modules that enable `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Swift 6.2+).

- Defaults to `true` when the codegen tool is built with Swift 6.2+.
- Defaults to `false` when built with an older toolchain.

If your app runs under Swift 6.2+ with default `@MainActor` isolation and you see "actor-isolated" errors referencing generated Apollo types, ensure `markTypesNonisolated` is `true`.

```json
"options": {
  "markTypesNonisolated": true
}
```

## Custom scalars

Map a GraphQL custom scalar to a Swift type. Apollo iOS requires the Swift type to conform to `CustomScalarType`.

### 1. Declare the mapping in the config

```json
"options": {
  "schemaCustomization": {
    "customTypeNames": {
      "DateTime": "CustomDateTime"
    }
  }
}
```

### 2. Provide the conforming Swift type

Codegen emits a stub file for each custom scalar (in the schema types directory). Edit it to provide the real implementation:

```swift
import ApolloAPI
import Foundation

public struct CustomDateTime: CustomScalarType {
  public let value: Date

  public init(_jsonValue value: JSONValue) throws {
    guard let string = value as? String,
          let date = ISO8601DateFormatter().date(from: string) else {
      throw JSONDecodingError.couldNotConvert(value: value, to: Date.self)
    }
    self.value = date
  }

  public var _jsonValue: JSONValue {
    ISO8601DateFormatter().string(from: value)
  }
}
```

You can also customize enum case names and input-object field names:

```json
"customTypeNames": {
  "SkinCovering": {
    "enum": {
      "name": "CustomSkinCovering",
      "cases": { "HAIR": "CUSTOMHAIR" }
    }
  },
  "PetSearchFilters": {
    "inputObject": {
      "name": "CustomPetSearchFilters",
      "fields": { "size": "customSize" }
    }
  }
}
```

## `schemaDownload`

Optional. Configures what `apollo-ios-cli fetch-schema` does.

### Introspection

```json
"schemaDownload": {
  "downloadMethod": {
    "introspection": {
      "endpointURL": "https://api.example.com/graphql"
    }
  },
  "outputPath": "./MyAPI/schema.graphqls"
}
```

### Apollo Registry (Studio)

```json
"schemaDownload": {
  "downloadMethod": {
    "apolloRegistry": {
      "graphID": "my-graph",
      "variant": "current",
      "apiKey": "$APOLLO_API_KEY"
    }
  },
  "outputPath": "./MyAPI/schema.graphqls"
}
```

## CLI commands

```bash
./apollo-ios-cli init \
  --schema-namespace MyAPI \
  --module-type embeddedInTarget \
  --target-name MyApp
```

Creates a minimal `apollo-codegen-config.json` in the current directory.

```bash
./apollo-ios-cli fetch-schema
```

Downloads the schema according to the `schemaDownload` section.

```bash
./apollo-ios-cli generate
```

Generates Swift types. Pass `--path` if your config file lives elsewhere.

```bash
./apollo-ios-cli generate-operation-manifest
```

Writes an operation manifest for Automatic Persisted Queries. See [interceptors.md](interceptors.md#apq) for how the manifest is consumed at runtime.

## Automating generation on build

Add a **Run Script** build phase (in the app target's Build Phases, before "Compile Sources"):

```bash
cd "$SRCROOT"
./apollo-ios-cli generate
```

Tick **"Based on dependency analysis"** off so Xcode always runs the script (the script is idempotent and fast when there are no schema changes). Add the output files as explicit outputs of the build phase if you want accurate incremental builds.

## Multi-module projects

If you picked `moduleType: swiftPackage` in [setup.md Q2](setup.md#q2-which-schema-moduletype), the schema becomes its own SPM package:

```
MyAPI/
  Package.swift
  Sources/MyAPI/          # generated schema types
  Sources/MyAPITestMocks/ # if testMocks.swiftPackage is used
```

Feature modules depend on the schema package:

```swift
.target(
  name: "FeatureModule",
  dependencies: [
    .product(name: "Apollo", package: "apollo-ios"),
    .product(name: "MyAPI", package: "MyAPI"),
  ]
)
```

When feature modules own their own operations, switch `operations` to `relative` so each operation file is generated next to the `.graphql` file that defines it.

## Ground rules

- Regenerate after every `.graphql` or `.graphqls` change.
- Never hand-edit generated Swift files. Editable stubs (e.g. custom scalar implementations, `SchemaConfiguration.swift`) are emitted exactly once; if you need to regenerate them, delete the stub file first.
- Commit `apollo-codegen-config.json` and `schema.graphqls`. Commit the generated Swift sources unless you guarantee codegen runs on every build machine.
- Keep `markTypesNonisolated: true` for Swift 6 projects.
- Use `pruneGeneratedFiles: true` so deleted operations don't linger as dead Swift files.
