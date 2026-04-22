# Interceptors

Apollo iOS uses a chain-of-responsibility interceptor model for networking. Four distinct protocols split the work by what part of the request they can see: GraphQL request/response, HTTP request/response, cache lookup, and response parsing. A custom `InterceptorProvider` supplies instances for each operation.

This reference explains the four protocols, how to build a custom provider, and the patterns for the three most common use cases: **auth**, **logging**, and **retry**.

## The four interceptor protocols

| Protocol | Sees | Use for |
|---|---|---|
| `GraphQLInterceptor` | `GraphQLRequest` and the parsed `ParsedResult` stream | Retry, token refresh & replay, logging at the operation layer, APQ |
| `HTTPInterceptor` | `URLRequest` and `HTTPResponse` | Attaching auth tokens and other headers, logging raw bytes |
| `CacheInterceptor` | Pre-flight cache lookup, post-flight cache write | Custom caching strategies (rare) |
| `ResponseParsingInterceptor` | Raw response → `ParsedResult` | Custom wire formats (very rare) |

**Decision rubric:**
- Attaching a bearer token or adding any HTTP header → `HTTPInterceptor`.
- Retrying on specific server errors (HTTP 5xx, GraphQL `UNAUTHENTICATED`, etc.) → `GraphQLInterceptor` (use the existing `MaxRetryInterceptor` as a starting point).
- Token refresh + replay-on-401 → `GraphQLInterceptor`. It has to sit at the same layer as `MaxRetryInterceptor` so the whole operation (including a new HTTP request with the refreshed token) is replayed.
- Logging — pick the layer that matches what you need to see: `HTTPInterceptor` for URL / status / headers / raw bytes; `GraphQLInterceptor` for operation names and parsed results.
- Replacing the cache or wire format → `CacheInterceptor` / `ResponseParsingInterceptor` (almost never needed).

## Custom `InterceptorProvider`

The `InterceptorProvider` protocol returns a fresh set of interceptors for each operation. **Always construct new instances per operation** — the `MaxRetryInterceptor` and some auth-refresh patterns rely on per-operation state.

```swift
import Apollo
import Foundation

final class AppInterceptorProvider: InterceptorProvider, Sendable {
  private let tokenStore: AuthTokenStore
  private let refresh: @Sendable () async throws -> String

  init(tokenStore: AuthTokenStore, refresh: @escaping @Sendable () async throws -> String) {
    self.tokenStore = tokenStore
    self.refresh = refresh
  }

  func graphQLInterceptors<Operation: GraphQLOperation>(
    for operation: Operation
  ) -> [any GraphQLInterceptor] {
    [
      MaxRetryInterceptor(maxRetriesAllowed: 3),                          // outermost — catches and replays
      AuthRefreshInterceptor(tokenStore: tokenStore, refresh: refresh),   // refresh + rethrow on 401
      AutomaticPersistedQueryInterceptor(),
    ]
  }

  func httpInterceptors<Operation: GraphQLOperation>(
    for operation: Operation
  ) -> [any HTTPInterceptor] {
    [
      AuthTokenInterceptor(tokenStore: tokenStore),                       // attach token to URLRequest
      ResponseCodeInterceptor(),
    ]
  }

  // `cacheInterceptor` and `responseParser` fall back to the DefaultInterceptorProvider
  // implementations from an extension on InterceptorProvider.
}
```

Wire the provider into the transport:

```swift
let provider = AppInterceptorProvider(tokenStore: tokenStore)
let transport = RequestChainNetworkTransport(
  urlSession: URLSession(configuration: .default),
  interceptorProvider: provider,
  store: store,
  endpointURL: URL(string: "https://api.example.com/graphql")!
)
```

## Auth token interceptor (#1 use case)

Attach a bearer token to every outgoing request. Use an `HTTPInterceptor` because auth is an HTTP concern.

```swift
import Apollo
import Foundation

actor AuthTokenStore {
  private(set) var token: String?
  func update(_ token: String?) { self.token = token }
  func currentToken() -> String? { token }
}

struct AuthTokenInterceptor: HTTPInterceptor {
  let tokenStore: AuthTokenStore

  func intercept(
    request: URLRequest,
    next: NextHTTPInterceptorFunction
  ) async throws -> HTTPResponse {
    var request = request
    if let token = await tokenStore.currentToken() {
      request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
    return try await next(request)
  }
}
```

Token refresh + retry is a **GraphQL-layer** concern, not HTTP. `MaxRetryInterceptor` is itself a `GraphQLInterceptor`, so the refresh interceptor must also be a `GraphQLInterceptor` to sit in the same layer and trigger a full-operation replay. Observe errors from downstream (HTTP failures, parser errors, etc.) via `mapErrors`, refresh the token, and rethrow — `MaxRetryInterceptor` catches the rethrown error and replays the chain, at which point the HTTP-layer `AuthTokenInterceptor` attaches the freshly-rotated token:

```swift
struct AuthRefreshInterceptor: GraphQLInterceptor {
  let tokenStore: AuthTokenStore
  let refresh: @Sendable () async throws -> String

  func intercept<Request: GraphQLRequest>(
    request: Request,
    next: NextInterceptorFunction<Request>
  ) async throws -> InterceptorResultStream<Request> {
    return await next(request).mapErrors { error in
      guard Self.isUnauthorized(error) else { throw error }
      let newToken = try await refresh()
      await tokenStore.update(newToken)
      // Rethrow so the outer MaxRetryInterceptor replays the chain.
      // On replay, AuthTokenInterceptor attaches the fresh token.
      throw AuthError.unauthorized
    }
  }

  private static func isUnauthorized(_ error: any Error) -> Bool {
    if let response = error as? ResponseCodeInterceptor.ResponseCodeError,
       response.response.statusCode == 401 { return true }
    return false
  }
}

enum AuthError: Error { case unauthorized }
```

Order matters in `graphQLInterceptors(for:)`: `MaxRetryInterceptor` must come **before** `AuthRefreshInterceptor` so it wraps it and catches the rethrown error:

```swift
func graphQLInterceptors<Operation: GraphQLOperation>(
  for operation: Operation
) -> [any GraphQLInterceptor] {
  [
    MaxRetryInterceptor(maxRetriesAllowed: 3),
    AuthRefreshInterceptor(tokenStore: tokenStore, refresh: refresh),
    AutomaticPersistedQueryInterceptor(),
  ]
}
```

## Logging interceptor (debug builds only)

A `GraphQLInterceptor` can log the operation name pre-flight and the parsed result post-flight. The WWDC-style recipe from the SDK's own docs:

```swift
import Apollo
import os

struct LoggingInterceptor: GraphQLInterceptor {
  let logger: Logger

  func intercept<Request: GraphQLRequest>(
    request: Request,
    next: NextInterceptorFunction<Request>
  ) async throws -> InterceptorResultStream<Request> {
    logger.debug("→ \(Request.Operation.operationName)")
    return await next(request)
      .map { result in
        logger.debug("← \(Request.Operation.operationName) ok")
        return result
      }
      .mapErrors { error in
        logger.error("✕ \(Request.Operation.operationName): \(error)")
        throw error
      }
  }
}
```

Add it to `graphQLInterceptors(for:)` only in `DEBUG` builds:

```swift
func graphQLInterceptors<Operation: GraphQLOperation>(
  for operation: Operation
) -> [any GraphQLInterceptor] {
  var interceptors: [any GraphQLInterceptor] = [MaxRetryInterceptor()]
  #if DEBUG
  interceptors.append(LoggingInterceptor(logger: Logger(subsystem: "MyApp", category: "Apollo")))
  #endif
  interceptors.append(AutomaticPersistedQueryInterceptor())
  return interceptors
}
```

## Retry

The built-in `MaxRetryInterceptor` handles retry with optional exponential backoff and jitter:

```swift
MaxRetryInterceptor(
  configuration: .init(
    maxRetries: 3,
    baseDelay: 0.3,
    multiplier: 2.0,
    maxDelay: 20.0,
    enableExponentialBackoff: true,
    enableJitter: true
  )
)
```

Put it **first** in `graphQLInterceptors(for:)` so it wraps every other interceptor. `MaxRetryInterceptor` is stateful per-operation — never share an instance across operations. The `InterceptorProvider` contract is to create new instances each call, which is why the example above returns a freshly constructed `MaxRetryInterceptor()` from the function.

If you throw from a later interceptor (for example `AuthRefreshInterceptor`), `MaxRetryInterceptor` catches the error and replays the chain up to `maxRetries` times.

## Automatic Persisted Queries (APQ)

`AutomaticPersistedQueryInterceptor` is included in the default provider. It sends a hash of each operation; if the server has the operation cached, it responds with the result. If not, it asks for the full operation, and the client retries with the query body included.

To enable APQ end to end:

1. Add `AutomaticPersistedQueryInterceptor()` to `graphQLInterceptors(for:)` (it is included in the default provider).
2. Configure `operationDocumentFormat: "operationId"` in `apollo-codegen-config.json` if you want to strip operation bodies from generated code.
3. Generate and upload an operation manifest with `./apollo-ios-cli generate-operation-manifest` so the server can recognize the hashes.

See [codegen.md](codegen.md#cli-commands) for the manifest command and the [APQ docs](https://www.apollographql.com/docs/ios/fetching/persisted-queries) for server setup.

## Ground rules

- **Create fresh interceptor instances per operation.** Sharing an instance across operations causes state bleed — for example, `MaxRetryInterceptor` counts retries per instance.
- **Split auth across two interceptors.** Put token attachment (`Authorization` header) in an `HTTPInterceptor` — it's a stateless URL-request mutation. Put token-refresh and replay orchestration in a `GraphQLInterceptor` so it lives at the same layer as `MaxRetryInterceptor` and can trigger a full-operation retry.
- Put retry in a `GraphQLInterceptor` (use `MaxRetryInterceptor` or a variant); retries should cover the whole operation, not just one HTTP call.
- Keep logging interceptors `#if DEBUG` — logging request bodies in release builds leaks data and slows the network path.
- Do not subclass or monkey-patch `DefaultInterceptorProvider` — implement `InterceptorProvider` directly. Most methods have default implementations via protocol extension.
