# Compiler plugin migration

`apollo-compiler` remains experimental in v5. If you had a custom compiler plugin in v4, it almost certainly needs updating — the host APIs (`ApolloCompilerPlugin`, `ApolloCompilerPluginEnvironment`, `ApolloCompilerRegistry`) evolved, and the plugin is now loaded via Java's `ServiceLoader` from an isolated classloader.

Refer to the upstream [compiler plugins page](https://www.apollographql.com/docs/kotlin/v5/advanced/compiler-plugins) for the current full surface; this file covers the most common reason apps need a compiler plugin in v5: replacing v4's removed `operationOutputGenerator` / `operationIdGenerator` (used for persisted queries).

## When you need this

Add an `ApolloCompilerPlugin` if you previously called any of:

- `service { operationIdGenerator.set(...) }`
- `service { operationOutputGenerator.set(...) }`
- Any other v4 plugin-style hook that's been removed.

If you don't use these, you don't need a compiler plugin.

## Minimal plugin module

Create a separate Gradle module (e.g. `apollo-compiler-plugin/`) that:

1. Targets the JVM (it runs at build time inside the Gradle daemon, not on Android).
2. Depends on `com.apollographql.apollo:apollo-compiler:5.x` (`compileOnly` is fine).
3. Implements `ApolloCompilerPlugin`.
4. Registers the implementation with `ServiceLoader`.

```kotlin
// build.gradle.kts
plugins {
  kotlin("jvm")
}

dependencies {
  compileOnly("com.apollographql.apollo:apollo-compiler:5.0.0")
}
```

```kotlin
// src/main/kotlin/.../MyPlugin.kt
package com.example.apollo.plugin

import com.apollographql.apollo.compiler.ApolloCompilerPlugin
import com.apollographql.apollo.compiler.ApolloCompilerPluginEnvironment
import com.apollographql.apollo.compiler.ApolloCompilerRegistry
import com.apollographql.apollo.compiler.OperationId

class MyPlugin : ApolloCompilerPlugin {
  override fun beforeCompilationStep(
      environment: ApolloCompilerPluginEnvironment,
      registry: ApolloCompilerRegistry,
  ) {
    registry.registerOperationIdsGenerator { operations ->
      operations.map { OperationId(it.source.md5(), it.name) }
    }
  }
}
```

```
src/main/resources/META-INF/services/com.apollographql.apollo.compiler.ApolloCompilerPlugin
```
…containing one line:
```
com.example.apollo.plugin.MyPlugin
```

## Wire the plugin into your service

In your app/library module:

```kotlin
apollo {
  service("service") {
    packageName.set("com.example")
    plugin(project(":apollo-compiler-plugin"))
  }
}
```

The plugin module runs inside the compiler's isolated classloader, which is why the v4 closure-based callbacks no longer work and a real artifact is required.

## Persisted queries

If your reason for migrating was persisted queries specifically, the dedicated upstream guide ([persisted queries](https://www.apollographql.com/docs/kotlin/v5/advanced/persisted-queries)) shows the full end-to-end flow including registering the operations with the server.
