# Error Handling

## Table of Contents
- [Result Over Panic](#result-over-panic)
- [Avoiding unwrap/expect](#avoiding-unwrapexpect)
- [thiserror for Libraries](#thiserror-for-libraries)
- [anyhow for Binaries](#anyhow-for-binaries)
- [The ? Operator](#the--operator)
- [Testing Errors](#testing-errors)

## Result Over Panic

Use `Result<T, E>` for fallible operations. Reserve `panic!` for unrecoverable scenarios.

Alternative macros:
- `todo!()` - missing code placeholder
- `unreachable!()` - logically impossible conditions
- `unimplemented!()` - incomplete feature blocks

## Avoiding unwrap/expect

Only use in tests or when failure is genuinely impossible.

**Better alternatives:**
```rust
// Early return
let Ok(value) = operation() else {
    return Err(MyError::OperationFailed);
};

// Recovery logic
if let Ok(value) = operation() {
    process(value);
} else {
    handle_fallback();
}

// Default values
let value = operation().unwrap_or_default();
let value = operation().unwrap_or_else(|| compute_default());
```

## thiserror for Libraries

Use `thiserror` to simplify custom error types with automatic `From` and `Display` implementations.

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum DataError {
    #[error("failed to parse data: {0}")]
    Parse(#[from] serde_json::Error),

    #[error("validation failed: {field} {reason}")]
    Validation { field: String, reason: String },

    #[error("not found: {0}")]
    NotFound(String),
}
```

**Error hierarchies** for layered systems:
```rust
#[derive(Error, Debug)]
pub enum ServiceError {
    #[error("database error: {0}")]
    Database(#[from] DatabaseError),

    #[error("network error: {0}")]
    Network(#[from] NetworkError),
}
```

## anyhow for Binaries

Use `anyhow` for binary applications only. Never use in libraries.

**Why not in libraries:**
- Erases error context callers might need
- Makes error matching impossible for consumers
- String maintenance becomes difficult

## The ? Operator

Prefer `?` over verbose match chains:

```rust
// Verbose (avoid)
let file = match File::open(path) {
    Ok(f) => f,
    Err(e) => return Err(e.into()),
};

// Clean (prefer)
let file = File::open(path)?;
```

**Error transformation:**
```rust
// Map error type
let data = parse(input).map_err(|e| MyError::Parse(e))?;

// Log and propagate
let data = parse(input)
    .inspect_err(|e| tracing::error!("parse failed: {e}"))?;
```

## Testing Errors

Test error messages using `to_string()` or `format!`:

```rust
#[test]
fn parse_returns_error_on_invalid_input() {
    let result = parse("invalid");
    assert!(result.is_err());
    assert_eq!(
        result.unwrap_err().to_string(),
        "parse error: unexpected character at position 0"
    );
}
```

Most error types lack `PartialEq`, so compare string representations.

## Special Considerations

- **Single-error modules**: Use error struct instead of enum
- **Async code**: Errors need `Send + Sync + 'static` bounds
- **Libraries**: Avoid boxing error types to preserve caller flexibility
