# HTTP cache migration

The `apollo-http-cache` artifact is deprecated. Apollo Kotlin v5 leans on OkHttp's native HTTP cache combined with `enablePostCaching` on `DefaultHttpRequestComposer` so that POST GraphQL requests can be cached at the HTTP layer.

This means: remove the `apollo-http-cache` dependency, drop `.httpCache(...)` on `ApolloClient.Builder`, and configure an OkHttp `Cache` on the `OkHttpClient` you pass through `DefaultHttpEngine`.

## Setup change

**Before (v4):**
```kotlin
val apolloClient = ApolloClient.Builder()
    .serverUrl(serverUrl)
    .httpCache(directory = "http_cache", maxSize = 10_000_000)
    .build()
```

**After (v5):**
```kotlin
val apolloClient = ApolloClient.Builder()
    .networkTransport(
        HttpNetworkTransport.Builder()
            .httpRequestComposer(
                DefaultHttpRequestComposer(
                    serverUrl = serverUrl,
                    enablePostCaching = true,
                )
            )
            .httpEngine(
                DefaultHttpEngine {
                    OkHttpClient.Builder()
                        .cache(
                            Cache(
                                directory = File(application.cacheDir, "http_cache"),
                                maxSize = 10_000_000,
                            )
                        )
                        .build()
                }
            )
            .build()
    )
    .build()
```

## Cache policy → `Cache-Control` headers

In v4, the Apollo HTTP cache had its own fetch policies (`NetworkFirst`, `CacheFirst`, `NetworkOnly`, etc.) and a custom `httpExpireTimeout()`. In v5, behavior is driven by standard HTTP `Cache-Control` headers (server-supplied, or stamped on requests via interceptors). There is no direct equivalent for `NetworkFirst` or `httpExpireTimeout()` — if you relied on them, either:

- have the server emit `Cache-Control` headers tuned for your use case, or
- add an OkHttp interceptor that rewrites request/response `Cache-Control` to match the old behavior, or
- consider whether the normalized cache better fits the pattern you wanted.

## Cache key change

The way cache keys are computed changed. Any existing on-disk HTTP cache from a v4 install will not be reused — it stays on disk but new requests miss and re-fetch. If disk usage is a concern, point the new cache at a different directory or wipe the old one on first launch.

## Don't forget the runtime dep

You no longer need `apollo-http-cache` in `dependencies`:

```kotlin
// Remove
implementation("com.apollographql.apollo:apollo-http-cache")
```

`apollo-runtime` and `okhttp` are sufficient.
