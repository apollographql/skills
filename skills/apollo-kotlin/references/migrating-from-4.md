# Migration

## Migrating from Apollo Kotlin 3 to 4

If the user is on v3 (group `com.apollographql.apollo3`) or v2 (group `com.apollographql.apollo` at `2.x`), they must migrate to v4.

Follow this order. Earlier steps unblock later ones.

### 1. Update Gradle plugin and dependencies

Change the group from `com.apollographql.apollo3` to `com.apollographql.apollo`:

```kotlin
// Before (v3)
plugins {
  id("com.apollographql.apollo3") version "3.x.x"
}
dependencies {
  implementation("com.apollographql.apollo3:apollo-runtime:3.x.x")
}

// After (v4)
plugins {
  id("com.apollographql.apollo") version "LATEST_V4"
}
dependencies {
  implementation("com.apollographql.apollo:apollo-runtime:LATEST_V4")
}
```

Run `scripts/list-apollo-kotlin-versions.sh` to find the latest v4.x version.

### 2. Update imports

Change all `com.apollographql.apollo3` package imports to `com.apollographql.apollo`:

```kotlin
// Before
import com.apollographql.apollo3.ApolloClient
import com.apollographql.apollo3.api.ApolloResponse

// After
import com.apollographql.apollo.ApolloClient
import com.apollographql.apollo.api.ApolloResponse
```

### 3. Build and fix remaining errors

Build the project. Most v4 APIs are source-compatible with v3. Key breaking changes:

- `ApolloCall.execute()` now returns a single `ApolloResponse` instead of throwing on errors. Check `response.exception` for fetch errors.
- `ApolloCall.toFlow()` replaces `.watch()` for subscriptions and multi-emission responses.
- `HttpCache` moved to `com.apollographql.apollo:apollo-http-cache`.
- `ApolloIdlingResource` is deprecated. Use `ApolloIdlingResource` from `apollo-testing-support` instead.
- `@nonnull` client directive replaced by `@catch` (experimental).

### 4. Review deprecated APIs

After a successful build, address deprecation warnings. The v4 deprecation messages include replacement suggestions.

For the full migration reference, see the [v3 to v4 migration guide](https://www.apollographql.com/docs/kotlin/migration/4.0).
