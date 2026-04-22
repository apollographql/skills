# Setup

Use this guide to take an empty Xcode project to a running `ApolloClient` with generated types. Covers SDK install, codegen CLI install, the three project-configuration decisions, writing `apollo-codegen-config.json`, running initial codegen, and wiring `ApolloClient` into SwiftUI.

## Add the SDK

- Always use Apollo iOS **v2+**. v1.x and v0.x are legacy and must not be used for new work.
- Always use the latest **v2.x** release. To find the latest version, run `scripts/list-apollo-ios-versions.sh` and pick the highest `2.N.M` tag (tags do not have a `v` prefix in the 2.x line).

### Swift Package Manager (recommended)

Add Apollo iOS to `Package.swift`:

```swift
dependencies: [
  .package(
    url: "https://github.com/apollographql/apollo-ios.git",
    .upToNextMajor(from: "LATEST_APOLLO_VERSION")
  ),
],
```

Link the products you need to each target that uses them:

```swift
.target(
  name: "MyApp",
  dependencies: [
    .product(name: "Apollo", package: "apollo-ios"),
    // Optional, if you need persistent cache:
    .product(name: "ApolloSQLite", package: "apollo-ios"),
    // Optional, if you need subscriptions:
    .product(name: "ApolloWebSocket", package: "apollo-ios"),
  ]
),
```

In Xcode, the equivalent workflow is **File → Add Package Dependencies → https://github.com/apollographql/apollo-ios.git** and adding `Apollo` (plus optional `ApolloSQLite` / `ApolloWebSocket`) to the target.

## Install the codegen CLI

Apollo iOS ships an SPM command plugin that downloads the `apollo-ios-cli` binary into the project directory. From a directory containing the Apollo SPM package:

```bash
swift package plugin --allow-writing-to-package-directory apollo-cli-install
```

This produces an executable at `./apollo-ios-cli`. Prefix CLI invocations below with `./` (e.g. `./apollo-ios-cli generate`).

For CI and non-SPM setups, download the universal macOS binary from the [Apollo iOS Releases](https://github.com/apollographql/apollo-ios/releases) page.

## Answer the three project-configuration questions **first**

Before writing `apollo-codegen-config.json`, decide three things. These are the decisions the Apollo docs ([Project Configuration](https://www.apollographql.com/docs/ios/project-configuration/intro)) consider foundational. A wrong answer forces painful rework later — **ask the user using `AskUserQuestion` before generating a config**.

### Q1: Single vs. multiple modules?

Will Apollo types live in one target, or be shared across multiple Swift packages / Xcode targets?

- **Single target** — one app target, no shared frameworks. Default recommendation for new apps.
- **Multiple modules** — shared schema used by several feature modules (common in modular SwiftUI apps and iOS/macOS-shared codebases).

Docs: [Project Modularization](https://www.apollographql.com/docs/ios/project-configuration/modularization).

### Q2: Which schema `moduleType`?

How should the generated schema types be packaged?

| `moduleType` | When to use | JSON key |
|---|---|---|
| `embeddedInTarget` | Single target — generated files live inside an existing target. | `"embeddedInTarget"` |
| `swiftPackage` | Multiple modules — generated schema lives in its own SPM package. | `"swiftPackage"` |
| `other` | Custom build system (Tuist, Bazel, etc.); you manage the module yourself. | `"other"` |

Docs: [Schema Types](https://www.apollographql.com/docs/ios/project-configuration/schema-types).

### Q3: Where should operation models live?

Where should the generated query / mutation / subscription types sit relative to the schema?

| `operations` | When to use | JSON key |
|---|---|---|
| Together with the schema | Single target, or you want all operations in one place. | `"inSchemaModule"` |
| Beside the `.graphql` file that defines them | Feature modules that own their own operations. | `"relative"` |
| At a fixed path | You need a specific location that does not match either pattern above. | `"absolute"` |

Docs: [Operation Models](https://www.apollographql.com/docs/ios/project-configuration/operation-models).

## Generate `apollo-codegen-config.json`

The easiest way to create a config file is `./apollo-ios-cli init`, which writes a minimal config you can edit. Pass the answers from the three questions above:

```bash
./apollo-ios-cli init \
  --schema-namespace MyAPI \
  --module-type embeddedInTarget \
  --target-name MyApp
```

The config below is the canonical **single-target** shape (maps to the answers: single target, `embeddedInTarget`, `inSchemaModule`):

```json
{
  "schemaNamespace": "MyAPI",
  "input": {
    "schemaSearchPaths": ["**/*.graphqls"],
    "operationSearchPaths": ["**/*.graphql"]
  },
  "output": {
    "schemaTypes": {
      "path": "./MyApp/MyAPI",
      "moduleType": {
        "embeddedInTarget": {
          "name": "MyApp",
          "accessModifier": "internal"
        }
      }
    },
    "operations": { "inSchemaModule": {} },
    "testMocks": { "none": {} }
  }
}
```

For a **multi-module** project with the schema in its own SPM package:

```json
{
  "schemaNamespace": "MyAPI",
  "input": {
    "schemaSearchPaths": ["**/*.graphqls"],
    "operationSearchPaths": ["**/*.graphql"]
  },
  "output": {
    "schemaTypes": {
      "path": "./MyAPI",
      "moduleType": { "swiftPackage": {} }
    },
    "operations": { "inSchemaModule": {} },
    "testMocks": {
      "swiftPackage": { "targetName": "MyAPITestMocks" }
    }
  }
}
```

For feature modules that own their operations alongside feature code, use `"operations": { "relative": {} }` instead of `"inSchemaModule"`.

See [codegen.md](codegen.md) for the full config reference, custom scalars, and advanced options.

## Download the schema

Add a `schemaDownload` section to your config, then run `./apollo-ios-cli fetch-schema`:

```json
{
  "schemaDownload": {
    "downloadMethod": {
      "introspection": {
        "endpointURL": "https://api.example.com/graphql"
      }
    },
    "outputPath": "./MyApp/MyAPI/schema.graphqls"
  }
}
```

Alternatively, check in a `schema.graphqls` fetched from your GraphQL server or Apollo Studio. Committing the schema file makes builds reproducible.

## Run initial codegen

Once the config file and schema are in place, generate types:

```bash
./apollo-ios-cli generate
```

Rerun `generate` after every change to `schema.graphqls` or any `.graphql` operation file.

To automate this in Xcode, add a **Run Script** build phase to your app target that runs **before** "Compile Sources":

```bash
cd "$SRCROOT"
./apollo-ios-cli generate
```

## Initialize `ApolloClient`

The simplest case — in-memory cache, default interceptors, HTTP transport:

```swift
import Apollo

let apolloClient = ApolloClient(url: URL(string: "https://api.example.com/graphql")!)
```

For real apps, use the full initializer so you can inject a custom interceptor provider (for auth) and a persistent cache:

```swift
import Apollo
import ApolloSQLite

func makeApolloClient() throws -> ApolloClient {
  let cacheURL = try FileManager.default
    .url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    .appendingPathComponent("apollo_cache.sqlite")

  let cache = try SQLiteNormalizedCache(fileURL: cacheURL)
  let store = ApolloStore(cache: cache)

  let endpointURL = URL(string: "https://api.example.com/graphql")!
  let transport = RequestChainNetworkTransport(
    urlSession: URLSession(configuration: .default),
    interceptorProvider: DefaultInterceptorProvider(store: store),
    store: store,
    endpointURL: endpointURL
  )

  return ApolloClient(networkTransport: transport, store: store)
}
```

For custom interceptors (auth tokens, logging, retry), see [interceptors.md](interceptors.md). For subscriptions, see [subscriptions.md](subscriptions.md).

## Wire `ApolloClient` into SwiftUI

Apollo iOS does not ship a built-in SwiftUI environment key, but the canonical pattern is a custom `EnvironmentValues` entry plus a single shared instance at the app root:

```swift
import SwiftUI
import Apollo

extension EnvironmentValues {
  @Entry var apolloClient: ApolloClient = {
    // Replace with your real client. Using a throwing factory from app startup
    // and guarding against failure is preferable to force-unwrap in production.
    try! makeApolloClient()
  }()
}

@main
struct MyApp: App {
  private let apolloClient: ApolloClient

  init() {
    self.apolloClient = try! makeApolloClient()
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(\.apolloClient, apolloClient)
    }
  }
}
```

Access it from any view:

```swift
struct RootView: View {
  @Environment(\.apolloClient) private var apolloClient
  var body: some View { /* ... */ }
}
```

See [operations.md](operations.md) for the `@Observable` view-model pattern that actually executes operations against this client.

## Ground rules

- **Ask before writing `apollo-codegen-config.json`.** The three project-configuration questions are the foundation — bad defaults cascade into hours of rework.
- Commit `apollo-codegen-config.json`, `schema.graphqls`, and all `.graphql` files to source control so builds are reproducible.
- Commit the generated Swift files as well if your `moduleType` is `embeddedInTarget`; gitignore is acceptable only when a build-time `generate` step is guaranteed (for example via a pre-build script).
- Regenerate after every schema or operation change. Never hand-edit generated files.
- Create one `ApolloClient` per endpoint, hold it for the lifetime of the app, and inject it via `Environment`. Never construct a new client per request or per view.
- Put authentication and retry logic in an interceptor. Never embed them in view code or view models.
