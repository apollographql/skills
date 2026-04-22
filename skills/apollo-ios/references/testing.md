# Testing

Apollo iOS emits two distinct sets of testing affordances:

1. **`ApolloTestSupport`** — a public target shipped with the SDK. Use it to construct strongly-typed `Mock<Type>` fixtures for any object in your schema, and to wire those mocks into a `ApolloClient` via a fake network transport.
2. **Generated test mocks** — emitted alongside your schema types when `output.testMocks` is set to `swiftPackage` or `absolute` in `apollo-codegen-config.json`. These are the schema-specific counterparts to `Mock<Type>`.

This reference covers both, plus the recommended architecture for making view models testable without a real GraphQL server.

## Enable test mocks in codegen

In `apollo-codegen-config.json`:

```json
"output": {
  "testMocks": {
    "swiftPackage": { "targetName": "MyAPITestMocks" }
  }
}
```

Or for non-SPM projects:

```json
"testMocks": {
  "absolute": { "path": "./MyAppTests/Mocks" }
}
```

Regenerate:

```bash
./apollo-ios-cli generate
```

## Link `ApolloTestSupport` to your test target

Add the dependency to your test target only:

```swift
// Package.swift
.testTarget(
  name: "MyAppTests",
  dependencies: [
    "MyApp",
    .product(name: "ApolloTestSupport", package: "apollo-ios"),
    // If you used `testMocks.swiftPackage`, add the generated mocks package too:
    .product(name: "MyAPITestMocks", package: "MyAPI"),
  ]
),
```

## Build test fixtures with `Mock<Type>`

`Mock<ObjectType>` is `@dynamicMemberLookup` — set the fields you need and feed the mock into selection-set conversion helpers:

```swift
import ApolloTestSupport
import MyAPITestMocks
import Testing

@Test
func viewModelDisplaysUser() async throws {
  let userMock = Mock<User>()
  userMock.id = "user-1"
  userMock.name = "Ada Lovelace"
  userMock.email = "ada@example.com"

  let data = GetUserQuery.Data.from(userMock)
  // `data` is a real GetUserQuery.Data — feed it into view models or
  // selection-set tests exactly as you would a server response.
  #expect(data.user?.name == "Ada Lovelace")
}
```

Use `Mock<Type>.from(…)` / the typed `Data.from(_:)` helpers emitted by codegen (when test mocks are enabled) to coerce mocks into the precise `Data` type the operation expects.

## Testability architecture — wrap `ApolloClient`

There is no public `MockNetworkTransport` or `MockApolloClient` in the SDK. The cleanest way to make view models testable is to **wrap `ApolloClient` in a protocol your app owns**, then mock the protocol in tests.

```swift
// In the app target:
protocol GraphQLService: Sendable {
  func getUser(id: String) async throws -> GetUserQuery.Data.User?
}

final class ApolloGraphQLService: GraphQLService {
  private let client: ApolloClient
  init(client: ApolloClient) { self.client = client }

  func getUser(id: String) async throws -> GetUserQuery.Data.User? {
    let response = try await client.fetch(query: GetUserQuery(id: id))
    if let errors = response.errors, !errors.isEmpty { throw GraphQLErrors(errors) }
    return response.data?.user
  }
}
```

In tests, conform a fake type to `GraphQLService` and return mocks:

```swift
import ApolloTestSupport
import MyAPITestMocks

final class FakeGraphQLService: GraphQLService {
  var userToReturn: GetUserQuery.Data.User?
  func getUser(id: String) async throws -> GetUserQuery.Data.User? { userToReturn }
}

@Test
func viewModelLoadsUser() async throws {
  let user = Mock<User>()
  user.id = "1"
  user.name = "Grace Hopper"

  let service = FakeGraphQLService()
  service.userToReturn = GetUserQuery.Data.User.from(user)

  let viewModel = UserViewModel(service: service)
  await viewModel.load(userID: "1")

  #expect(viewModel.userName == "Grace Hopper")
}
```

This keeps Apollo-specific types contained to one boundary; the rest of the app tests against plain Swift.

## Integration-testing against a fake server

If you want to test the `ApolloClient` itself (interceptor wiring, cache behavior, response parsing), use a custom `NetworkTransport` that returns canned GraphQL responses.

A minimal pattern:

```swift
import Apollo
import ApolloAPI

final class CannedNetworkTransport: NetworkTransport, Sendable {
  let queryResponses: [String: String]  // operationName → JSON response body

  init(queryResponses: [String: String]) { self.queryResponses = queryResponses }

  func send<Query: GraphQLQuery>(
    query: Query,
    fetchBehavior: FetchBehavior,
    requestConfiguration: RequestConfiguration
  ) throws -> AsyncThrowingStream<GraphQLResponse<Query>, any Error> {
    return AsyncThrowingStream { continuation in
      guard let json = queryResponses[Query.operationName],
            let data = json.data(using: .utf8) else {
        continuation.finish(throwing: TestError.notConfigured)
        return
      }
      // Parse `data` into a GraphQLResponse<Query> using ApolloAPI decoders,
      // then yield and finish. The exact conversion helpers live in ApolloAPI.
      // For most tests, prefer the protocol-based FakeGraphQLService above —
      // this level of detail is only needed when testing Apollo itself.
      _ = data
      continuation.finish(throwing: TestError.notImplemented)
    }
  }

  func send<Mutation: GraphQLMutation>(
    mutation: Mutation,
    requestConfiguration: RequestConfiguration
  ) throws -> AsyncThrowingStream<GraphQLResponse<Mutation>, any Error> {
    throw TestError.notImplemented
  }

  enum TestError: Error { case notConfigured, notImplemented }
}
```

In practice, the overhead of building a fake `NetworkTransport` usually outweighs the benefit. **Prefer the protocol-wrapper pattern above** for view-model tests, and reserve custom transports for the rare cases where you need to test Apollo-specific behavior (cache writes, interceptors, subscription multipart parsing).

## Testing watchers

Watchers fire the result handler whenever the relevant cache records change. To test watcher behavior deterministically:

1. Build a test `ApolloStore` with `InMemoryNormalizedCache`.
2. Write fixture data to the cache with `withinReadWriteTransaction`.
3. Call `client.watch(…)` and assert the handler fires with the expected values.
4. Trigger an update with another `withinReadWriteTransaction` and assert the handler fires again.

```swift
@Test
@MainActor
func watcherReactsToCacheUpdate() async throws {
  let store = ApolloStore()
  // ... build an ApolloClient with a transport that never actually hits the network ...

  var received: [String] = []
  let watcher = await client.watch(query: GetUserQuery(id: "1")) { result in
    if case let .success(response) = result, let name = response.data?.user?.name {
      Task { @MainActor in received.append(name) }
    }
  }

  try await store.withinReadWriteTransaction { tx in
    try tx.write(
      data: /* mocked GetUserQuery.Data with name: "Before" */,
      for: GetUserQuery(id: "1")
    )
  }
  try await Task.sleep(for: .milliseconds(50))

  try await store.withinReadWriteTransaction { tx in
    try tx.write(
      data: /* mocked GetUserQuery.Data with name: "After" */,
      for: GetUserQuery(id: "1")
    )
  }
  try await Task.sleep(for: .milliseconds(50))

  #expect(received == ["Before", "After"])
  watcher.cancel()
}
```

## Ground rules

- **Wrap `ApolloClient` in an app-owned protocol**; test view models against the protocol. Keep Apollo-specific types behind that boundary.
- Never hit the real network in unit tests. If you must exercise `ApolloClient` itself, use a fake `NetworkTransport`.
- Enable `output.testMocks` in `apollo-codegen-config.json` once you start writing tests — the generated `.from(_:)` helpers cut fixture setup dramatically.
- Do not share `Mock<Type>` instances across tests. Build a fresh mock per test to avoid state bleed.
- Test watcher behavior by directly manipulating the `ApolloStore` in `withinReadWriteTransaction`, not by sending real network responses.
- Prefer Swift Testing (`@Test`, `#expect`) for new tests; XCTest also works with the same patterns.
