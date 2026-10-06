# The no-spec playbook

Before authoring, assess customer context ([`customer-context.md`](customer-context.md)). A readable
API contract does not establish that customer-defined fields or the chosen
scope are available. Reuse existing answers and record unresolved inputs.

When there is no OpenAPI document, you are the parser. The risk changes
shape entirely: with a spec the danger is believing a wrong spec; without
one it is **inventing endpoints that do not exist**. Everything below exists
to keep an invented endpoint from reaching the schema.

## The rule

Every inventory entry carries `provenance` and `confidence`. Nothing reaches
`selection.yaml` above `needs_review` unless it is confirmed by the vendor's
own documentation **or** a live probe. A plausible-looking endpoint you
inferred from a URL pattern is an entry in `unresolved[]`, not an operation.

| `provenance` | Means | Max confidence |
|---|---|---|
| `spec` | read from a machine-readable document | 1.0 |
| `docs` | stated in the vendor's documentation, with a URL in `sources.lock.yaml` | 0.9 |
| `probe` | a real request was sent and its response recorded | 1.0 for the shape |
| `inferred` | neither — pattern-matched from siblings | 0.4, and never selectable |

A `docs`-sourced operation gives you the request; only a `probe` gives you
the response shape you can safely type. Where the two disagree, the probe
wins and the disagreement goes in `memory.md`.

## Working the docs

1. **Find the reference index**, not the tutorials. Record its URL,
   retrieval time and the pages you used in `sources.lock.yaml` under a
   `kind: docs` entry with `used_for: [operationKey, …]`.
2. **Read per resource, not per page.** Build the inventory one resource at
   a time — list, get, create, update, delete — so the gaps are visible.
   An API with `listWidgets` and `getWidget` but no documented
   `createWidget` either has one (find it) or genuinely does not (record it
   in `unresolved[]` with that reason).
3. **Harvest every example payload.** A documented response example is the
   best shape evidence short of a probe. Save it under
   `.factory/samples/<operationKey>/` with an `x-source: docs` note, and
   feed it to `inferred-schema.json`.
4. **Record auth from the docs, precisely.** The header name, the scheme
   prefix, whether the credential is each caller's or one shared. "Bearer" vs
   "Token token=" vs a bare key is exactly the kind of detail an OpenAPI
   `apiKey` scheme does not carry, and getting it wrong produces a 401 that
   looks like a bad credential. When the API is OAuth-only with an
   authorization-code flow (Google, Slack, GitHub), write the `oauth2` block
   the spec reader would have written, with the same fields and a
   confidence per thing you learned separately
   ([spec-intake.md](spec-intake.md) §authentication has the spec-read
   shape):

   ```jsonc
   { "kind": "oauth2", "header": "Authorization", "prefix": "Bearer ",
     "scheme_name": "google", "source": "docs", "confidence": 0.9,
     "oauth2": { "flows": ["authorization_code"], "authorization_code": {
       "authorization_url": "https://accounts.google.com/o/oauth2/v2/auth",
       "token_url": "https://oauth2.googleapis.com/token",
       "source": "docs", "confidence": 0.9,                        // the endpoints page
       "scopes": [
         { "name": "https://www.googleapis.com/auth/spreadsheets.readonly",
           "description": "…", "source": "docs", "confidence": 0.9 },   // the scopes page
         { "name": "https://www.googleapis.com/auth/drive.readonly",
           "description": "…", "source": "inferred", "confidence": 0.4 } // a guess, not documented
       ] } } }
   ```

   Record `api.security` / `operations[].security` too when the docs say
   which scope each operation needs: they are facts like the rest of the
   inventory. The endpoints and scopes are `docs` at most (0.9): a probe
   proves that a *token* works, never that an authorization endpoint or a
   scope name is right, so a discovered inventory's flow records what the
   docs say, not a flow anyone has run. A scope you inferred from a
   sibling stays `inferred`; never present it as documented.
5. **Note the rate limit and the pagination style** before selecting
   anything. They shape every list operation.

## Probing

A probe is a real authenticated request against the real API. It is the
only way to close the gap between documented and actual behaviour, and it
carries real risk, so:

- **Read-only, always.** Probe `GET`s. Never probe a write against an
  account that matters; use a sandbox, and if the vendor has none, do not
  probe writes at all — say so and mark those operations `needs_review`.
- **Credentials come from the environment**, by name. A committed file
  records the *variable name* (`WIDGET_CO_TOKEN`), never a value.
- **Scrub before anything is written to disk.** Tokens, emails, real names,
  account ids, and anything that looks like a secret. A recorded sample
  that fails scrubbing is not committed — fix the scrubber or drop the
  sample.
- **Record the probe** in `sources.lock.yaml`: base URL, time, the
  operations covered, the credential variable name.

What a probe proves, in order of value:

1. the endpoint exists and the auth scheme is right (a 200 at all);
2. the response's real shape, including fields the docs omit and
   nullability the docs get wrong;
3. the pagination mechanics — request one page, follow the cursor, confirm
   the terminator (an empty string, a null, a missing key: all three occur).

## From samples to an oracle

Recorded samples become two things:

- **fixtures** for the WireMock layer, scrubbed and scoped to their cases;
- **`.factory/inferred-schema.json`**, a JSON Schema synthesised from all
  samples of an operation. It is the no-spec answer to the conformance
  layer: without it, a hand-authored connector has no independent oracle at
  all, and every test merely agrees with itself.

Synthesise conservatively — a field seen in one of three samples is
optional, not absent; a field seen as both string and null is nullable.
More samples make the oracle stricter, which is the right direction.

## When to stop discovering

Stop when every resource the user asked for has: a confirmed list and read
operation, a recorded response shape, a documented auth scheme, and a known
pagination style. Then present the inventory and let the user select. An
inventory that is 60% of a large API and honest about the other 40% is far
more useful than one that quietly guesses the rest.

## The instruments, as used on the deck-of-cards pilot

The playbook above is mechanised by four scripts; the order matters.

1. **`graphos-factory-core probe`** — one request, one sample. `--key` is the operation key
   the sample belongs to (with `{placeholders}` in the path, exactly as the
   inventory will spell it), `--url` the concrete request. GET only unless
   `--allow-write`; a credential comes from `--auth-env NAME` and only the
   name is stored. Everything is scrubbed before it touches disk and a
   residual secret-looking token stops the write. Each probe appends itself
   to `sources.lock.yaml`. **Probe the failures too**: a 404, an over-draw,
   an out-of-range parameter — the error shapes are part of the API, and
   they are where vendors' docs are wrongest.
2. **Write `inventory.json` by hand** from the docs and the probes: every
   operation with `provenance` (`docs` for the page, `probe` for a route only
   the source or a probe revealed), `confidence`, its parameters, and a
   `semantics` you decided — nothing derives it here. Point each
   `response.shape_ref` / `errors[].shape_ref` at a shape *name*; the shapes
   themselves come next.
3. **`graphos-factory-core infer --update-inventory`** fills those shapes from the samples,
   unioned across every operation that references the same name. Inference
   is conservative on its own: a field missing from some samples is
   optional, a field seen as string and null is nullable, and more samples
   only make the shape stricter. What it cannot do is tell apart two things
   that look identical in JSON, so `.factory/inference.yaml` carries
   **hints** — a human's knowledge about the API, applied at named paths.

   The hint *entries* are specific to one API; the hint *kinds* are the
   ones `graphos-factory-core infer` knows how to act on, and today there are two, both
   found by the deck-of-cards pilot:

   - `maps` — objects whose keys are data, not fields (`$.piles`, keyed by
     the caller's pile names). Without the hint every new key becomes a
     spurious field, and more samples make it worse. With it, one shape is
     inferred for the values and the object becomes a map.
   - `enums` — strings that are a closed vocabulary (`suit`, `value`).
     Without the hint they are `String`; with it the schema gets an enum
     and the oracle rejects a value outside the set. **Paths listed in one
     `enums` entry share a vocabulary** — put a card's `suit` under `cards`
     and under `piles.*.cards` together, but never mix two different
     vocabularies in one entry, or the oracle accepts a suit as a value. An
     enum is closed over *every* sample at those paths, so a shape inferred
     from two recordings does not reject the third value the API sends;
     still, record a complete vocabulary deliberately (draw the whole
     54-card deck) before trusting a closed set.

   **Two kinds is the evidence from one API, not the whole set.** Other
   APIs will raise ambiguities these do not cover — a `type` field that
   selects which other fields appear (a discriminator), ids that arrive as
   both `"123"` and `123`, JSON encoded inside a string, a `format` such as
   a timestamp that samples can never reveal, a field that is conditional
   on another rather than optional. When a real API forces one, add the
   hint kind to `graphos-factory-core infer` and this list together, and record
   why as a decision in the workspace's `decisions.json` (`graphos-factory-core
   decisions`). Do not add kinds speculatively: an
   unexercised hint is a promise the oracle cannot keep. Where a
   conservative default is honest (looser union types, optional fields),
   prefer it to a new kind.
4. **`graphos-factory-core fixtures`** turns recordings into WireMock stubs via
   `.factory/recordings.yaml` (case → sample). Nothing under
   `tests/fixtures/` is typed by hand, so the e2e stubs and the conformance
   oracle agree by construction. A recording no case can issue (the schema's
   non-null argument forbids the request) goes under `unreachable:` and is
   kept with `"x-cases": []`.

Then the same five layers as a spec workspace, plus `live.sh` — which, for
a keyless sandbox, runs with no setup at all.

What the pilot's probes found that neither the docs nor the source said:
a field the docs show as a string is an integer; a response the docs show
with a `remaining` key does not carry one; an out-of-range parameter the
source answers with 400 arrives as **200 with `success: false`**; an unknown
pile on one route is a **500 with HTML**. Every one of those shaped the
schema (`success`/`error` on every result, a nullable key, an error-mapping
fallback), and none was discoverable without a probe.
