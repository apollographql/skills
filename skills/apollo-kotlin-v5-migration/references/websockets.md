# WebSockets / subscriptions migration

The WebSocket stack was rewritten. Classes in `com.apollographql.apollo.network.ws` are deprecated; use `com.apollographql.apollo.network.websocket` (note: `websocket`, one word, no separator). The builder shorthand methods on `ApolloClient.Builder` for configuring the WebSocket transport were removed in favor of an explicit `subscriptionNetworkTransport(...)`. The default protocol is now `graphql-ws`. Retry logic moved to `retryOnErrorInterceptor`.

## Update imports

```kotlin
// Before
import com.apollographql.apollo.network.ws.AppSyncWsProtocol
import com.apollographql.apollo.network.ws.GraphQLWsProtocol
import com.apollographql.apollo.network.ws.SubscriptionWsProtocol
import com.apollographql.apollo.network.ws.WebSocketNetworkTransport

// After
import com.apollographql.apollo.network.websocket.AppSyncWsProtocol
import com.apollographql.apollo.network.websocket.GraphQLWsProtocol
import com.apollographql.apollo.network.websocket.SubscriptionsWsProtocol
import com.apollographql.apollo.network.websocket.WebSocketNetworkTransport
```

Note the rename `SubscriptionWsProtocol` (singular) → `SubscriptionsWsProtocol` (plural). This is the legacy `subscriptions-transport-ws` ("transport-ws") protocol; if you're not pinned to it, drop it entirely — v5 defaults to `graphql-ws`.

## Replace shorthand builder methods

The `ApolloClient.Builder` no longer exposes `webSocketEngine(...)` / `webSocketIdleTimeoutMillis(...)` / `wsProtocol(...)` directly. Configure a `WebSocketNetworkTransport` and pass it via `subscriptionNetworkTransport(...)`.

**Before:**
```kotlin
val apolloClient = ApolloClient.Builder()
    .serverUrl("https://example.com/graphql")
    .webSocketServerUrl("wss://example.com/subscriptions")
    .webSocketEngine(myWebSocketEngine)
    .build()
```

**After:**
```kotlin
val apolloClient = ApolloClient.Builder()
    .serverUrl("https://example.com/graphql")
    .subscriptionNetworkTransport(
        WebSocketNetworkTransport.Builder()
            .serverUrl("wss://example.com/subscriptions")
            .webSocketEngine(myWebSocketEngine)
            .build()
    )
    .build()
```

## Default protocol changed to graphql-ws

If you previously specified `GraphQLWsProtocol` explicitly, you can drop it — it's the default. Keep an explicit `WebSocketNetworkTransport.Builder()` though; you still need it to set `serverUrl` and any engine options.

```kotlin
// Before — explicit graphql-ws
val apolloClient = ApolloClient.Builder()
    .protocol(GraphQLWsProtocol.Factory())
    .build()

// After — graphql-ws is the default
val apolloClient = ApolloClient.Builder()
    .subscriptionNetworkTransport(
        WebSocketNetworkTransport.Builder()
            .serverUrl(url)
            .build()  // defaults to GraphQLWsProtocol
    )
    .build()
```

## Legacy `transport-ws` (`subscriptions-transport-ws`)

If your server still speaks the legacy protocol:

```kotlin
val apolloClient = ApolloClient.Builder()
    .subscriptionNetworkTransport(
        WebSocketNetworkTransport.Builder()
            .serverUrl(url)
            .wsProtocol(SubscriptionsWsProtocol())
            .build()
    )
    .build()
```

## Retry: `webSocketReopenWhen` → `retryOnErrorInterceptor`

Connection retry logic is no longer a builder method; it's an interceptor that can also see non-subscription operations, so gate on `Subscription<*>` if you only want to retry subscriptions.

**Before:**
```kotlin
val apolloClient = ApolloClient.Builder()
    .webSocketServerUrl("https://localhost:8080/subscriptions")
    .webSocketReopenWhen { e, attempt ->
      delay(2.0.pow(attempt.toDouble()).toLong())
      true
    }
    .build()
```

**After:**
```kotlin
val apolloClient = ApolloClient.Builder()
    .subscriptionNetworkTransport(
        WebSocketNetworkTransport.Builder()
            .serverUrl("wss://localhost:8080/subscriptions")
            .build()
    )
    .retryOnErrorInterceptor(RetryOnErrorInterceptor { context ->
      if (context.request.operation is Subscription<*>) {
        delay(2.0.pow(context.attempt.toDouble()).toLong())
        true
      } else {
        false
      }
    })
    .build()
```

## AppSync

`AppSyncWsProtocol` exists in the new package and behaves the same way — just update the import and wrap it in a `WebSocketNetworkTransport.Builder()` like any other protocol.
