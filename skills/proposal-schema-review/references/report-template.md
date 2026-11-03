# Report template

Keep lint findings and design observations in separate sections. Keep sections with no entries and write "None". For an optional section you skipped, write "Not called".

```markdown
# Schema review: <proposal title>

## Scope

- Proposal: <id>, status <status>, latest revision <revision id>
- Source variant: <graph>@<variant>
- Proposal variant: <graph>@<variant>
- Subgraphs reviewed: <names, with source and proposal revisions>
- Subgraphs unchanged (identical on both variants): <names or None>
- Subgraphs not part of the proposal (source variant only): <names. Not removals>
- Source variant changed since proposal creation (hasUpstreamChanges): <yes | no>. If yes, say the flag does not identify which subgraphs changed.

## Lint findings (deterministic, from LintSchema)

Linted with the source variant's schema as the base, so only newly introduced violations appear.

| Subgraph | Coordinate | Level | Rule | Message |
|---|---|---|---|---|

Counts: <errors> errors, <warnings> warnings, <total> total, <ignored> ignored.

<For a new subgraph with no base, say that all diagnostics are reported.>

## Graph-level lint context (from GetLintResults, optional)

<Recurring patterns across the graph's recent checks, which can include other variants and subgraphs. Not specific to this proposal. Write "Not called" if you did not call the tool.>

## Design observations (model judgment)

Each item is an opinion from this review. It was not produced by the platform.

1. <Coordinate>: <observation and recommendation>. Area: <naming | nullability | pagination | errors | security | entities | shared fields | evolution>. Basis: <graphql-schema | apollo-federation>.

## Not reviewed

<Subgraphs skipped, data not available, questions for the user, anything unverified.>
```

## Style

- Lint rows are copied from the tool output. Do not rephrase rule names or messages.
- Design observations lead with the coordinate and say what to change, not only what is wrong.
- Rank design observations by impact. Prefer a short list.
- Do not post the report to the proposal. Posting comments is out of scope for this skill.
