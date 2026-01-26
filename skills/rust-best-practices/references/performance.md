# Performance

## Table of Contents
- [Measurement First](#measurement-first)
- [Profiling Tools](#profiling-tools)
- [Cloning Patterns](#cloning-patterns)
- [Memory Layout](#memory-layout)
- [Iterator Efficiency](#iterator-efficiency)

## Measurement First

**"Don't guess, measure."** Rust code is typically already performant. Optimize only after identifying actual bottlenecks.

**Initial steps:**
1. Use `--release` flag (debug builds lack critical optimizations)
2. Run `cargo clippy -- -D clippy::perf` for performance hints
3. Micro-benchmark with `cargo bench`
4. Profile with `cargo flamegraph` (or `samply` on macOS)

## Profiling Tools

**Flamegraph interpretation:**
- Y-axis: stack depth (main at bottom)
- Box width: total CPU time for that function
- Color: random, not meaningful

Thick stacks = heavy CPU usage. Thin stacks = low intensity.

**Commands:**
```bash
cargo install flamegraph
cargo flamegraph --bin myapp
```

## Cloning Patterns

**Appropriate cloning:**
- API design requires owned data
- Overloaded operators need retained original ownership
- Snapshot comparisons
- Reference-counted pointers (Arc, Rc)
- Small connection-pool structures (HTTP clients)
- Builder patterns requiring owned mutation

**Inappropriate cloning:**
- Function parameters (use `&[T]` over `Vec<T>`)
- Read-only access (use `.iter()` or slices)
- Shared data across threads (use `&mut MyStruct` with proper synchronization)

**Cow for ambiguous ownership:**
```rust
use std::borrow::Cow;

fn greet(name: Cow<'_, str>) {
    println!("Hello {name}");
}

greet(Cow::Borrowed("Julia"));
greet(Cow::Owned(format!("User {}", id)));
```

## Memory Layout

**Stack allocation:**
- Keep small types and `Copy` implementations on stack
- Avoid passing large types (>512 bytes) by value
- Return small types by value; expensive returns use references

**Heap allocation:**
- Recursive data structures require boxing
- Massive stack allocations should be boxed (`Box<[u8]>`)
- Large const arrays benefit from `smallvec` crate

**Inline hints:**
Only apply `#[inline]` when benchmarks prove benefit. Rust already optimizes well without hints.

## Iterator Efficiency

Rust iterators compile into efficient tight loops (zero-cost abstractions). Chained operations compile without overhead.

**Best practices:**
- Prefer iterators over manual loops; compilers optimize them better
- `.iter()` creates references, allowing multiple iterators simultaneously
- Avoid unnecessary intermediate collections

```rust
// Inefficient - creates intermediate Vec
let doubled: Vec<_> = items.iter().map(|x| x * 2).collect();
process(&doubled);

// Efficient - passes iterator directly
let doubled = items.iter().map(|x| x * 2);
process_iter(doubled);
```

**Specialize when possible:**
```rust
// Use specialized methods
items.iter().sum::<i32>()  // Better than .fold(0, |a, b| a + b)
items.iter().product::<i32>()
items.iter().count()
```
