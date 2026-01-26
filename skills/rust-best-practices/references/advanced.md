# Advanced Patterns

## Table of Contents
- [Generics and Static Dispatch](#generics-and-static-dispatch)
- [Dynamic Dispatch](#dynamic-dispatch)
- [Dispatch Trade-offs](#dispatch-trade-offs)
- [Type State Pattern](#type-state-pattern)
- [Documentation Best Practices](#documentation-best-practices)
- [Pointer Types](#pointer-types)

## Generics and Static Dispatch

Use generics with `impl Trait` or trait bounds for compile-time polymorphism.

**When to use:**
- Performance-critical code requiring zero runtime overhead
- Types known at compile time
- Single-use implementations

```rust
fn process<T: AsRef<str>>(input: T) {
    println!("{}", input.as_ref());
}

fn sum_items(iter: impl Iterator<Item = i32>) -> i32 {
    iter.sum()
}
```

Through monomorphization, the compiler generates specialized code for each concrete type used.

## Dynamic Dispatch

Use `dyn Trait` for runtime polymorphism.

**When to use:**
- Heterogeneous collections requiring mixed type storage
- Plugin architectures needing runtime polymorphism
- API abstraction layers

```rust
// Owned trait objects
let animals: Vec<Box<dyn Animal>> = vec![
    Box::new(Dog),
    Box::new(Cat),
];

// Thread-safe sharing
let handler: Arc<dyn Handler + Send + Sync> = Arc::new(MyHandler);
```

**Object safety requirements:**
- No generic methods
- No `Self: Sized` requirements
- No associated constants

## Dispatch Trade-offs

| Factor | Static (Generics) | Dynamic (`dyn`) |
|--------|-------------------|-----------------|
| Speed | Faster, inlined | Vtable indirection |
| Compilation | Slower | Faster |
| Binary size | Larger | Smaller |
| Type mixing | No | Yes |

**Guidelines:**
- Start with generics; migrate to `Box<dyn Trait>` when flexibility becomes essential
- Avoid boxing prematurely within struct internals
- Apply boxing at API boundaries rather than internally

## Type State Pattern

Encode valid states in the type system to catch invalid operations at compile time.

```rust
use std::marker::PhantomData;

struct Closed;
struct Open;

struct File<State> {
    path: String,
    _state: PhantomData<State>,
}

impl File<Closed> {
    fn new(path: &str) -> Self {
        File { path: path.to_string(), _state: PhantomData }
    }

    fn open(self) -> File<Open> {
        File { path: self.path, _state: PhantomData }
    }
}

impl File<Open> {
    fn read(&self) -> Vec<u8> { /* ... */ vec![] }
    fn close(self) -> File<Closed> {
        File { path: self.path, _state: PhantomData }
    }
}
```

**Builder with compile-time guarantees:**
```rust
struct Builder<Name, Age> {
    name: Name,
    age: Age,
}

struct Missing;
struct Set<T>(T);

impl Builder<Missing, Missing> {
    fn new() -> Self { Builder { name: Missing, age: Missing } }
}

impl<Age> Builder<Missing, Age> {
    fn name(self, name: String) -> Builder<Set<String>, Age> {
        Builder { name: Set(name), age: self.age }
    }
}

impl<Name> Builder<Name, Missing> {
    fn age(self, age: u32) -> Builder<Name, Set<u32>> {
        Builder { name: self.name, age: Set(age) }
    }
}

impl Builder<Set<String>, Set<u32>> {
    fn build(self) -> Person {
        Person { name: self.name.0, age: self.age.0 }
    }
}
```

**When to apply:**
- Library development requiring strict constraints
- Replacing runtime booleans with type-safe alternatives
- Critical compile-time correctness needs

**Avoid when:**
- Simple state tracking via enums suffices
- Runtime flexibility is necessary

## Documentation Best Practices

**`///` for public items:**
```rust
/// Loads a user profile from disk.
///
/// # Errors
/// - [`MyError::FileNotFound`] if file missing
/// - [`MyError::InvalidJson`] if content isn't valid JSON
///
/// # Examples
///
/// ```
/// let user = load_user(Path::new("user.json"))?;
/// ```
pub fn load_user(path: &Path) -> Result<User, MyError> { }
```

**`//!` for module/crate documentation:**
```rust
//! Custom chess engine implementation.
//!
//! Handles board state, move generation, and check detection.
```

**Documentation lints:**
```rust
#![deny(missing_docs)]
#![deny(rustdoc::broken_intra_doc_links)]
```

| Lint | Purpose |
|------|---------|
| `missing_docs` | Warns of undocumented public items |
| `broken_intra_doc_links` | Detects broken internal references |
| `missing_panics_doc` | Requires `# Panics` section |
| `missing_errors_doc` | Requires `# Errors` section for Result types |
| `missing_safety_doc` | Requires `# Safety` section for unsafe blocks |

## Pointer Types

**Safe references:**
- `&T`: Multiple concurrent readers, no mutation
- `&mut T`: Single exclusive writer
- `Box<T>`: Single-owner heap allocation
- `Rc<T>`: Reference counting (single-threaded)
- `Arc<T>`: Atomic reference counting (multi-threaded)

**Interior mutability:**
- `Cell<T>`: Fast, Copy types only
- `RefCell<T>`: Runtime-checked borrowing (may panic)
- `Mutex<T>`: Thread-safe exclusive access
- `RwLock<T>`: Thread-safe shared/exclusive access
- `OnceCell<T>`, `OnceLock<T>`: One-time initialization

**Thread safety traits:**
- `Send`: Data can transfer across thread boundaries
- `Sync`: Data can be safely referenced from multiple threads

**Unsafe pointers:**
- `*const T`, `*mut T`: FFI and low-level operations, require `unsafe` blocks
