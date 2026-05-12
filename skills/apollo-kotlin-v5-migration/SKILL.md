---
name: apollo-kotlin-v5-migration
description: >
  Migrate an Android, JVM, or Kotlin Multiplatform app from Apollo Kotlin v4 to v5. Use this skill when:
  (1) the user mentions upgrading, migrating, or moving to Apollo Kotlin 5 / v5 / 5.0,
  (2) the user is on Apollo Kotlin v4 (group `com.apollographql.apollo`, version `4.x`) and wants the latest,
  (3) the user hits compile errors after bumping to 5.0 (deprecated/removed APIs around `webSocketEngine`, `webSocketReopenWhen`, `apollo-http-cache`, `apollo-idling-resource`, `apollo-gradle-plugin-external`, `operationOutputGenerator`, `operationIdGenerator`, `downloadApolloSchema`, `@nonnull`, the bundled normalized cache, `ApolloStore`, `.store(...)`, data builders),
  (4) the user wants to adopt the new normalized cache, the rewritten WebSocket stack, `@semanticNonNull` + `@catch`, or `ApolloCompilerPlugin`.
license: MIT
compatibility: Apollo Kotlin v4.x → v5.0; JVM 8+, Kotlin 1.9+, Gradle 8+, Android/JVM/Kotlin Multiplatform projects.
metadata:
  author: apollographql
  version: "1.0.0"
allowed-tools: Bash(./gradlew:*) Bash(gradle:*) Bash(./scripts/list-apollo-kotlin-versions.sh:*) Bash(./scripts/list-apollo-kotlin-normalized-cache-versions.sh:*) Read Write Edit Glob Grep WebFetch
---

# Apollo Kotlin v4 → v5 Migration Guide

Apollo Kotlin 5.0 ships a rewritten WebSocket stack, a new normalized cache published as a separate library, classloader-isolated Gradle plugin, stricter nullability handling via `@semanticNonNull` + `@catch`, and restructured data builders. Several v4 APIs have been removed outright. This skill walks Claude through identifying v4 usage in the user's app and applying the correct fixes one area at a time.

The upstream reference is the [Apollo Kotlin 5.0 migration guide](https://www.apollographql.com/docs/kotlin/v5/migration/5.0). When in doubt about a detail not covered here, fetch that page or the linked sub-guides.

## Process

Follow this order. Earlier steps unblock later ones (e.g. you can't compile to find runtime call-site errors until the Gradle plugin coordinates are right).

If the user is on v3 or earlier (group `com.apollographql.apollo3` or `com.apollographql.apollo` at `3.x`/`2.x`), they must migrate to v4 first using the [v3 → v4 migration guide](https://www.apollographql.com/docs/kotlin/migration/4.0); this skill only covers the v4 → v5 step.

- [ ] **Inventory** — Confirm the user is on v4 and capture which v4 features they actually use (cache? subscriptions? HTTP cache? data builders? `@nonnull`? custom compiler plugin?). Grep the repo before touching anything; the migration cost depends entirely on what they use.
- [ ] **Bump versions and plugin coordinates** — See [references/gradle-plugin.md](references/gradle-plugin.md). Use the latest 5.x; run [scripts/list-apollo-kotlin-versions.sh](scripts/list-apollo-kotlin-versions.sh) to discover it.
- [ ] **Migrate the normalized cache** (if the user uses it) — See [references/normalized-cache.md](references/normalized-cache.md). This is the biggest single change and has its own dedicated upstream guide; do it as a focused pass.
- [ ] **Migrate WebSockets / subscriptions** (if any) — See [references/websockets.md](references/websockets.md).
- [ ] **Migrate HTTP cache** (if used) — See [references/http-cache.md](references/http-cache.md).
- [ ] **Replace `@nonnull` with `@semanticNonNull` + `@catch`** (if used) — See [references/nullability.md](references/nullability.md).
- [ ] **Update data builders / test code** (if used) — See [references/data-builders.md](references/data-builders.md).
- [ ] **Update custom compiler plugins / persisted query setup** (if any) — See [references/compiler-plugin.md](references/compiler-plugin.md).
- [ ] **Sweep removals** — Remove `apollo-idling-resource`. Replace `downloadApolloSchema` invocations. See [references/removals.md](references/removals.md).
- [ ] **Compile, run tests, smoke test** the app. Iterate on remaining errors.

## Inventory commands

Before editing, find what's actually in use. Most users won't touch every area.

```bash
# Apollo dependencies and plugin in use
rg -n "com\.apollographql\.apollo|com\.apollographql\.cache" --type gradle --type kotlin

# v4-only APIs that need migration:
rg -nw "apollo-gradle-plugin-external|apollo-http-cache|apollo-idling-resource"
rg -nw "webSocketEngine|webSocketReopenWhen|webSocketServerUrl"
rg -nw "operationOutputGenerator|operationIdGenerator|downloadApolloSchema"
rg -nw "ApolloStore|\.store\(|storePartialResponses"
rg -n "@nonnull"
rg -nw "buildCat|buildData|Data \{|FakeResolver"   # heuristic for data builders
rg -n "com\.apollographql\.apollo\.cache\.normalized"
rg -n "com\.apollographql\.apollo\.network\.ws[^a-zA-Z]"
```

Anything that matches → flag it for migration. Anything that doesn't → skip the corresponding section.

## Reference files

- [Gradle plugin](references/gradle-plugin.md) — plugin id/coordinate change, removal of `operationOutputGenerator`/`operationIdGenerator`/`downloadApolloSchema`.
- [Normalized cache](references/normalized-cache.md) — moving to the new `com.apollographql.cache:normalized-cache` library, `ApolloStore` → `CacheManager`, suspending store APIs.
- [WebSockets](references/websockets.md) — `com.apollographql.apollo.network.ws` → `com.apollographql.apollo.network.websocket`, `subscriptionNetworkTransport`, graphql-ws default, `retryOnErrorInterceptor`.
- [HTTP cache](references/http-cache.md) — `apollo-http-cache` → OkHttp cache + `enablePostCaching`.
- [Nullability](references/nullability.md) — `@nonnull` → `@semanticNonNull` + `@catch`.
- [Data builders](references/data-builders.md) — new `builder` package, explicit `FakeResolver`/`customScalarAdapters`, fragment builders, JSON-domain `FakeResolver`.
- [Compiler plugin](references/compiler-plugin.md) — `ApolloCompilerPlugin` + `ServiceLoader`.
- [Removals](references/removals.md) — `apollo-idling-resource`, `downloadApolloSchema`, deprecated `external` plugin.

## Scripts

- [list-apollo-kotlin-versions.sh](scripts/list-apollo-kotlin-versions.sh) — list available Apollo Kotlin tags (use to pick the latest 5.x).
- [list-apollo-kotlin-normalized-cache-versions.sh](scripts/list-apollo-kotlin-normalized-cache-versions.sh) — list versions of the new normalized cache library.

## Key rules

- **Pin to a single 5.x version.** Don't mix v4 and v5 artifacts; the package paths and plugin coordinates changed.
- **Cache is a separate dependency now.** `com.apollographql.apollo:apollo-normalized-cache` does not exist in v5 — it's `com.apollographql.cache:normalized-cache` with its own versioning.
- **Don't rely on bytecode shimming.** v4's `apollo-gradle-plugin-external` (R8 relocation) is replaced by classloader isolation in v5's `apollo-gradle-plugin`. If a v4 build needed `external` to coexist with another tool, retest after the swap — the conflict may simply be gone.
- **Migration is mechanical but layered.** Bumping the version will surface most issues at compile time; fix them in the order above to avoid chasing cascading errors.
- **Existing on-device caches are invalidated.** Both the new normalized cache (SQLite schema change) and the HTTP cache (key change) start empty after upgrading. Don't treat this as a regression; communicate it to users if relevant.
