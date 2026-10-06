# The mapping language

`JSONSelection`: the syntax inside `selection`, `body`, `queryParams`, `path`,
`isSuccess` and `errors`, and inside the `{…}` expressions of a header value or
a URI template, which are otherwise string templates. It turns the JSON an API sends into the shape a GraphQL type
declares, with no resolver code.

The one idea everything else follows from: **a selection is a shape, not a
query**. Composition has to determine the output shape by reading the string,
without ever seeing a response. That is why a group selection needs a
sub-selection it can name keys from, why methods are a fixed set rather than
arbitrary code, and why an untypable payload has to become a documented scalar
instead of a guess.

This file is written for the target toolchain: **`connect/v0.4`, composed at
`federation_version: =2.15.2`, served by Apollo Router 2.17**. Where
`connect/v0.3` behaves differently, the difference is marked **At v0.3**,
because workspaces created before the move may still be pinned at
`federation_version: =2.12.0` with `connect/v0.3`. A workspace can also link
an older `federation/` spec than its pin, recorded as `federation_spec_version`.
Check `.factory/workspace.yaml`
before trusting any example here, and read
[Moving a workspace from v0.3 to v0.4](#moving-a-workspace-from-v03-to-v04) before changing the pin.

The grammar is in the [appendix](#appendix-the-grammar-at-connectv04), so this
file answers a syntax question without a network round trip. For the grammar
explained rule by rule, with railroad diagrams and the reasoning behind each
production, read
[`json_selection/README.md`](https://github.com/apollographql/router/blob/dev/apollo-federation/src/connectors/json_selection/README.md)
in the router repository, but take the method list from
[Which methods run](#which-methods-run). Read
[connectors-language.md](connectors-language.md) for the directives that carry
these strings.

## What your pin decides

Three version numbers matter, and they are independent:

| Setting | Target | Where it lives |
|---|---|---|
| `federation_version` | `=2.15.2` | `supergraph.yaml`, pinned by `workspace.yaml` |
| `@link(url: ".../federation/vX")` | `v2.15` | the schema |
| `@link(url: ".../connect/vX")` | `v0.4` | the schema, pinned by `workspace.yaml` |

The router's version (2.17) and `federation_version` are separate lines. 2.15.2
was the newest composition release when this file was measured; 2.15.3 and
2.15.4 have not been measured here.

**Apollo documents `connect/v0.4`'s floor as composition 2.14.1 and Apollo
Router 2.15.0**; below either, use `connect/v0.3` (composition 2.12, Router
2.8). The table records what composed here, which is not the supported
floor: the `v0.4` link alone composes from 2.13.0. A `federation_version`
accepts a `federation/` link no newer than itself:

| `federation_version` | newest `federation/` link | `connect/v0.4` |
|---|---|---|
| 2.12.0 | `v2.12` | no |
| 2.13.0 | `v2.13` | yes |
| 2.14.0, 2.14.3 | `v2.14` | yes |
| 2.15.0 | `v2.14` | yes |
| 2.15.2 | `v2.15` | yes |

`yes` means the link composes, not that all of this file's grammar does:
composed at 2.14.0, comma-separated lists, bare numbers, unwrapped `??` and
`?!` chains and bare-brace bodies are parse errors. All of them compose at
2.15.1 and 2.15.2.

A `federation/` link newer than the pin fails composition; see
[connectors-language.md](connectors-language.md#linking-the-spec).

## Reading a response into a type

### Sub-selections map over arrays for free

There is no array syntax. A sub-selection after an array-valued path applies to
every element, the way a GraphQL selection set does. Every row below is
executed output for one response whose `author.articles` is a two-element array:

| Selection | Result |
|---|---|
| `author.articles.title` | `["T1", "T2"]` |
| `author.articles { title }` | `[{title:"T1"}, {title:"T2"}]` |
| `author.articles.byline.place` | `["P1", "P2"]` |
| `author.articles { title place: byline.place }` | `[{title, place}, …]` |
| `author.articles { td: { title date } }` | `[{td:{title,date}}, …]` |

If the value turns out not to be an array, the same selection yields one
result instead of a list. The string does not change.

Paths inside the braces start from each element, so
`author.articles { name: author.name }` gives `name: null` for every article.
To reach the parent, bind it first:
`author->as($a).articles { name: $a.name }` gives `name: "Ben"` on each.

### Separators

A selection list is separated by whitespace or by commas, **not both**:
`a, b, c` and `a b c` are fine, and `a, b c` fails with a message saying the
list is comma-separated. Method arguments always take commas. The examples in
this file use whitespace, which is the only form v0.3 accepts.

**At v0.3:** commas in a selection list are a parse error.

### Stripping an envelope

Most REST list endpoints wrap the payload. Select through the wrapper with `$.`
and keep siblings alongside it:

```graphql
selection: """
$.data { id name }
nextCursor: meta.next_cursor
"""
```

Given `{"data":{"id":7,"name":"n"},"meta":{"next_cursor":"c1"}}` this produces
`{id: 7, name: "n", nextCursor: "c1"}`: the `data` wrapper is gone and
`nextCursor` sits beside the fields it wrapped.

### The single-key rule

This is the one that silently produces the wrong shape.

```graphql
author { name }              # keeps the key:  { author: { name } }
some.nested.path { a b c }   # merges:         { a, b, c }
```

A **single** key with a sub-selection contributes that key to the output. A
path of more than one step does not, so its sub-selection merges into the
parent. Executed, both in one selection, the result is
`{author: {name: "Ben"}, a: "A", b: "B", c: "C"}`.

Two consequences worth holding on to:

- Adding one step flips the behaviour. `author { name }` keeps `author`;
  `author.details { name }` does not.
- To get the flat value from a single key, write `$.author { name }`. To keep
  a key on a longer path, alias it: `abc: some.nested.path { a b c }`.

### Building an object the API sent flat

When the response has `authorID` and `authorName` but the schema wants a nested
`author`, alias a sub-selection. The alias is required, because the group would
otherwise be anonymous:

```graphql
selection: """
postID
title
author: {
  id: authorID
  name: authorName
}
"""
```

### Turning an array of ids into entity references

A very common REST shape, and three tokens:

```graphql
selection: """
id
friends: friend_ids { id: $ }
"""
```

`{"id":123,"friend_ids":[234,345,456]}` becomes
`{id: 123, friends: [{id:234},{id:345},{id:456}]}`. Inside the sub-selection
`$` is each element in turn.

The target field has to be a typed object list. A `{ … }` group cannot target a
`<Prefix>_JSON` scalar: composition rejects it with
`GROUP_SELECTION_IS_NOT_OBJECT`. The JSON escape hatch in
[schema-authoring.md](schema-authoring.md) does not absorb a sub-selection.

### Renaming snake_case keys in bulk

`->keysToCamelCase` renames every key of an object, so one line replaces a
block of `camelCase: snake_case` aliases:

```graphql
selection: """
$->keysToCamelCase { id loginName fullName }
"""
```

turns `{"id":1,"login_name":"ben","full_name":"Ben Newman"}` into
`{id: 1, loginName: "ben", fullName: "Ben Newman"}`. The sub-selection is not
optional: without it composition cannot see which fields the method provides,
and every field of the type is `CONNECTORS_UNRESOLVED_FIELD`.
`->keysToCamelCaseDeep` recurses: `{"outer_key":{"inner_key":1}}` becomes
`{outerKey: {innerKey: 1}}`.

Aliases stay the right tool when the GraphQL name is not the camelCase of the
wire name. [naming.md](naming.md) has the rules.

In a factory workspace, keep the aliases for now: the tools do not yet
read through `->keysToCamelCase`. `graphos-factory-core reconcile` reports every
field it renames as unmapped; `source-coverage` reports every field under a
root `$->keysToCamelCase { … }` as `unaccounted`, and every field under a
nested one as `unresolved`.

## Abstract types

A `oneOf` whose members a wire value tells apart (usually a `discriminator`)
becomes a union, or an interface when the members share fields. One form
composes: a `...` spread of `->match` on the discriminator, with one arm per
member, each an object carrying a literal `__typename`:

```graphql
type Query {
  media: [Media] @connect(source: "api", http: { GET: "/media" }, selection: """
  id
  title
  ... kind->match(
    ["book", { __typename: "Book", pages: pages }],
    ["movie", { __typename: "Movie", minutes }],
    [@, null]
  )
  """)
}
```

This works for `union Media = Book | Movie` and for `interface Media`. `pages`
and `minutes` read from the element the spread sits in, and `{ minutes }` is
the shorthand for `minutes: minutes`. An arm can also be written
`$ { __typename: $("Book") pages }`.

What composition enforces, at `=2.15.2`:

| Written | Result |
|---|---|
| a flat list, `id title pages minutes` | `SELECTED_FIELD_NOT_FOUND`: `minutes` does not exist on `Book` |
| `__typename: kind->match(["book", "Book"], …)` beside flat fields | the same. A `__typename` outside a spread narrows nothing |
| the shared fields only, `id title` | `CONNECTORS_UNRESOLVED_FIELD` for `Book.pages` and `Movie.minutes` |
| a member with no arm | `No matching shape found for selection. Attempted 1 different shape variations` |
| an arm with a field its member lacks | the same message |
| an arm with no `__typename`, one that names a non-member, or one computed (`__typename: kind`) | `INTERNAL: An internal error has occurred` |

A field outside the spread has to exist on every member.

**Only at a connector's own return type.** A union or interface field inside
another type's selection (`payment { ... type->match(…) }` on
`Order.payment: PaymentMethod`) fails with `GROUP_SELECTION_IS_NOT_OBJECT`.
Give that field its own `@connect` on `Order`, keyed by `$this.id`, and put the
spread in it: `$.payment { ... type->match(…) }`. That costs one request per
parent. When nothing can re-fetch the value, it stays a documented JSON scalar
([schema-authoring.md](schema-authoring.md#the-opaque-json-policy)).

**An unmatched discriminator is a silent `null`.** Executed through Router
2.17.0 with a `podcast` element the arms do not list:

- with `[@, null]`, the element is `null` and `errors` is empty;
- with no catch-all, a union element is `null` too. An interface's result
  then depends on the query: `{ media { id title } }` returns the podcast,
  and adding `__typename` or a fragment turns it into `null`;
- in a `[Media!]` list, the whole list is `null`, reported only in
  `extensions.valueCompletion`;
- a catch-all into a member, `[@, { __typename: "Book", … }]`, labels the
  podcast a `Book`, with `pages: null`.

Write `[@, null]`, keep the element type nullable, and give e2e one case per
member plus one with a discriminator value the arms do not list.

**Without a discriminator**, match on a key only some members send, through a
fallback: `... $(radius ?? "none")->match(["none", { __typename: "Rect", width,
height }], [@, { __typename: "Circle", radius }])`. The method does not run on
a missing key, so `radius->match([null, …], …)` yields `null` for every
`Rect`.

**At v0.3** a union or interface is `CONNECTORS_UNSUPPORTED_ABSTRACT_TYPE`,
and `...` fails with "Spread syntax (...) is not supported in connect/v0.3
(use connect/v0.4)". A
polymorphic payload is a documented JSON scalar there.

**What the skill's tools see**. `rover connector test` asserts a
spread correctly, and an unmatched element fails the case with
`Method ->match did not match any [candidate, value] pair`. The factory
readers parse this form, with each arm reading from the object the spread
sits in:
- `source-coverage` maps the discriminator and every arm's fields;
- `reconcile` reports an excluded field an arm maps;
- lint's `wire-enum-drift` and `int-overflow` check an arm's leaves against
  its `__typename` member. The source property comes from the `oneOf` variant
  whose discriminator `enum` holds the arm's candidate, so a `@` arm is not
  checked;
- `scaffold` asks for `__typename` and one `... on Member { … }` fragment per
  arm, with the fields beside the spread repeated in each.

Any other spread (`... $.x { … }`, `... ->echo(…)`, a `->match` arm that is
neither an object nor `null`) reads `unresolved` in `source-coverage`,
naming the spread, for every path under that object the selection does not
otherwise map.

## Literals

At v0.4 the right-hand side of an alias is any expression, so a literal can be
written bare:

```graphql
kind: "Book"            # "Book"
five: 5                 # 5
flag: true              # true
none: null              # null
fb: $.missing ?? "x"    # "x"
```

`$( … )` still works and still means "this is a literal expression", and
`$."…"` reads a property whose name needs quoting. Both are unambiguous at
every version, so prefer them in anything that has to survive a move between
versions. The skill's own tools need them too: `graphos-factory-core reconcile`
reads a bare `true`, `false` or `null` as a property path ("the connector
selects … true"), and `$(true)` as a literal.

**At v0.3 the same text means something else, silently.** A quoted string on
the right of an alias is a property **name**, and so are `true`, `false` and
`null`. Executed against `{"Book": "…", "true": "…", "false": "…", "null": "…"}`:

| Selection | v0.3 | v0.4 |
|---|---|---|
| `looksLiteral: "Book"` | the `Book` property | `"Book"` |
| `bool: true` | the `true` property | `true` |
| `no: false` | the `false` property | `false` |
| `nul: null` | the `null` property | `null` |
| `properLiteral: $("Book")` | `"Book"` | `"Book"` |
| `propertyForm: $."Book"` | the `Book` property | the `Book` property |

Neither version errors, so moving a schema from v0.3 to v0.4 can change what
it returns; [`connect-migrate`](#moving-a-workspace-from-v03-to-v04) finds such
sites in `selection`, and the other mapping arguments are checked by hand. At
v0.3 a bare number (`a: 5`) or an unwrapped operator chain (`a: $.x ?? "d"`)
does not parse; wrap it in `$( )`.

## Variables

| Variable | Bound to | Where |
|---|---|---|
| `$` | the value the enclosing `{ … }` received, or the response root | `selection`, `errors` |
| `@` | the value a method is operating on, rebound per element inside `->map` | method arguments |
| `$args` | the field's GraphQL arguments | root-field connectors |
| `$this` | the parent object, so sibling fields are reachable | non-root types |
| `$batch` | the collected keys | batch connectors |
| `$config` | values from router config | anywhere |
| `$env` | the router process environment | anywhere |
| `$context` | the router's request context, e.g. the caller's own credentials | anywhere |
| `$request.headers` | the client request's headers; each value is a list | anywhere |
| `$status` | the HTTP status | `selection`, `errors` |
| `$response.headers` | the API response's headers; each value is a list | `selection`, `errors` |

`$` does **not** rebind inside a method argument, which is what makes
`$.first->and($.second)` work: `$.second` still reads from the enclosing
object, not from the result of `$.first`. Use `@` when you do want the value
flowing through the method.

`rover connector test` injects `$args`, `$this`, `$batch`, `$config` and
`$context`, but **not** `$env`. `scripts/unit.sh` rewrites static
`{$env.NAME}` to `{$config.NAME}` in a temporary copy and the suites supply
`config.common.variables.$config`. Only a real router run proves `$env`.

## Methods

Written `value->method(args)`, chainable left to right, and always named here
with the leading `->`. The set is closed.

### Which methods run

The router that executes the connector decides which methods exist, not
the connect version. Routers 2.17 and 2.18 run the same **39 public
methods**, whatever the composition pin. `->withError` and `->withWarning`
are in no 2.x release up to 2.18.0, so do not use either. The connect
version decides how an existing method behaves: a breaking change to a
method applies only from the connect version that introduced it, so a
schema opts in by moving its link. `->typeof`, `->matchIf`,
`->has`, `->keys` and `->values` are not exposed at any release, so never reach
for them however they are documented elsewhere. An unavailable method is
neither a build error nor a runtime error: the field comes back `null`.

### Picking things out of a list

| Method | Does | Example |
|---|---|---|
| `->first` | first element | `colors->first` |
| `->last` | last element | `colors->last` |
| `->get(i)` | element at index; also a string char, or an object property by name | `items->get(2)`, `user->get("name")` |
| `->slice(a, b)` | sub-list, or substring | `colors->slice(0, 2)`, `$("abcdef")->slice(1, 3)` is `"bc"` |
| `->size` | list length, string length, or property count | `colors->size` |
| `->filter(cond)` | every element matching, `@` is the element | `users->filter(@.active->eq(true))` |
| `->find(cond)` | the first element matching, else nothing | `users->find(@.active->eq(true))` |
| `->map(expr)` | apply to each element; on a non-list, a one-element list (`27` gives `[54]`) | `numbers->map(@->mul(2))` |
| `->entries` | object to `[{key, value}, …]`; `->entries.key` for just the keys | `obj->entries` |
| `->joinNotNull(sep)` | joins a list of scalars, skipping nulls | `$(["a", null, "b"])->joinNotNull(",")` is `"a,b"` |

### Comparing and testing

`->eq` `->ne` `->gt` `->gte` `->lt` `->lte` compare against their argument and
return a boolean. `->in([…])` is true when the value is one of the listed
values; `->contains(v)` is true when the **list** it is applied to holds `v`.
Note the direction: `$(123)->in([123, 456])` and `$([123, 456])->contains(123)`
are the same question asked from opposite ends. `->and` `->or` take further
values, `->not` inverts.

**Combining conditions inside `->filter` or `->find` needs `->as`.** `@` rebinds in
every method, so in `@.active->and(@.age->gt(30))` the inner `@` is the boolean
`@.active`, and the router returns `null` for the whole field with no error.
If the first condition is itself a method call (`@.a->eq("x")->and(…)`),
composition fails instead, with a misleading `CONNECTORS_UNRESOLVED_FIELD`
on every field of the type. Bind the element first:

```graphql
adults: users->filter(@->as($u)->echo($u.active)->and($u.age->gt(30)))
```

Use the `->as` form unless the router the service runs on is 2.18.0 or
later. Before 2.18.0, a `->filter` or `->find` after another list-producing
method, followed by a sub-selection
(`users->filter(@.active)->filter(@.age->gt(30)) { id name }`,
`users->filter(@.active)->find(@.age->gt(30)) { id name }`), composes, and
then the router will not start ("… all of its members are @inaccessible").
Without a sub-selection (`…->filter(…)->map(@.name)`) the chain works.

### Strings

| Method | Does | Example |
|---|---|---|
| `->split(sep)` | string to list | `$("a,b,c")->split(",")` is `["a","b","c"]` |
| `->trim`, `->trimStart`, `->trimEnd` | strip whitespace | `$("  hi  ")->trim` is `"hi"` |

A comma-separated header or field becomes a clean list with
`tags->split(",")->map(@->trim)`.

### Arithmetic and conversion

`->add` `->sub` `->mul` `->div` `->mod` work on integers and floats.
`->toString` renders a scalar (`null` becomes `""`; a list or object is an
error). `->parseInt` takes an optional base, so `$("ff")->parseInt(16)` is
`255`. `->jsonStringify` serialises a value to a JSON string, and `->jsonParse`
reverses it:
`$('{"x":1}')->jsonParse` is `{x: 1}`, which unpacks an API that embeds JSON in
a string field.

### The rest

| Method | Does |
|---|---|
| `->echo(x)` | returns its argument, ignoring the input |
| `->as($var[, expr])` | returns the input unchanged **and** binds it (or `expr`) to `$var` for later in the chain: `person->as($n, @.name)->echo($n)` is `"Ben"` |
| `->match([a, x], [b, y], [@, z])` | value translation; a final `[@, …]` pair is the catch-all |
| `->keysToCamelCase`, `->keysToCamelCaseDeep` | see [Renaming snake_case keys in bulk](#renaming-snake_case-keys-in-bulk) |

`->match` is how an enum crosses the wire boundary. Executed, with
`status: "open"`:

```graphql
state: status->match(['open', 'OPEN'], ['closed', 'CLOSED'], [@, 'UNKNOWN'])
```

gives `"OPEN"`, and an unlisted input gives `"UNKNOWN"`. Without the `[@, …]`
catch-all an unmatched value drops the output key, and the router returns
`null` with no error.
[naming.md](naming.md) explains when to translate and when to keep the wire
casing instead; `graphos-factory-core lint` checks the two agree
(`wire-enum-drift`).

## Absence: `?.`, `?->`, `??`, `?!`

These read like JavaScript's optional chaining and nullish coalescing, and
mostly behave like them. Executed through Router 2.17 against
`{"person": {"name": "Ben"}, "size": null, "n": 27}`:

| Selection | Result | JavaScript counterpart |
|---|---|---|
| `$.nobody?.absent` | `null` | `nobody?.absent` |
| `size?->jsonStringify` | `null` | `size?.jsonStringify()` |
| `size->jsonStringify` | `"null"` | none: the method runs on `null` |
| `n?->jsonStringify` | `"27"` | `n?.jsonStringify()` |
| `$.nobody.absent ?? "fb"` | `"fb"` | `nobody?.absent ?? "fb"` |
| `$.size ?! "fb"` | `null` | `size === undefined ? "fb" : size` |

Where they differ from JavaScript:

- **A missing step is never an exception.** `$.nobody.absent` is `null` with or
  without the `?`, where JavaScript's `nobody.absent` would throw. On a path,
  `?` marks the step you expect may be missing; it does not change the result.
- **`?->` is where `?` matters.** A method runs on `null` unless the step before
  it is guarded: `size->jsonStringify` turns a JSON `null` into the four-character
  string `"null"`, and `size?->jsonStringify` keeps it `null`.
- **A `?` can close a path.** `$.person.absent?` has no JavaScript form; it marks
  the last step as optional.
- **"Missing" is JavaScript's `undefined`.** `??` falls back when the value is
  `null` or missing, as in JavaScript. `?!` falls back only when it is missing,
  so an explicit `null` from the API survives. Use `??` for an error-message
  fallback, where anything beats empty, and `?!` when the API distinguishes
  "not set" from "set to null" and the schema should too.
- **Operators cannot be mixed in one chain.** `a ?? b ?? c` is fine;
  `a ?? b ?! c` does not compose.

A key that the selection drops and a key the API sent as `null` look the same
to the client: a nullable field reads `null`, and a non-null field nulls its
parent object.

**At v0.3** an operator chain has to be wrapped: `nn: $($.nullField ?? 'fallback')`.
The wrapped form works at both versions.

## Building requests

`queryParams` and `body` use the same language as `selection`; a header value
is a string template, and only its `{…}` expressions do. An entry whose value
is null is omitted from the request, which is how an optional argument stays
optional:

```graphql
http: {
  GET: "/widgets"
  queryParams: """
  limit: $args.limit
  cursor: $args.cursor
  """
}
```

A request body is a literal object. Keys are the API's wire names, not the
GraphQL ones, and a literal value can sit beside the arguments:

```graphql
body: """
{
  channel: $args.channel,
  thread_ts: $args.threadTs,
  kind: "message"
}
"""
```

Executed with `channel: "C1"`, `threadTs: "123.4"`, that sends
`{"channel":"C1","thread_ts":"123.4","kind":"message"}`. A body written as
plain mapping lines (`channel: $args.channel` on its own) also works.

Inside the braces, separate the entries with commas. The skill's tools read a
braced body as comma-separated: on gitea's issue-create body, dropping the
commas takes `source-coverage` from 8 request fields mapped to 0.

**At v0.3** the braces must be wrapped, `body: "$({ a: $args.a })"`; the
wrapped form is valid at both versions.

## Moving a workspace from v0.3 to v0.4

Use [`connect-migrate`](https://github.com/apollographql/connect-migrate). It
parses every `@connect(selection: …)` with the real Connectors parser at both
the schema's linked version and v0.4, and lists the sites whose meaning would
change ([Literals](#literals)) with the rewrite that preserves each one.

1. **Install it.** `curl -fsSL https://raw.githubusercontent.com/apollographql/connect-migrate/main/install.sh | sh`
   puts `connect-migrate` in `~/.local/bin`. The binaries are unsigned; where
   that is a problem, build it from the router repository instead:
   `cargo build --release --bin connect-migrate --features connect-migrate` in
   `apollo-federation/`.
2. **Follow its guide.** `connect-migrate agent-guide` prints the procedure.
   In short: `connect-migrate analyze <workspace> -o manifest.md`; apply the
   manifest's rewrites; put only its questions to the user; run `analyze`
   again **while the schema still links v0.3** until it reports nothing to
   change; bump the `@link` last, after step 3.
3. **Check the rest by hand.** `connect-migrate` reads only `selection`, but
   `body`, `queryParams`, `path`, `isSuccess` and `errors`, on `@connect` and
   on `@source`, are parsed at the linked version too. In each, find every
   quoted string, `true`, `false` or `null` after an alias, and rewrite it as
   `$."…"` to keep the v0.3 property read, or as `$( … )` if the literal was
   meant. Leave `headers` out: a header value is a string template, not a
   mapping.
4. **Move the workspace pins with it.** Set `connect_spec: v0.4` and
   `federation_version: "2.15.2"` in `.factory/workspace.yaml`, and `=2.15.2`
   in `supergraph.yaml`. The `federation/` link can move or stay: lint's
   `federation-drift` checks it against `federation_spec_version` when that is
   set, and against `federation_version` when it is not. To move it, link
   `federation/v2.15` and delete `federation_spec_version`, which is only for a
   link that differs from the plugin pin ([workspace-contract.md](workspace-contract.md)),
   or set it to `"2.15"`. To keep it, set `federation_spec_version` to the
   version it links, as the pilots do (`federation/v2.12`,
   `"2.12"`). `graphos-factory-core lint` and `render` fail until the pins and the
   schema agree.
5. **Treat the rewrites as schema edits.** Record them under SKILL.md's
   hand-edit policy, record the move with `graphos-factory-core decisions`, then
   compose and run the e2e layer.

## Troubleshooting

**A field is `null` and the response has no error.** The router reports
mapping problems this way: an unavailable method, a `->match` with no `[@, …]`
catch-all, `->and` inside `->filter`, a missing property, a non-null field left
empty. Check the selection against the payload, and assert the values you care
about in the e2e suite, which serves the schema through a real router. Results
from `rover connector test` are not evidence of what the router does.

**Every response-derived field is `null`, but literals and `$args` come
through.** The API or stub is answering without a JSON content type
(`application/octet-stream`, `text/plain`). Check the `Content-Type` before
debugging the selection.

**`GROUP_SELECTION_IS_NOT_OBJECT`.** A `{ … }` group, or a method whose result
composition can see is an object list (`raw: $.obj->entries`), targets a
`JSON`-typed field. Type the object. On a union or interface field, see
[Abstract types](#abstract-types).

**`INTERNAL` or `No matching shape found for selection` on a union or
interface.** An arm lacks a literal `__typename`, names a non-member, selects
a field its member lacks, or a member has no arm
([Abstract types](#abstract-types)).

## Appendix: the grammar at `connect/v0.4`

Extended Backus-Naur Form, as implemented at `federation_version: =2.15.2`.
Whitespace and `#` comments are allowed between any two tokens **except**
where `NO_SPACE` forbids it, which is why `$ args` and a broken-up identifier
are invalid.

```ebnf
JSONSelection        ::= LitExpr | NamedSelectionList
NamedSelectionList   ::= NamedSelection ("," NamedSelection)* ","? | NamedSelection*
SubSelection         ::= "{" NamedSelectionList "}"
NamedSelection       ::= "..." LitExpr
                       | Alias LitExpr
                       | PathSelection
Alias                ::= Key ":"
PathSelection        ::= (VarPath | KeyPath | AtPath | ExprPath) SubSelection?
VarPath              ::= "$" (NO_SPACE Identifier)? PathTail
KeyPath              ::= Key PathTail
AtPath               ::= "@" PathTail
ExprPath             ::= "$(" LitExpr ")" PathTail
PathTail             ::= "?"? (PathStep "?"?)*
NonEmptyPathTail     ::= "?"? (PathStep "?"?)+ | "?"
PathStep             ::= "." Key | "->" Identifier MethodArgs?
Key                  ::= Identifier | LitString
Identifier           ::= [a-zA-Z_] NO_SPACE [0-9a-zA-Z_]*
MethodArgs           ::= "(" (LitExpr ("," LitExpr)* ","?)? ")"
LitExpr              ::= LitOpChain | LitPath | LitPrimitive | LitObject | LitArray | PathSelection
LitOpChain           ::= LitExpr (LitOp LitExpr)+
LitOp                ::= "??" | "?!"
LitPath              ::= (LitPrimitive | LitObject | LitArray) NonEmptyPathTail
LitPrimitive         ::= LitString | LitNumber | "true" | "false" | "null"
LitString            ::= "'" ("\\'" | [^'])* "'" | '"' ('\\"' | [^"])* '"'
LitNumber            ::= "-"? ([0-9]+ ("." [0-9]*)? | "." [0-9]+)
LitObject            ::= SubSelection
LitArray             ::= "[" (LitExpr ("," LitExpr)* ","?)? "]"
NO_SPACE             ::= !SpacesOrComments
SpacesOrComments     ::= (Spaces | Comment)+
Spaces               ::= (" " | "\t" | "\r" | "\n")+
Comment              ::= "#" [^\n]*
```

What the prose above depends on:

- **`NamedSelectionList`** is either comma-separated or whitespace-separated,
  never mixed. That is [Separators](#separators).
- **`Alias LitExpr`** is why a literal can follow an alias
  ([Literals](#literals)).
- **A `PathSelection` contributes its key only when the path is one key long.**
  That is the single-key rule.

### What v0.3 lacks

The v0.3 grammar is this one with four differences:

```ebnf
JSONSelection        ::= NamedSelection*
SubSelection         ::= "{" NamedSelection* "}"
NamedSelection       ::= (Alias | "...")? PathSelection | Alias SubSelection
LitObject            ::= "{" (LitProperty ("," LitProperty)* ","?)? "}"
LitProperty          ::= Key ":" LitExpr
```

No commas in a selection list; an alias takes only a path or a sub-selection,
never a literal (which is why `a: "Book"` reads a property there); `...` is
rejected outright despite the grammar's `"..."`; and a literal object is its
own rule, reachable only inside `$( )`.

## Appendix: reproducing these measurements

Everything version-dependent here is a measurement. Two instruments did the
measuring:

- **Composition** (`rover supergraph compose` at the pin) decides what parses
  and what builds: the pin and link tables, the grammar, and the build error in
  [Troubleshooting](#troubleshooting).
- **The router** decides what a selection produces. Every runtime result in
  this file was read from Apollo Router 2.17.0 serving the composed supergraph
  against local stubs: a static JSON file per connector, served as
  `application/json`, and an echo server for request bodies.

To re-measure after changing `federation_version`, `connect_spec` or the router
version: write a schema that uses each form once, compose it, check that the
compose succeeded, and query it through the router, or run the workspace's e2e
layer, which does the same with WireMock.

Composition was measured with rover 0.41.0 at federation 2.12.0, 2.13.0,
2.14.0, 2.14.3, 2.15.0 and 2.15.2, at both connect spec versions, and at
2.15.1 for the grammar note under the pin table. Runtime results come from
Router 2.17.0 on schemas composed at 2.15.2 (`connect/v0.4`) and 2.12.0
(`connect/v0.3`). [Abstract types](#abstract-types) was measured the same way:
composition at 2.15.2 and at 2.12.0, and runtime on Router 2.17.0.

Every selection and every result in this file was produced that way. If you
change one, re-run it.
