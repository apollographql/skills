# Coding Style & Idioms

## Table of Contents
- [Borrowing Over Cloning](#borrowing-over-cloning)
- [When to Pass by Value](#when-to-pass-by-value)
- [Handling Option and Result](#handling-option-and-result)
- [Prevent Early Allocation](#prevent-early-allocation)
- [Iterators vs For Loops](#iterators-vs-for-loops)
- [Comments](#comments)
- [Import Organization](#import-organization)

## Borrowing Over Cloning

Prefer `&T` over `.clone()` for performance.

**When cloning is appropriate:**
- Needing to modify while preserving the original
- Using `Arc`/`Rc` pointers
- Thread-shared data (typically via `Arc`)
- Caching scenarios where APIs demand owned data

**Anti-patterns to avoid:**
- Auto-cloning in loops (use `.cloned()` or `.copied()` instead)
- Cloning large structures like `Vec<T>` or `HashMap<K, V>`
- Using `Vec<T>` or `&Vec<T>` instead of `&[T]`
- Using `String` instead of `&str`

```rust
// Bad
fn process(name: String) {
    println!("Hello {name}");
}

// Good
fn process(name: &str) {
    println!("Hello {name}");
}
```

## When to Pass by Value

Small, cheap-to-copy types should be passed by value using the `Copy` trait.

**Guidelines for Copy:**
- All fields implement `Copy`
- Size: up to ~24 bytes (3 words on 64-bit systems)
- Represents plain data without heap allocations

```rust
#[derive(Debug, Copy, Clone)]
struct Point {
    x: f32,
    y: f32,
    z: f32,
}
```

**Primitive sizes:**
- `i8`/`u8`: 1 byte
- `i16`/`u16`: 2 bytes
- `i32`/`u32`/`f32`: 4 bytes
- `i64`/`u64`/`f64`: 8 bytes
- `i128`/`u128`: 16 bytes
- `bool`: 1 byte, `char`: 4 bytes

For enums: derive `Copy` when acting as tags with all `Copy` payloads.

## Handling Option and Result

**Use `match` when:**
- Pattern matching against inner types
- Transforming into complex types (e.g., `Result<Option<U>, E>`)

**Use `let Some(x) = expr else { ... }` when:**
- Diverging code needs no failed-pattern context
- Breaking/continuing loops

```rust
let Some(user) = get_user(id) else {
    return Err(UserNotFound);
};
```

**Use `if let` when:**
- Diverging code requires additional computation

**Anti-patterns:**
- Converting Result to Option manually (use `.ok()`, `.ok_or()`, `.ok_or_else()`)
- Using `unwrap`/`expect` outside tests
- Using `if let` for precomputed defaults

## Prevent Early Allocation

Methods like `or`, `map_or`, `unwrap_or` allocate eagerly. Use `_else` variants for lazy evaluation.

```rust
// Eager (bad) - allocates even if x is Ok
x.ok_or(ParseError::ValueAbsent(format!("missing {x}")))

// Lazy (good) - only allocates on error
x.ok_or_else(|| ParseError::ValueAbsent(format!("missing {x}")))
```

```rust
// Good patterns
x.map_or_else(|e| format!("Error: {e}"), |v| v.len())
x.unwrap_or_else(Vec::new)
```

For error logging and transformation:
```rust
x.inspect_err(|err| tracing::error!("{err}"))
 .map_err(|err| GeneralError::from(("fn_name", err)))?;
```

## Iterators vs For Loops

**Prefer `for` loops when:**
- Early exits needed (`break`, `continue`, `return`)
- Simple iterations with side-effects
- Readability prioritized

**Prefer iterators when:**
- Transforming collections or Option/Result types
- Composing multiple steps elegantly
- No early exits required
- Using `.enumerate`, `.windows`, `.chunks`
- Combining data from multiple sources

**Critical:** Iterators are lazy. `.iter()`, `.map()`, `.filter()` don't execute until a consumer like `.collect()`, `.sum()`, `.for_each()`.

**Anti-patterns:**
- Long chains without formatting
- Unnecessary `.collect()` before passing to another function
- `.into_iter()` over `.iter()` for Copy types
- `.fold()` instead of specialized `.sum()`

## Comments

Comments explain *why*, not *what* or *how*.

**Good comments address:**
- Safety concerns with justification
- Performance quirks and non-obvious optimizations
- External constraints or design decisions

```rust
// SAFETY: `ptr` guaranteed non-null and aligned by caller
unsafe { std::ptr::copy_nonoverlapping(src, dst, len); }
```

**Bad comments:**
- Obvious statements restating code
- Lengthy explanations that should be in docs or ADRs

**Better than comments:** Extract complex logic into well-named functions with tests.

**TODOs:** Track via issues with references: `// TODO(#42): Remove workaround after bugfix`

## Import Organization

Standard Rust import order:
1. `std` (including `core`, `alloc`)
2. External crates
3. Workspace crates
4. `super::`
5. `crate::`

Configure `rustfmt.toml`:
```toml
reorder_imports = true
imports_granularity = "Crate"
group_imports = "StdExternalCrate"
```
