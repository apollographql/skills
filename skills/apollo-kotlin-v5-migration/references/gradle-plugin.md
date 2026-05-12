# Gradle plugin migration

Apollo Kotlin 5 moves the Gradle plugin from R8-based dependency relocation to classloader isolation. This removes the need for a separate "external" plugin and changes the plugin id and dependency coordinate.

## Swap `apollo-gradle-plugin-external` → `apollo-gradle-plugin`

If the user previously used the external variant (which existed to avoid classpath clashes with other Gradle plugins), switch to the standard one.

**Before:**
```kotlin
implementation("com.apollographql.apollo:apollo-gradle-plugin-external:4.3.3")

plugins {
  id("com.apollographql.apollo.external")
}
```

**After:**
```kotlin
implementation("com.apollographql.apollo:apollo-gradle-plugin:5.0.0")

plugins {
  id("com.apollographql.apollo")
}
```

If the user was already on `com.apollographql.apollo` (not `external`), only the version bump is needed.

## `operationOutputGenerator` and `operationIdGenerator` are removed

The DSL methods were removed because the compiler now runs inside an isolated classloader and can no longer accept a `Closure`/lambda living in the build classpath. Use the `ApolloCompilerPlugin` ServiceLoader API instead.

**Before (v4):**
```kotlin
apollo {
  service("service") {
    operationIdGenerator.set(object : OperationIdGenerator {
      override fun apply(operationDocument: String, operationName: String) =
        operationDocument.md5()
      override val version: String = "v1"
    })
  }
}
```

**After (v5):** create an `ApolloCompilerPlugin` and register it via `META-INF/services`.

```kotlin
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

See [compiler-plugin.md](compiler-plugin.md) for the full plugin setup (service-loader file, build module wiring, etc.).

## `downloadApolloSchema` task removed

The standalone `downloadApolloSchema` task is gone. Configure the per-service `introspection` block instead and depend on the generated task name `download<ServiceName>ApolloSchemaFromIntrospection`.

**Before (v4):**
```kotlin
tasks.register("downloadSchema", com.apollographql.apollo.gradle.api.ApolloDownloadSchemaTask::class.java) {
  endpoint.set("https://example.com/graphql/endpoint")
  schema.set(file("src/main/graphql/schema.graphqls"))
}
```

**After (v5):**
```kotlin
apollo {
  service("service") {
    packageName.set("com.example")

    introspection {
      endpointUrl.set("https://example.com/graphql/endpoint")
      schemaFile.set(file("src/main/graphql/schema.graphqls"))
    }
  }
}

// Optional convenience alias
tasks.register("downloadSchema") {
  dependsOn("downloadServiceApolloSchemaFromIntrospection")
}
```

The generated task name is `download` + the service name (capitalized) + `ApolloSchemaFromIntrospection`. If the service is named `"github"`, the task is `downloadGithubApolloSchemaFromIntrospection`.

## Sanity check

After the swap, run:

```bash
./gradlew tasks --group=apollo
./gradlew generateApolloSources
```

If `generateApolloSources` fails referencing missing types from your generated code, you may also need to migrate the [normalized cache](normalized-cache.md), [data builders](data-builders.md), or [compiler plugins](compiler-plugin.md) before the build is green again.
