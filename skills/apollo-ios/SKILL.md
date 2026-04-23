---
name: apollo-ios
description: >
  Guide for building Apple-platform applications with Apollo iOS, the strongly-typed GraphQL client for Swift. Use this skill when:
  (1) adding Apollo iOS to a Swift Package Manager or Xcode project,
  (2) configuring `apollo-codegen-config.json` and running code generation,
  (3) configuring an `ApolloClient` with auth, interceptors, and caching,
  (4) writing queries, mutations, or subscriptions from SwiftUI views,
  (5) writing tests against generated operation mocks.
license: MIT
compatibility: iOS 15+, macOS 12+, tvOS 15+, watchOS 8+, visionOS 1+. Swift 6.1+, Xcode 16+. SwiftUI apps using Swift Concurrency.
metadata:
  author: apollographql
  version: "1.0.0"
allowed-tools: Bash(apollo-ios-cli:*) Bash(swift:*) Bash(xcodebuild:*) Bash(curl:*) Bash(git:*) Read Write Edit Glob Grep WebFetch
---

# Apollo iOS Guide

Apollo iOS is a strongly-typed GraphQL client for Apple platforms. It generates Swift types from your GraphQL operations and schema, and ships an async/await client, a normalized cache (in-memory or SQLite-backed), a pluggable interceptor-based HTTP transport that handles queries, mutations, and multipart subscriptions, and an optional WebSocket transport (`graphql-transport-ws`) that can carry any operation type.

## Process

Follow this process when adding or working with Apollo iOS:

- [ ] Confirm target platforms, GraphQL endpoint(s), and how the schema is sourced.
- [ ] Add Apollo iOS via Swift Package Manager and install the `apollo-ios-cli`.
- [ ] Link each target to the correct product (`Apollo` for targets using `ApolloClient`, `ApolloAPI` for targets that only read generated models).
- [ ] Write `apollo-codegen-config.json` using the canonical default (`moduleType: swiftPackage`, `operations: relative`); deviate only when the project has a specific constraint.
- [ ] Run codegen and wire it into the build.
- [ ] Create a single shared `ApolloClient` and inject it via SwiftUI `Environment`.
- [ ] Implement operations (queries, mutations, subscriptions) from `@Observable` view models.
- [ ] Add interceptors for auth and logging.
- [ ] Validate behavior with tests against generated mocks.

## Reference Files

- [Setup](references/setup.md) — Install the SDK and CLI, link the right product (`Apollo` / `ApolloAPI` / `ApolloSQLite` / `ApolloWebSocket` / `ApolloTestSupport`) to each target, generate the canonical `apollo-codegen-config.json`, download the schema, run initial codegen, initialize `ApolloClient`, wire it into SwiftUI.
- [Codegen](references/codegen.md) — Full `apollo-codegen-config.json` reference: `schemaTypes.moduleType` (`swiftPackage` / `embeddedInTarget` / `other`) and `operations` (`relative` / `inSchemaModule` / `absolute`) with tradeoffs and fragment-sharing patterns, custom scalars, test mocks, Swift 6 / MainActor flags, pre-build script.
- [Operations](references/operations.md) — Queries, mutations, watchers, cache policies, error handling, and SwiftUI `@Observable` view-model patterns with async/await.
- [Caching](references/caching.md) — Choosing between in-memory and SQLite cache, declaring cache keys with the `@typePolicy` directive, programmatic cache keys as advanced fallback, watching the cache, manual reads/writes.
- [Interceptors](references/interceptors.md) — The four interceptor protocols, building a custom `InterceptorProvider`, auth token interceptor, logging, retry, APQ.
- [Subscriptions](references/subscriptions.md) — Choosing between HTTP multipart and WebSocket transports, `SplitNetworkTransport` wiring, `connection_init` auth, pause/resume on scene phase, consuming subscriptions from SwiftUI.
- [Testing](references/testing.md) — `ApolloTestSupport`, generated `Mock<Type>` fixtures, the protocol-wrapper pattern for testable view models, integration testing with a fake `NetworkTransport`, testing watchers.

## Scripts

- [list-apollo-ios-versions.sh](scripts/list-apollo-ios-versions.sh) — List published Apollo iOS tags. Use this to find the latest version before writing version-pinned SPM dependencies.

## Key Rules

- Use Apollo iOS **v2+**. v1.x and v0.x are legacy — do not target them for new work.
- Install via **Swift Package Manager**. CocoaPods and Carthage are not the recommended distribution mechanism for apollo-ios.
- Default the codegen config to `moduleType: swiftPackage` and `operations: relative` (see [Setup](references/setup.md)). This shape works for single-target and multi-module apps alike. Deviate only when the project cannot use SPM or has specific fragment-sharing needs (see [Codegen](references/codegen.md)).
- Target linking is a per-target decision made as modules grow — there is no upfront decision to make. Link `Apollo` to targets using `ApolloClient`; link `ApolloAPI` to targets that only consume generated response models.
- Keep `schema.graphqls`, `.graphql` operation files, and `apollo-codegen-config.json` in source control so builds are reproducible.
- Regenerate code after every schema or `.graphql` operation change. Never hand-edit generated files.
- Create a **single shared `ApolloClient`** per endpoint. Inject it via SwiftUI `Environment`; never construct a new client per request.
- Prefer `@typePolicy` schema directives over programmatic cache key resolution when declaring cache keys for types.
- Attach auth tokens in an `HTTPInterceptor` (header mutation is an HTTP concern). Put token-refresh and retry orchestration in a `GraphQLInterceptor` so it wraps the entire operation — `MaxRetryInterceptor` lives at the GraphQL layer for this reason. Never put auth or retry in view code.
- In SwiftUI, scope fetch `Task`s to `.task { }` so they cancel automatically when the view disappears.
- If Xcode MCP tools are available in the agent environment (typically exposed as `mcp__xcode__BuildProject`, `mcp__xcode__RunSomeTests`, `mcp__xcode__XcodeListNavigatorIssues`, etc.), prefer them over raw `xcodebuild` for building, running tests, and inspecting build issues after regenerating code.
