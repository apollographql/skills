# Read-only selection review

Use this optional instrument to explain or validate proposed changes to selection.yaml.
It is available from an ordinary agent chat and does not require a UI or a service process.

```sh
graphos-factory-core selection review /path/to/workspace
graphos-factory-core selection review /path/to/workspace --candidate /path/to/candidate.yaml --expect-input INPUT_TOKEN
graphos-factory-core selection review /path/to/workspace --candidate /path/to/candidate.yaml --expect-input INPUT_TOKEN --expect-review REVIEW_TOKEN
```

The first call returns JSON containing the current selection and an input token. Author
candidate YAML separately, then pass the input token with that candidate. Validation checks
workspace, inventory and selection schemas and requires operation keys to exist in inventory.
The report preserves exact YAML and describes additions, removals, changed decisions,
explicitly unconfirmed response hints and writes assigned to GraphQL queries.

The input token covers the canonical workspace path, embedded inventory/selection schemas,
and the bytes or absence of workspace.yaml, inventory.json, selection.yaml, sources.lock.yaml,
applied.lock.yaml, decisions.json, findings.json and memory.md inside .factory. The review token additionally
binds the exact candidate bytes. Expected-token mismatches refuse the review.

Tokens establish observed content equality, not uninterrupted history or user approval.
Edit-then-revert between observations cannot be detected. A report is not comprehensive lint,
proof of confirmation, a write lock or permission to save. .factory and its named inputs
cannot be symlinks. Successful calls emit JSON contract version 1; refusals exit 1 with stderr.
No call writes files, confirms hints or starts apply. The usual user decisions and validation
rules remain in force whether or not this instrument is used.
