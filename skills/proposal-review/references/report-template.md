# Report template

Use this structure. Keep sections that have no entries, and write "None" so the reader knows they were checked. For a step you skipped, write "Not run". Keep the change set, lint findings and design observations in separate sections.

```markdown
# Proposal review: <proposal title>

## Summary

- Verdict: <Breaking changes found | No breaking changes found | No breaking changes found, client impact unverified | Blocked by composition errors | Check pending>. Use "client impact unverified" when the check passed but tested 0 operations, ran against a different base or for a different subgraph than the one that changed, predates the latest revision, does not exist, or was not run because the user declined `RunSubgraphCheck`. Use plain "No breaking changes found" only when a current check tested one or more operations against the source variant.
- Proposal: <id>, status <status>, latest revision <revision id>
- Base: <graph>@<base variant> (<subgraph> revision <revision>, updated <time>)
- Head: <graph>@<proposal variant> (<subgraph> revision <revision>, updated <time>)
- Check: <check id or "none">, status <status>, base variant <variant>, run for subgraph <name>, operations checked <n>, created <check createdAt> (<not older than the latest revision | stale, as it predates the latest revision created <time>>)
- Reviews: <decisions from GetProposal, or None>
- Source variant changed since proposal creation (hasUpstreamChanges): <yes | no>. If yes, say the flag does not identify which subgraphs changed.

## Contradictions between the diff and the check

<Each item: what the diff shows, what the check shows, how you read the gap. "None" if they agree.>

## Subgraph scope

- Changed: <subgraphs with differences>
- Unchanged: <subgraphs on the proposal variant with identical SDL>
- Only on the proposal variant: <subgraphs, or None. Added by the proposal only if the check's change list shows it, otherwise cause unconfirmed>
- Only on the source variant: <subgraphs, or None. Not reported as removals. Cause unconfirmed, possibly added upstream after the proposal was created>
- Removed: <only when comparing two full variants, otherwise None>

## Change set (agent diff, reconciled with the check)

### Breaking changes

<Coordinate, before -> after, why it breaks, affected operations from the check if any.>

### Non-breaking changes

<Coordinate, before -> after.>

### Composition-impacting changes

<Federation directive changes with the check's composition result.>

### Affected client operations

<From GetCheckResults: operation names, clients, counts. Note truncation and paging.>

## Lint findings (platform output, from LintSchema)

Linted with the source variant's schema as the base, so only newly introduced violations appear.

| Subgraph | Coordinate | Level | Rule | Message |
|---|---|---|---|---|

For an empty result, write "No new violations" in place of rows.

Counts: <errors> errors, <warnings> warnings, <total> total, <ignored> ignored.

<For a subgraph with no base, say that all diagnostics are reported.>

### Graph-level lint context (from GetLintResults, optional)

<Recurring patterns across the graph's recent checks, which can include other variants and subgraphs. Not specific to this proposal. Write "Not run" if you did not call the tool.>

## Design observations (agent judgment)

Each item is an opinion from this review. It was not produced by the platform.

1. <Coordinate>: <observation and recommendation>. Area: <naming | nullability | pagination | errors | security | entities | shared fields | evolution>. Basis: <graphql-schema | apollo-federation>.

## Not verified

<Anything you could not confirm: pending check, truncated change list, subgraphs skipped or not linted, assumptions, questions for the user.>
```

## Style

- Lead with the verdict. Put contradictions before detail.
- Show every changed element as a schema coordinate with before and after.
- Lint rows are copied from the tool output. Do not rephrase rule names or messages.
- Design observations lead with the coordinate and say what to change, not only what is wrong. Rank them by impact and prefer a short list.
- State uncertainty explicitly. Do not soften a gap into a pass.
- Do not post the report to the proposal. Posting comments is out of scope for this skill.
