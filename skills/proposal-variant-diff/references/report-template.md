# Report template

Use this structure. Keep sections that have no entries, and write "None" so the reader knows they were checked.

```markdown
# Proposal diff: <proposal title>

## Summary

- Verdict: <Breaking changes found | No breaking changes found | No breaking changes found, client impact unverified | Blocked by composition errors | Check pending>. Use "client impact unverified" when the check passed but tested 0 operations or ran against a different base.
- Proposal: <id>, status <status>, latest revision <revision id>
- Base: <graph>@<base variant> (<subgraph> revision <revision>, updated <time>)
- Head: <graph>@<proposal variant> (<subgraph> revision <revision>, updated <time>)
- Check: <check id>, status <status>, base variant <variant>, run for subgraph <name>, operations checked <n>
- Source variant changed since proposal creation (hasUpstreamChanges): <yes | no>. If yes, say the flag does not identify which subgraphs changed.

## Contradictions between the diff and the check

<Each item: what the diff shows, what the check shows, how you read the gap. "None" if they agree.>

## Breaking changes

<Coordinate, before -> after, why it breaks, affected operations from the check if any.>

## Non-breaking changes

<Coordinate, before -> after.>

## Composition-impacting changes

<Federation directive changes with the check's composition result.>

## Subgraph scope

- Changed: <subgraphs with differences>
- Unchanged: <subgraphs on the proposal variant with identical SDL>
- Added: <subgraphs only on the proposal variant, or None>
- Not part of the proposal: <subgraphs only on the source variant. Not removals>
- Removed: <only when comparing two full variants, otherwise None>

## Affected client operations

<From GetCheckResults: operation names, clients, counts. Note truncation and paging.>

## Not verified

<Anything you could not confirm: pending check, truncated change list, subgraphs skipped, assumptions.>
```

## Style

- Lead with the verdict. Put contradictions before detail.
- Show every changed element as a schema coordinate with before and after.
- State uncertainty explicitly. Do not soften a gap into a pass.
- Do not post the report to the proposal. Posting comments is out of scope for this skill.
