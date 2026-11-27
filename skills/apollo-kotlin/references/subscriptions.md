# Subscriptions

This reference covers subscription transport configuration beyond the basics in [Operations](operations.md).

## WebSocket transport

Configure WebSocket subscriptions with `WebSocketNetworkTransport`:

```kotlin
val apolloClient = ApolloClient.Builder()
    .serverUrl("https://your.domain/graphql")
    .subscriptionNetworkTransport(
        WebSocketNetworkTransport.Builder()
            .serverUrl("https://your.domain/graphql")
            .build()
    )
    .build()
```

Both `https://` and `wss://` protocols work. Internally `wss://` is mapped to `https://`.

## WebSocket protocols

The default protocol is `subscriptions-transport-ws` via `SubscriptionWsProtocol`, which is no longer actively maintained. Use `graphql-ws` via `GraphQLWsProtocol` for new projects:

| Subprotocol | Class |
|---|---|
| subscriptions-transport-ws | `SubscriptionWsProtocol` (default, not maintained) |
| graphql-ws | `GraphQLWsProtocol` (recommended) |
| appsync | `AppSyncWsProtocol` |

```kotlin
val apolloClient = ApolloClient.Builder()
    .serverUrl("https://your.domain/graphql")
    .subscriptionNetworkTransport(
        WebSocketNetworkTransport.Builder()
            .protocol(GraphQLWsProtocol())
            .serverUrl("https://your.domain/graphql")
            .build()
    )
    .build()
```

## HTTP subscriptions

For servers that support chunked multipart responses, use `HttpNetworkTransport`:

```kotlin
val apolloClient = ApolloClient.Builder()
    .subscriptionNetworkTransport(
        HttpNetworkTransport.Builder()
            .serverUrl("https://your.domain/graphql")
            .build()
    )
    .build()
```

## Authentication

Pass auth tokens in the WebSocket connection payload:

```kotlin
WebSocketNetworkTransport.Builder()
    .protocol(
        GraphQLWsProtocol(
            connectionPayload = {
                mapOf("Authorization" to "Bearer $token")
            }
        )
    )
    .serverUrl("https://your.domain/graphql")
    .build()
```

## Error handling and retry

Network errors terminate the subscription `Flow`. Use `retryOnError` to automatically reconnect:

```kotlin
apolloClient.subscription(MessagesSubscription())
    .retryOnError { it.operation is Subscription }
    .toFlow()
    .collect { response ->
        val data = response.dataOrThrow()
    }
```

A single WebSocket is shared between all active subscriptions. When no subscription is active, the WebSocket closes after a configurable timeout.

## Termination

The coroutine scope that collects the subscription handles termination. Cancel the collecting coroutine or scope to close the subscription:

```kotlin
val job = launch {
    apolloClient.subscription(MessagesSubscription())
        .toFlow()
        .collect { /* handle data */ }
}

job.cancel()
```
