# Normalized cache migration

The normalized cache has moved out of the main Apollo Kotlin repo into a dedicated library: [apollographql/apollo-kotlin-normalized-cache](https://github.com/apollographql/apollo-kotlin-normalized-cache). It adds pagination support, expiration, garbage collection, trimming, and partial-result reads — but the upgrade requires touching dependency coordinates, package imports, the `ApolloClient` builder, and any custom `ApolloStore` usage.

For the full story, read the upstream [cache migration guide](https://www.apollographql.com/docs/kotlin/v5/caching/migration-guide/). This file summarizes the must-do steps; for any edge case not covered here, defer to the upstream guide.

## Dependency coordinates

```kotlin
// Before (v4)
implementation("com.apollographql.apollo:apollo-normalized-cache")
implementation("com.apollographql.apollo:apollo-normalized-cache-sqlite")

// After (v5)
implementation("com.apollographql.cache:normalized-cache:<version>")
implementation("com.apollographql.cache:normalized-cache-sqlite:<version>")
```

Find the latest version with [`scripts/list-apollo-kotlin-normalized-cache-versions.sh`](../scripts/list-apollo-kotlin-normalized-cache-versions.sh). The new library has its own version number and does not track Apollo Kotlin's version.

You also need to add the cache compiler plugin so the `cache()` extension and codegen are wired up — follow the upstream guide's "Setup" section.

## Package imports

```kotlin
// Before
import com.apollographql.apollo.cache.normalized.*
import com.apollographql.apollo.cache.normalized.api.*
import com.apollographql.apollo.cache.normalized.sql.SqlNormalizedCacheFactory

// After
import com.apollographql.cache.normalized.*
import com.apollographql.cache.normalized.api.*
import com.apollographql.cache.normalized.sql.SqlNormalizedCacheFactory
```

A repo-wide search-and-replace from `com.apollographql.apollo.cache.normalized` → `com.apollographql.cache.normalized` will handle the bulk of it.

## API renames

| v4                                 | v5                                                |
|------------------------------------|---------------------------------------------------|
| `ApolloStore` interface            | `CacheManager`                                    |
| `.store(...)` on `ApolloClient.Builder` | `.cacheManager(...)`                         |
| `apolloClient.apolloStore`         | `apolloClient.cacheManager`                       |
| `readOperation()` returning `D`    | `readOperation()` returning `ApolloResponse<D>`   |
| Synchronous store calls            | All store operations are `suspend` functions      |
| `storePartialResponses(true)`      | Remove — partial responses are the default       |

The `readOperation` change is the most disruptive: it now returns a full `ApolloResponse<D>` so partial cache reads can surface errors. Update call sites to read `response.data` (and check `response.errors`) instead of using the result directly as `D`.

All store operations being `suspend` means every direct cache access must move into a coroutine. If you had blocking helpers wrapped around `ApolloStore`, replace them with `runBlocking` only in tests; in production code, propagate the suspending nature up the call stack.

## Schema directive link

If you use cache directives in `extra.graphqls`:

```graphql
# Before
extend schema @link(url: "https://specs.apollo.dev/kotlin_labs/v0.3", import: ["@typePolicy", "@fieldPolicy"])

# After
extend schema @link(url: "https://specs.apollo.dev/cache/v0.4", import: ["@typePolicy", "@fieldPolicy"])
```

## On-device cache wipe

The SQLite schema changed. Existing user databases will auto-migrate but lose their cached data. This is a one-time event on first run after the upgrade — not a bug. Communicate it to end users if the cache holds something they'd notice missing.

## Verification

```bash
./gradlew generateApolloSources build
```

If the build fails on `ApolloStore`, `.store(`, or `kotlin_labs/v0.3` references after the rename, those are the leftover v4 references — fix them with the table above.
