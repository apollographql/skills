# Report template

Produce one section per subgraph and a variant-level summary. Keep sections with no entries and write "None".

```markdown
# MCP readiness: <graph>@<variant>

## Summary

- Federation version: <variant version> (subgraphs link <versions from their @link>)
- Subgraphs assessed: <names>
- Subgraphs not assessed, and why: <names or "None">

| Subgraph | Revision | Description coverage | Lint errors | Lint warnings | Rating |
|---|---|---|---|---|---|

Ratings, description quality and argument coverage are agent judgment. Missing-description and naming diagnostics under "Lint findings" are platform output.

## <Subgraph name>

### Lint findings (platform output, from LintSchema)

| Coordinate | Level | Rule | Message |
|---|---|---|---|

Counts: <errors> errors, <warnings> warnings, <total> total, <ignored> ignored.

### Description coverage (agent count, cross-checked against lint)

| Element | Described | Total | Coverage |
|---|---|---|---|

Lint reported <n> missing-description diagnostics. <Say whether this matches your count, and why not, for example arguments, which lint does not report, or the rule not being enabled.>

Highest-impact gaps (root fields and arguments first):

- <Coordinate>

### Description quality (agent assessment)

- <Coordinate>: <what is missing: intent, units, format, constraint, side effect>. Suggested rewrite: "<text>"

### Enums and input types (agent assessment)

- <Coordinate>: <gap>

### Naming (agent assessment)

- <Coordinate>: <ambiguity>. Suggested change: <rename or description>

### Exposure notes for the user to confirm

- <State-changing fields, possibly sensitive fields, unbounded lists. Do not decide.>

### Rating

<Ready | Nearly ready | Not ready>, with the basis in one sentence.

## Next steps for tool exposure

For choosing which operations to expose, mutation gating and authentication, see [Best practices](best-practices.md), [Tools](tools.md) and [Authentication](auth.md).

## Not assessed

<Anything skipped, unavailable or unverified.>
```

## Style

- Report coverage as counts and percentages. List only the highest-impact gaps, not every undocumented element.
- Quote suggested rewrites for the worst offenders only.
- When many diagnostics share a rule, group them in one row per rule with the coordinates listed. Keep rule names and message text verbatim. Keep the counts exact.
- Keep platform output and agent judgment in separate sections. Do not call a finding lint output unless `LintSchema` returned it.
- Do not post the report to a proposal or change the schema. Posting comments and publishing are out of scope for a readiness assessment.
