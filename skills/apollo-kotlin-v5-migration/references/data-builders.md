# Data builders migration

Test-only data builders were restructured to live in a dedicated `builder` package, to require `FakeResolver` and custom scalar adapters to be passed explicitly, to make fragment builders top-level (not companion objects), and to have `FakeResolver` work in the JSON domain.

These changes mostly affect test code. Production code rarely touches data builders.

## Package change

```kotlin
// Before
import com.example.type.buildCat

// After
import com.example.builder.buildCat
```

The new package suffix is `.builder` instead of `.type`. The class names didn't change.

## Data root is an extension function

The `Data { ... }` DSL entry point is now an extension function defined in the builder package; you need to import it.

```kotlin
import com.example.builder.Data  // required in v5

val data = GetFooQuery.Data { /* ... */ }
```

## Pass `FakeResolver` explicitly

```kotlin
// Before — used a globally configured FakeResolver
val data = GetFooQuery.Data {}

// After — required as a positional argument
val data = GetFooQuery.Data(fakeResolver) {}
```

If you want the default fake resolver, instantiate `DefaultFakeResolver()` once per test (or per fixture) and pass it through.

## Pass custom scalar adapters explicitly

```kotlin
// Before — implicit from the client
val data = GetFooQuery.Data {}

// After
val data = GetFooQuery.Data(customScalarAdapters = customScalarAdapters) {}
```

You can construct a `CustomScalarAdapters.Builder()` (or grab the one from your test `ApolloClient`) and pass it in.

## Fragment builders are no longer companion objects

```kotlin
// Before — Lion was a companion object on AnimalDetailsImpl
val data = AnimalDetailsImpl.Data(Lion) { /* ... */ }

// After — LionBuilder is a top-level value in the builder package
val data = AnimalDetailsImpl.Data(LionBuilder) { /* ... */ }
```

Each concrete fragment-impl type gets a sibling `<TypeName>Builder` symbol; pass that to `Data(...)`.

## `FakeResolver` operates in the JSON domain

If you override `resolveLeaf` (or any custom resolution hook) to return a Kotlin value of a custom scalar type, you must now serialize it to its JSON representation via `context.adaptToJson(...)`. Returning a Kotlin instance of a custom scalar directly will produce wrong/garbled values.

```kotlin
// Before — returned a Kotlin LocalDate directly
override fun resolveLeaf(context: FakeResolverContext): Any {
  return if (context.mergedField.type.rawType().name == "Date") {
    LocalDate.of(2025, Month.APRIL, 28)
  } else {
    super.resolveLeaf(context)
  }
}

// After — adapt to JSON before returning
override fun resolveLeaf(context: FakeResolverContext): Any {
  return if (context.mergedField.type.rawType().name == "Date") {
    context.adaptToJson(LocalDate.of(2025, Month.APRIL, 28))
  } else {
    super.resolveLeaf(context)
  }
}
```

If your `FakeResolver` only deals with built-in scalars (`String`, `Int`, etc.), no change is needed.

## Migration recipe

1. `rg -n "import com\.example\.type\.build|\.Data \{|FakeResolver"` (substitute your generated package).
2. Update imports from `<pkg>.type.build*` and the `Data` symbol to `<pkg>.builder.*`.
3. Add an explicit `FakeResolver` argument to every `Data { ... }` call.
4. If you have custom scalars in your test data, add `customScalarAdapters = ...`.
5. Replace companion-object fragment references (`Lion`) with their `<Name>Builder` counterparts.
6. Audit any custom `FakeResolver` override returning custom-scalar Kotlin values — wrap with `context.adaptToJson(...)`.
7. Run the test source set: `./gradlew test` (or your platform-specific test task).
