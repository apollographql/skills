# Testing

## Table of Contents
- [Test Naming](#test-naming)
- [Test Organization](#test-organization)
- [Test Categories](#test-categories)
- [Assertions](#assertions)
- [Snapshot Testing](#snapshot-testing)

## Test Naming

Test names should read like sentences describing desired behavior.

```rust
// Bad
#[test]
fn test_add_happy_path() { }

// Good
#[test]
fn add_returns_sum_of_two_positive_numbers() { }

#[test]
fn parse_returns_error_when_input_contains_invalid_utf8() { }
```

## Test Organization

**Single responsibility:** Tests should describe one thing that the unit does. Separate tests with individual assertions make failures easier to diagnose.

**Module grouping:**
```rust
#[cfg(test)]
mod tests {
    use super::*;

    mod parse {
        use super::*;

        #[test]
        fn returns_value_for_valid_input() { }

        #[test]
        fn returns_error_for_empty_input() { }
    }

    mod format {
        use super::*;

        #[test]
        fn formats_with_default_precision() { }
    }
}
```

IDEs can run test modules together, and output shows hierarchical naming.

## Test Categories

**Unit tests:** Located within the same module as tested code.
- Verify implementation details and edge cases
- Test error handling
- Full visibility into private functions

**Integration tests:** Placed in `tests/` directory.
- Test public API only
- Ensure components work correctly when combined

**Doc tests:** Embedded in documentation comments.
- Serve as usage examples
- Executed via `cargo test`

```rust
/// Parses a number from a string.
///
/// # Examples
///
/// ```
/// use mylib::parse_number;
/// assert_eq!(parse_number("42"), Ok(42));
/// ```
pub fn parse_number(s: &str) -> Result<i32, ParseError> { }
```

## Assertions

**Built-in:**
- `assert!(condition)` - boolean check
- `assert_eq!(left, right)` - equality
- `assert_ne!(left, right)` - inequality

All support formatted error messages:
```rust
assert_eq!(result, expected, "failed for input: {input}");
```

**Parameterized testing with rstest:**
```rust
use rstest::rstest;

#[rstest]
#[case(2, 3, 5)]
#[case(0, 0, 0)]
#[case(-1, 1, 0)]
fn add_returns_correct_sum(#[case] a: i32, #[case] b: i32, #[case] expected: i32) {
    assert_eq!(add(a, b), expected);
}
```

**Better diffs with pretty_assertions:**
```rust
use pretty_assertions::assert_eq;
```

## Snapshot Testing

Use `cargo insta` for comparing outputs against saved "golden" versions.

**Ideal for:**
- Generated code
- Serialized data (JSON, YAML)
- HTML output
- CLI output

**Setup:**
```bash
cargo install cargo-insta
```

```rust
use insta::assert_snapshot;

#[test]
fn render_produces_expected_html() {
    let html = render_template(&data);
    assert_snapshot!(html);
}
```

**Named snapshots:**
```rust
assert_snapshot!("user_profile", render_user(&user));
```

**Redactions for unstable fields:**
```rust
use insta::assert_json_snapshot;

assert_json_snapshot!(response, {
    ".timestamp" => "[timestamp]",
    ".request_id" => "[uuid]",
});
```

**Best practices:**
- Use named snapshots for clarity
- Keep snapshots concise
- Apply redactions for timestamps, UUIDs, etc.
- Review snapshot changes carefully in PRs

**Avoid snapshot testing for:**
- Simple types that can use `assert_eq!`
- Huge objects (hard to review changes)
- Flaky outputs
