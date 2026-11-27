# Advanced features

This reference covers persisted queries, file uploads, query batching, and `@defer`.

## Persisted queries

Auto Persisted Queries (APQs) reduce request size by sending a hash instead of the full query string. Hashed queries also use HTTP `GET` by default, making them easier to cache at the edge.

Enable APQs on `ApolloClient`:

```kotlin
val apolloClient = ApolloClient.Builder()
    .serverUrl("https://your.domain/graphql")
    .autoPersistedQueries()
    .build()
```

Opt out per operation:

```kotlin
apolloClient.query(myQuery).enableAutoPersistedQueries(false).execute()
```

### Safelisting with persisted queries

For safelisting (requires GraphOS Router and Enterprise plan), generate an operation manifest:

```kotlin
apollo {
  service("service") {
    packageName.set("com.example")
    operationManifestFormat.set("persistedQueryManifest")
  }
}
```

The manifest is generated at `build/generated/manifest/apollo/$serviceName/persistedQueryManifest.json` during code generation. Publish it to GraphOS using Rover:

```bash
rover persisted-queries publish <GRAPH_ID>@<VARIANT> \
  --manifest ./build/generated/manifest/apollo/service/persistedQueryManifest.json
```

## File uploads

Apollo Kotlin supports file uploads via the [GraphQL multipart request specification](https://github.com/jaydenseric/graphql-multipart-request-spec).

Add the scalar mapping in Gradle:

```kotlin
apollo {
  service("service") {
    mapScalarToUpload("Upload")
  }
}
```

No adapter registration is needed. Create an `Upload` instance and pass it as a mutation variable:

```kotlin
// Android/JVM
val upload = File("path/to/file").toUpload("application/json")

// Multiplatform
val upload = DefaultUpload.Builder()
    .fileName("filename.txt")
    .content { sink -> source.use { sink.writeAll(it) } }
    .build()

val response = apolloClient.mutation(UploadFileMutation(file = upload)).execute()
```

Neither Apollo Router Core nor GraphOS Router support `multipart/form-data` uploads. For production, consider purpose-built upload tools.

## Query batching

Batch multiple operations into a single HTTP request to reduce network round trips:

```kotlin
val apolloClient = ApolloClient.Builder()
    .serverUrl("https://your.domain/graphql")
    .httpBatching()
    .build()
```

Configure the batch interval and max size:

```kotlin
.httpBatching(
    batchIntervalMillis = 50,
    maxBatchSize = 20
)
```

Opt out per operation:

```kotlin
apolloClient.query(myQuery).canBeBatched(false).execute()
```

Batching adds latency equal to the batch interval. Operations requiring minimum latency should opt out.

## @defer

The `@defer` directive enables incremental delivery of slower fields. Apply it to inline fragments:

```graphql
query PersonQuery($personId: ID!) {
  person(id: $personId) {
    id
    firstName
    ... on User @defer {
      friends {
        id
      }
    }
  }
}
```

Use `toFlow()` to collect incremental emissions:

```kotlin
apolloClient.query(PersonQuery(id))
    .toFlow()
    .collect { response ->
        val person = response.dataOrThrow().person
    }
```

Each emission contains progressively more data as deferred fragments resolve. `@defer` is not compatible with `responseBased` codegen models.
