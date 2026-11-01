# Caching

This reference covers HTTP caching and normalized caching in Apollo Kotlin.

## HTTP cache

The HTTP cache stores raw HTTP responses on disk. It is simpler to set up but does not deduplicate data or enable reactive UI updates.

Available on Android and JVM only.

### HTTP cache setup

```kotlin
dependencies {
  implementation("com.apollographql.apollo:apollo-http-cache:APOLLO_VERSION")
}
```

On Android API < 26, enable [core library desugaring](https://developer.android.com/studio/write/java8-support#library-desugaring).

```kotlin
val apolloClient = ApolloClient.Builder()
  .serverUrl("https://your.domain/graphql")
  .httpCache(
    directory = File(pathToCacheDirectory),
    maxSize = 100 * 1024 * 1024
  )
  .build()
```

### HTTP cache policies

```kotlin
val response = apolloClient.query(query)
  .httpFetchPolicy(HttpFetchPolicy.CacheFirst) // default
  .execute()
```

Available policies: `CacheFirst`, `CacheOnly`, `NetworkFirst`, `NetworkOnly`.

Set a global or per-query expiration:

```kotlin
// Global
ApolloClient.Builder()
  .httpCache(directory = cacheDir, maxSize = 100 * 1024 * 1024)
  .httpExpireTimeout(60 * 60 * 1000) // 1 hour
  .build()

// Per query
apolloClient.query(query)
  .httpExpireTimeout(60 * 60 * 1000)
  .execute()
```

Skip caching for a specific query with `.httpDoNotStore(true)`.

Clear the HTTP cache with `apolloClient.httpCache.clearAll()`.

## Normalized cache

Use a normalized cache when:

- You need offline support or fast startup.
- Multiple screens depend on the same objects.
- You want consistent updates after mutations.
- You want reactive UI that updates when cached data changes.

The normalized cache breaks responses into individual objects keyed by cache ID, deduplicating shared objects across queries.

### Normalized cache setup

Add the dependency for in-memory cache, SQLite cache, or both:

```kotlin
dependencies {
  // In-memory cache
  implementation("com.apollographql.apollo:apollo-normalized-cache:APOLLO_VERSION")
  // SQLite persistent cache
  implementation("com.apollographql.apollo:apollo-normalized-cache-sqlite:APOLLO_VERSION")
}
```

Configure the cache on `ApolloClient.Builder` using the `.normalizedCache()` extension function:

```kotlin
// In-memory cache
val cacheFactory = MemoryCacheFactory(maxSizeBytes = 10 * 1024 * 1024)

val apolloClient = ApolloClient.Builder()
  .serverUrl("https://your.domain/graphql")
  .normalizedCache(cacheFactory)
  .build()
```

SQLite cache (platform-specific driver):

```kotlin
// Android
val sqlCacheFactory = SqlNormalizedCacheFactory("apollo.db")
// JVM
val sqlCacheFactory = SqlNormalizedCacheFactory("jdbc:sqlite:apollo.db")
// iOS
val sqlCacheFactory = SqlNormalizedCacheFactory("apollo.db")

val apolloClient = ApolloClient.Builder()
  .serverUrl("https://your.domain/graphql")
  .normalizedCache(sqlCacheFactory)
  .build()
```

Chain memory and SQLite caches for fast reads with persistent storage:

```kotlin
val chainedFactory = MemoryCacheFactory(10 * 1024 * 1024)
  .chain(SqlNormalizedCacheFactory("apollo.db"))
```

Reads check each cache in order until a hit. Writes propagate to all caches.

### Fetch policies

The default fetch policy with a normalized cache is `FetchPolicy.CacheFirst`. Set it globally or per query:

```kotlin
// Global default
val apolloClient = ApolloClient.Builder()
  .serverUrl("https://your.domain/graphql")
  .normalizedCache(cacheFactory)
  .fetchPolicy(FetchPolicy.NetworkOnly)
  .build()

// Per query
val response = apolloClient.query(GetUserQuery(id))
  .fetchPolicy(FetchPolicy.NetworkFirst)
  .execute()
```

Available policies:
- `CacheFirst` — try cache, fall back to network
- `CacheOnly` — cache only, error on miss
- `NetworkFirst` — try network, fall back to cache
- `NetworkOnly` — always use network
- `CacheAndNetwork` — emit from cache then network (use `.toFlow()`, not `.execute()`)

Some policies emit multiple responses:
- `CacheFirst` and `NetworkFirst` emit 1 or 2 values
- `CacheAndNetwork` always emits 2 values

Use `.toFlow().collect { }` for multi-emission policies. `.execute()` filters to a single success response.

### Cache keys

For the normalized cache to deduplicate objects, configure cache keys using the `@typePolicy` directive. Place it in an `extra.graphqls` file alongside the schema:

```graphql
extend schema
@link(
  url: "https://specs.apollo.dev/kotlin_labs/v0.3",
  import: ["@typePolicy", "@fieldPolicy"]
)

extend type User @typePolicy(keyFields: "id")
extend type Book @typePolicy(keyFields: "isbn")
```

When a field takes cache key fields as arguments, declare `@fieldPolicy` so the cache can resolve objects without a network request:

```graphql
extend type Query @fieldPolicy(forField: "user", keyArgs: "id")
```

### Programmatic cache IDs

For more control, pass a `CacheKeyGenerator` and `CacheKeyResolver`:

```kotlin
val cacheKeyGenerator = object : CacheKeyGenerator {
  override fun cacheKeyForObject(
    obj: Map<String, Any?>,
    context: CacheKeyGeneratorContext
  ): CacheKey? {
    val id = obj["id"] as? String ?: return null
    val typename = context.field.type.rawType().name
    return CacheKey(typename, id)
  }
}

val apolloClient = ApolloClient.Builder()
  .serverUrl("https://your.domain/graphql")
  .normalizedCache(
    normalizedCacheFactory = cacheFactory,
    cacheKeyGenerator = cacheKeyGenerator,
    cacheResolver = cacheKeyResolver
  )
  .build()
```

### Watching the cache

Use `.watch()` to make the cache the single source of truth for the UI. The flow re-emits whenever cached fields used by the query change:

```kotlin
apolloClient.query(GetUserQuery(id))
  .watch()
  .collect { response ->
    val data = response.dataOrThrow()
    // Update UI — re-emitted on cache changes
  }
```

### Optimistic updates

Write expected data to the cache before the network response arrives:

```kotlin
apolloClient.mutation(UpdateUserMutation(id = "1", name = "New Name"))
  .optimisticUpdates(UpdateUserMutation.Data(
    updateUser = UpdateUserMutation.UpdateUser(id = "1", name = "New Name")
  ))
  .execute()
```

### Direct cache access

Read and write the cache directly via `apolloClient.apolloStore`:

```kotlin
// Read
val data = apolloClient.apolloStore.readOperation(
  GetUserQuery(id = "1"),
  apolloClient.customScalarAdapters
)

// Write
apolloClient.apolloStore.writeOperation(
  GetUserQuery(id = "1"),
  data,
  apolloClient.customScalarAdapters
)

// Clear all entries
apolloClient.apolloStore.clearAll()
```

Fragment reads and writes require `generateFragmentImplementations.set(true)` in the Gradle config.

### Troubleshooting

Dump the cache for debugging:

```kotlin
val dump = apolloClient.apolloStore.dump()
println(NormalizedCache.prettifyDump(dump))
```

The Android Studio plugin includes a graphical normalized cache viewer.

## Ground rules

- PREFER the normalized cache over the HTTP cache for apps with shared data across screens.
- ALWAYS configure `@typePolicy` for types that appear in multiple queries.
- USE `.toFlow()` instead of `.execute()` with `CacheAndNetwork` or when watching.
- NEVER call `apolloClient.apolloStore` without a configured normalized cache — it throws.
