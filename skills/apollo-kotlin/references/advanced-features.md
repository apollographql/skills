# Advanced Features

This reference covers HTTP interceptors, authentication, persisted queries, file uploads, query batching, subscriptions configuration, and network monitoring.

## HTTP interceptors

Apollo Kotlin provides a multiplatform `HttpInterceptor` interface for modifying HTTP requests and responses.

```kotlin
class AuthInterceptor(private val tokenProvider: () -> String) : HttpInterceptor {
  override suspend fun intercept(
    request: HttpRequest,
    chain: HttpInterceptorChain
  ): HttpResponse {
    val token = tokenProvider()
    return chain.proceed(
      request.newBuilder()
        .addHeader("Authorization", "Bearer $token")
        .build()
    )
  }
}

val apolloClient = ApolloClient.Builder()
  .serverUrl("https://your.domain/graphql")
  .addHttpInterceptor(AuthInterceptor { getToken() })
  .build()
```

On Android/JVM, you can also use OkHttp interceptors:

```kotlin
val okHttpClient = OkHttpClient.Builder()
  .addInterceptor(loggingInterceptor)
  .build()

val apolloClient = ApolloClient.Builder()
  .serverUrl("https://your.domain/graphql")
  .okHttpClient(okHttpClient)
  .build()
```

### GraphQL-level interceptors

`ApolloInterceptor` operates at the GraphQL level (after parsing). It works with `Flow<ApolloResponse>`:

```kotlin
class MyInterceptor : ApolloInterceptor {
  override fun <D : Operation.Data> intercept(
    request: ApolloRequest<D>,
    chain: ApolloInterceptorChain
  ): Flow<ApolloResponse<D>> {
    return chain.proceed(request)
  }
}

ApolloClient.Builder()
  .addInterceptor(MyInterceptor())
```

## Authentication

### HTTP authentication

Use an `HttpInterceptor` that refreshes tokens on 401 responses:

```kotlin
class AuthInterceptor(private val tokenProvider: TokenProvider) : HttpInterceptor {
  override suspend fun intercept(
    request: HttpRequest,
    chain: HttpInterceptorChain
  ): HttpResponse {
    val response = chain.proceed(
      request.newBuilder()
        .addHeader("Authorization", "Bearer ${tokenProvider.current()}")
        .build()
    )
    if (response.statusCode == 401) {
      tokenProvider.refresh()
      return chain.proceed(
        request.newBuilder()
          .addHeader("Authorization", "Bearer ${tokenProvider.current()}")
          .build()
      )
    }
    return response
  }
}
```

### WebSocket authentication

Pass credentials via `connectionPayload`:

```kotlin
val wsTransport = WebSocketNetworkTransport.Builder()
  .serverUrl("wss://your.domain/graphql")
  .protocol(SubscriptionWsProtocol.Factory(
    connectionPayload = { mapOf("authToken" to getToken()) }
  ))
  .build()

ApolloClient.Builder()
  .subscriptionNetworkTransport(wsTransport)
```

Add headers to the WebSocket handshake with `.addHeader("Authorization", "Bearer $token")` on the transport builder.

## Persisted queries

### Auto Persisted Queries (APQ)

APQ sends a hash instead of the full query body. The server requests the full query on cache miss.

```kotlin
val apolloClient = ApolloClient.Builder()
  .serverUrl("https://your.domain/graphql")
  .autoPersistedQueries()
  .build()
```

Disable for specific operations:

```kotlin
apolloClient.query(MyQuery())
  .enableAutoPersistedQueries(false)
  .execute()
```

### Persisted query manifest

Generate a manifest for safelisting with GraphOS Router:

```kotlin
apollo {
  service("service") {
    operationManifestFormat.set("persistedQueryManifest")
  }
}
```

The manifest is output to `build/generated/manifest/apollo/$serviceName/persistedQueryManifest.json`.

## File uploads

### Setup

Map the `Upload` scalar in Gradle:

```kotlin
apollo {
  service("service") {
    mapScalarToUpload("Upload")
  }
}
```

### Creating uploads

```kotlin
// JVM
val upload = File("/path/to/file.jpg").toUpload("image/jpeg")

// Multiplatform
val upload = DefaultUpload.Builder()
  .content("file content")
  .contentType("text/plain")
  .fileName("file.txt")
  .build()
```

### Executing

```kotlin
val response = apolloClient.mutation(
  UploadFileMutation(file = upload)
).execute()
```

## Query batching

Combine multiple operations into a single HTTP request:

```kotlin
val apolloClient = ApolloClient.Builder()
  .serverUrl("https://your.domain/graphql")
  .httpBatching(
    batchIntervalMillis = 10,
    maxBatchSize = 10
  )
  .build()
```

Exclude a specific operation from batching:

```kotlin
apolloClient.query(MyQuery())
  .canBeBatched(false)
  .execute()
```

## Subscription protocols

Configure WebSocket subscriptions with the appropriate protocol:

```kotlin
val wsTransport = WebSocketNetworkTransport.Builder()
  .serverUrl("wss://your.domain/graphql")
  .protocol(GraphQLWsProtocol.Factory())  // graphql-ws (recommended)
  // or: .protocol(SubscriptionWsProtocol.Factory())  // subscriptions-transport-ws (legacy)
  // or: .protocol(AppSyncWsProtocol.Factory(...))  // AWS AppSync
  .build()

val apolloClient = ApolloClient.Builder()
  .serverUrl("https://your.domain/graphql")
  .subscriptionNetworkTransport(wsTransport)
  .build()
```

### WebSocket error handling

Handle connection-level errors with automatic reconnection:

```kotlin
ApolloClient.Builder()
  .webSocketReopenWhen { exception, attempt ->
    delay(2.0.pow(attempt.toInt()).toLong() * 1000)
    true // return true to reconnect
  }
```

Handle per-subscription errors with `retryWhen` on the Flow.

## @defer

Use `@defer` on inline fragments for incremental delivery of slow-resolving fields:

```graphql
query GetUser($id: ID!) {
  user(id: $id) {
    name
    ... on User @defer {
      expensiveField
    }
  }
}
```

Collect incremental payloads with `.toFlow()`:

```kotlin
apolloClient.query(GetUserQuery(id))
  .toFlow()
  .collect { response ->
    // First emission: name populated, expensiveField may be null
    // Second emission: expensiveField populated
  }
```

Not compatible with `responseBased` codegen.

## Client awareness

Send client identification headers to GraphOS for per-client operation metrics:

```kotlin
ApolloClient.Builder()
  .addHttpInterceptor(
    ApolloClientAwarenessInterceptor("my-app", "1.0.0")
  )
```

## Network monitoring (experimental)

Detect network availability and fail fast when offline:

```kotlin
// Android
val networkMonitor = NetworkMonitor(context)

val apolloClient = ApolloClient.Builder()
  .serverUrl("https://your.domain/graphql")
  .retryOnErrorInterceptor(RetryOnErrorInterceptor(networkMonitor))
  .failFastIfOffline(true)
  .build()
```

## Ground rules

- ALWAYS use `HttpInterceptor` (not OkHttp interceptors) for multiplatform projects.
- PREFER APQ for production apps to reduce bandwidth.
- PREFER `GraphQLWsProtocol` for new WebSocket subscription setups.
- NEVER send authentication tokens in query parameters — use headers or `connectionPayload`.
