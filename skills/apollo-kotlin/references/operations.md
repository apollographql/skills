# Operations

This reference covers queries, mutations, subscriptions, and response handling.

## GraphQL files

- Place your operations in `.graphql` files under `src/main/graphql/` (or `src/commonMain/graphql/` for multiplatform).
- Name the operations with a prefix indicating their type, e.g., `GetUserQuery`, `UpdateUserMutation`, `OnMessageReceivedSubscription`.
- Keep one operation per `.graphql` file, and name it with the operation name, e.g. `GetUserQuery.graphql` for `GetUserQuery`.
- Fragments can stay in the same file as the operation, or be in separate files if used across multiple operations.

## Queries and Mutations

Use generated query classes and call them with `.execute()`.

```kotlin
suspend fun loadUser(id: String): User {
  val response = apolloClient.query(GetUserQuery(id)).execute()
  val data = response.dataOrThrow()
  return data.user.toDomain()
}
```

## Subscriptions

- For subscriptions, never use `.execute()` which can only accept one emission, instead use `toFlow()`.

```kotlin
fun observeMessages() {
  apolloClient.subscription(GetMessagesSubscription()).toFlow().collect { response ->
    val messages = response.dataOrThrow().messages
    // Update UI
  }
}
```

## Error handling

- Local (e.g. network, http, parsing, ...) errors are in `response.exception`.
- Errors from the server that are returned in the GraphQL response are in `response.errors`.
- Some `data` may be present even if there are `errors`, but `data` will be null if `exception` is present.

## Fragments

### Named fragments

Named fragments are shared across `.graphql` files and generate reusable data classes. Access fragment data via the `.fragmentName` property on the parent:

```kotlin
val user = response.dataOrThrow().user
val details = user.userDetails // generated from fragment UserDetails
```

### Inline fragments

Inline fragments handle polymorphic types (interfaces and unions). Access typed data via `.onTypeName`:

```kotlin
val hero = response.dataOrThrow().hero
when {
  hero.onHuman != null -> println("Human: ${hero.onHuman.height}")
  hero.onDroid != null -> println("Droid: ${hero.onDroid.primaryFunction}")
}
```

## Custom scalars

Map custom scalars to Kotlin types in the Gradle config. See [Setup](setup.md) for `mapScalar()` configuration.

Built-in shorthand mappers:

```kotlin
apollo {
  service("service") {
    mapScalarToKotlinLong("Long")
    mapScalarToUpload("Upload") // for file uploads
  }
}
```

Additional adapters for `DateTime`, `BigDecimal`, and more are available in the [apollo-kotlin-adapters](https://github.com/apollographql/apollo-kotlin-adapters) repository.

Custom adapters implement `Adapter<T>` with `fromJson` and `toJson` methods. Register them at build time (third argument to `mapScalar`) or at runtime with `.addCustomScalarAdapter()` on `ApolloClient.Builder`.

## Ground rules

- Only select fields that are needed for the UI or app's logic.
