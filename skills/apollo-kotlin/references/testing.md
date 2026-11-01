# Testing

This reference covers testing tools for Apollo Kotlin: data builders, mock responses, and debugging utilities.

## Data builders

Data builders provide a type-safe DSL for constructing operation data in tests without manual JSON.

### Setup

Enable data builders in the Gradle config:

```kotlin
apollo {
  service("service") {
    generateDataBuilders.set(true)
  }
}
```

### Building test data

Each generated operation class gets a `Data {}` builder:

```kotlin
val data = GetUserQuery.Data {
  user = buildUser {
    id = "1"
    name = "Jane"
    email = "jane@example.com"
    friends = listOf(
      buildUser {
        id = "2"
        name = "Bob"
      }
    )
  }
}
```

For polymorphic types, use the concrete type builder:

```kotlin
val data = HeroQuery.Data {
  hero = buildHuman {
    name = "Luke"
    height = 1.72
  }
}
```

### Default values

Fields not explicitly set are auto-populated with default values via `DefaultFakeResolver`. To customize defaults, pass a custom `FakeResolver`:

```kotlin
val data = GetUserQuery.Data(resolver = MyFakeResolver()) {
  user = buildUser {
    name = "Custom"
  }
}
```

### Fragment data builders

With `generateFragmentImplementations.set(true)`, build fragment data directly:

```kotlin
val data = UserDetailsImpl.Data {
  id = "1"
  name = "Jane"
}
```

## MockServer

`MockServer` is a full HTTP mock server for integration tests. It runs on all platforms supported by Apollo Kotlin.

### Setup

Add the mock server dependency (separate repository):

```kotlin
testImplementation("com.apollographql.mockserver:apollo-mockserver:MOCKSERVER_VERSION")
```

### Usage

```kotlin
val mockServer = MockServer()

// Enqueue a JSON response
mockServer.enqueueString("""
  {"data": {"user": {"id": "1", "name": "Jane"}}}
""")

val apolloClient = ApolloClient.Builder()
  .serverUrl(mockServer.url())
  .build()

val response = apolloClient.query(GetUserQuery("1")).execute()

// Shut down when done
mockServer.stop()
```

### Custom response control

Use `MockResponse` for full control over status code, headers, and delay:

```kotlin
mockServer.enqueue(MockResponse(
  body = """{"data": {"user": null}}""",
  statusCode = 200,
  headers = mapOf("X-Custom" to "value"),
  delayMillis = 500
))
```

For dynamic routing, pass a `MockServerHandler`:

```kotlin
val handler = object : MockServerHandler {
  override fun handle(request: MockRequest): MockResponse {
    return if (request.body.contains("GetUser")) {
      MockResponse(body = userJson)
    } else {
      MockResponse(body = errorJson, statusCode = 400)
    }
  }
}
val mockServer = MockServer(handler)
```

A custom handler disables `enqueue()`.

## TestNetworkTransport

`TestNetworkTransport` bypasses HTTP entirely, returning predefined GraphQL responses at the transport level.

### Setup

```kotlin
testImplementation("com.apollographql.apollo:apollo-testing-support:APOLLO_VERSION")
```

### QueueTestNetworkTransport

Returns responses in FIFO order:

```kotlin
val apolloClient = ApolloClient.Builder()
  .networkTransport(QueueTestNetworkTransport())
  .build()

val testData = GetUserQuery.Data {
  user = buildUser { name = "Jane" }
}
apolloClient.enqueueTestResponse(GetUserQuery("1"), testData)

val response = apolloClient.query(GetUserQuery("1")).execute()
assertEquals("Jane", response.data?.user?.name)
```

### MapTestNetworkTransport

Maps operations to responses for any execution order:

```kotlin
val apolloClient = ApolloClient.Builder()
  .networkTransport(MapTestNetworkTransport())
  .build()

apolloClient.registerTestResponse(
  GetUserQuery("1"),
  GetUserQuery.Data { user = buildUser { name = "Jane" } }
)
apolloClient.registerTestResponse(
  GetUserQuery("2"),
  GetUserQuery.Data { user = buildUser { name = "Bob" } }
)
```

## Apollo Debug Server

The debug server exposes the normalized cache to the Android Studio plugin's cache viewer. Android only.

### Setup

Add as a debug-only dependency:

```kotlin
debugImplementation("com.apollographql.apollo:apollo-debug-server:APOLLO_VERSION")
```

### Usage

```kotlin
// Register your client (optionally with a name)
ApolloDebugServer.registerApolloClient(apolloClient, "main")

// Unregister when done
ApolloDebugServer.unregisterApolloClient(apolloClient)
```

The Android Studio plugin connects via adb to browse and search cache records.

## Ground rules

- PREFER `TestNetworkTransport` for unit tests that do not need HTTP-level assertions.
- PREFER `MockServer` for integration tests that verify HTTP behavior (headers, retries).
- ALWAYS enable `generateDataBuilders` when writing tests to avoid hand-crafting JSON.
- ALWAYS call `mockServer.stop()` in test teardown.
