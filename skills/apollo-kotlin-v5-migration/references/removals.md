# Removals and deprecations sweep

A short list of v4 things that simply don't exist in v5 anymore. After applying the larger migrations (cache, websockets, http cache, nullability, data builders, compiler plugins), the items below are usually the last loose ends.

## `apollo-idling-resource` artifact — removed

Used in v4 for Espresso IdlingResource integration. The artifact is gone in v5 with no in-tree replacement.

```kotlin
// Remove from dependencies
implementation("com.apollographql.apollo:apollo-idling-resource")
```

Alternatives:

- Use Espresso's `IdlingResource` directly with a counter incremented in an `ApolloInterceptor`.
- Use Compose UI tests' `waitUntil` / `waitForIdle` if you're on Compose UI.
- Use `kotlinx.coroutines.test` schedulers in unit tests rather than relying on idling at all.

## `downloadApolloSchema` task — removed

Replaced by the per-service `introspection { ... }` block; see [gradle-plugin.md](gradle-plugin.md#downloadapolloschema-task-removed).

## `apollo-gradle-plugin-external` — removed

Replaced by `apollo-gradle-plugin` with classloader isolation; see [gradle-plugin.md](gradle-plugin.md#swap-apollo-gradle-plugin-external--apollo-gradle-plugin).

## `apollo-http-cache` — deprecated

Use OkHttp's cache + `enablePostCaching`; see [http-cache.md](http-cache.md).

## `apollo-normalized-cache` (and `-sqlite`) — moved

Use `com.apollographql.cache:normalized-cache(-sqlite)`; see [normalized-cache.md](normalized-cache.md).

## `com.apollographql.apollo.network.ws.*` — deprecated

Use `com.apollographql.apollo.network.websocket.*`; see [websockets.md](websockets.md).

## `operationOutputGenerator` / `operationIdGenerator` — removed

Use `ApolloCompilerPlugin` + `registerOperationIdsGenerator`; see [compiler-plugin.md](compiler-plugin.md).

## `@nonnull` (client directive) — error

Use `@semanticNonNull` + `@catch`; see [nullability.md](nullability.md).

## `ApolloStore` / `.store(...)` — renamed

Now `CacheManager` / `.cacheManager(...)`; see [normalized-cache.md](normalized-cache.md#api-renames).

## `storePartialResponses(true)` — removed

Partial responses are the default; just delete the call.

## `webSocketReopenWhen` — removed

Use `retryOnErrorInterceptor`; see [websockets.md](websockets.md#retry-websocketreopenwhen--retryonerrorinterceptor).
