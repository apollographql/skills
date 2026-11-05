---
name: proposal-review
description: >
  Guide for reviewing a GraphOS schema proposal using the hosted GraphOS MCP server. Produces a change set
  against the source variant, reconciles it with schema check results, and adds lint findings and design
  review, keeping platform output and model judgment separate. Use this skill when:
  (1) asked what a schema proposal changes compared with its source variant,
  (2) asked whether a proposal contains breaking changes,
  (3) comparing a subgraph schema between two variants, such as a proposal variant and production,
  (4) summarizing composition errors and affected client operations for a proposal,
  (5) asked to review a schema proposal or proposed subgraph schema,
  (6) asked which lint violations a proposal newly introduces,
  (7) assessing naming, nullability, pagination, error modeling, or federation entity design in proposed changes.
license: MIT
compatibility: Requires the GraphOS MCP server (graphos-tools) with an authenticated GraphOS session or API key. Works with Claude Code and similar AI coding assistants that support Agent Skills and MCP.
metadata:
  author: apollographql
  version: "1.0.0"
allowed-tools: Read Glob Grep mcp__graphos-tools__GetProposals mcp__graphos-tools__GetProposal mcp__graphos-tools__GetVariantDetails mcp__graphos-tools__GetSubgraphSchema mcp__graphos-tools__GetSchemaChecks mcp__graphos-tools__GetCheckResults mcp__graphos-tools__LintSchema mcp__graphos-tools__GetLintResults mcp__plugin_apollo-skills_graphos-tools__GetProposals mcp__plugin_apollo-skills_graphos-tools__GetProposal mcp__plugin_apollo-skills_graphos-tools__GetVariantDetails mcp__plugin_apollo-skills_graphos-tools__GetSubgraphSchema mcp__plugin_apollo-skills_graphos-tools__GetSchemaChecks mcp__plugin_apollo-skills_graphos-tools__GetCheckResults mcp__plugin_apollo-skills_graphos-tools__LintSchema mcp__plugin_apollo-skills_graphos-tools__GetLintResults
---

# Proposal review

Review a GraphOS schema proposal in three layers and keep them apart in the report:

- **Change set** (your diff, reconciled with the platform's check results): what changed, and which changes break
- **Lint findings** (platform output from `LintSchema`): deterministic and quoted verbatim
- **Design observations** (your judgment): built on the `graphql-schema` and `apollo-federation` skills

The GraphOS MCP server has no diff tool, so you produce the change set yourself from two SDL documents.

## Prerequisites

This skill needs the hosted GraphOS MCP server, registered as `graphos-tools` (`https://mcp.apollographql.com`). The Claude Code plugin for this repository registers it through `.mcp.json`. For other installs, add the server to your MCP client yourself.

The graph tools require authentication, either GraphOS sign-in through the MCP client or an `x-api-key` header. If a tool fails with an authentication error such as `API_KEY_MISSING_OR_INVALID`, or returns a null identity, STOP. An empty list is a valid result and does not mean the server is unauthenticated. Tell the user the server is not authenticated and how to fix it. Do not guess at schema contents, produce a diff from memory, or present a review as lint-backed when no lint ran.

You also need the graph ID. Ask the user if it is not in the conversation.

## Security

> **Security: read-only by default.** This skill reads proposals, schemas, check results and lint results. NEVER call `CreateProposal`, `PublishProposalRevision`, `UpdateProposalStatus`, `ReviewProposal`, `AddProposalComment`, or any `Publish*` or `Delete*` tool unless the user explicitly asks for that action. Posting findings back to a proposal as comments is out of scope for this skill.

`RunSubgraphCheck` is not read-only in the strict sense. It starts a check that appears in Studio, but it publishes nothing. It is not pre-approved. Use it only as described in step 5, and tell the user before you call it.

## Process

Copy this checklist and complete each step in order. If the user asked only for the change set, or only for the design review, run the steps that apply and write "Not run" for the rest in the report.

- [ ] Step 1: Find the proposal
- [ ] Step 2: Identify what to compare
- [ ] Step 3: Fetch both subgraph schemas
- [ ] Step 4: Produce the structured diff
- [ ] Step 5: Get check results
- [ ] Step 6: Lint with the source schema as the base
- [ ] Step 7: Review the design
- [ ] Step 8: Classify and reconcile
- [ ] Step 9: Report

### Step 1: Find the proposal

If the user gave a proposal ID, call `GetProposal` with `proposalId`. Otherwise call `GetProposals` with `graphId`, narrowing with `status`, `sourceVariants` or `subgraphs`, and page with `limit` and `offset`. Then call `GetProposal` with the ID, because `GetProposals` does not return `hasUpstreamChanges` or the latest revision. Confirm the match with the user if more than one proposal fits.

From `GetProposal`, record the title, status, source variant (`sourceVariant`), proposal variant (`backingVariant`), latest revision (ID, summary and `createdAt`), the schema check attached to that revision (`latestRevision.checkWorkflow`), the proposal's `createdAt`, and `hasUpstreamChanges`. That flag is true when the source variant has changed since the proposal was created. If it is true, say so prominently, because the diff may then mix the proposal's changes with unrelated changes on the source variant. The flag does not say which subgraphs changed. To narrow it, compare each source subgraph's `updatedAt` (from `GetSubgraphSchema`) with the proposal's `createdAt`. A source subgraph updated after the proposal was created has changed upstream. One updated before has not. This covers only the subgraphs you fetched, so state it as partial evidence.

If the user supplied a schema directly instead of a proposal, treat it as the proposed schema and ask which variant is the base.

### Step 2: Identify what to compare

Default comparison: source variant (base) against proposal variant (head). If the user names a different variant, such as `production`, use that as the base and say so in the report.

Call `GetVariantDetails` for both variants and compare the subgraph name lists.

A proposal variant starts from the source variant's schema, and the source is not kept in sync afterward. A subgraph that appears on only one side therefore has more than one possible cause, and the subgraph lists alone cannot tell you which. Do not assume the proposal made the change. Apply these rules:

- A subgraph on the source variant but not on the proposal variant may have been added to the source after the proposal was created, or the proposal variant may not carry it. Do NOT report it as removed. List it as "only on the source variant" with the cause marked unconfirmed, and move on.
- A subgraph on the proposal variant but not on the source variant may have been added by the proposal, or removed from the source after the proposal was created. Report it as "only on the proposal variant" and do not diff it field by field. Say it is added by the proposal only when the check's change list shows it.
- To narrow the cause, use `hasUpstreamChanges` and the `updatedAt` comparison from step 1. Say what the evidence supports and what it does not.
- A subgraph on both sides can still be identical. Compare the normalized SDL, not revision labels. A proposal variant's revision label differs from the source variant's even when the SDL is the same. Report identical subgraphs as unchanged.

When you compare two full variants instead of a proposal, a subgraph on only one side is added or removed.

### Step 3: Fetch both subgraph schemas

For each subgraph on both sides that is not identical, call `GetSubgraphSchema` with `graphId`, `variant` and `subgraphName`, once for the base and once for the head. Fetch one subgraph at a time. Whole supergraph documents can exceed the model's token limit. If the proposal touches many subgraphs, ask the user which to prioritize, or work through them one at a time and summarize each before moving on. Record the revision and last update time returned for each fetch.

### Step 4: Produce the structured diff

Follow [Diff method](references/diff-method.md). In short: normalize both documents, index every element by schema coordinate (`Type.field(arg:)`), then list added, removed and changed types, fields, arguments, directives, enum values, nullability, defaults and deprecations. Do not diff raw text. Reordering and whitespace are not changes.

### Step 5: Get check results

Prefer an existing check over starting a new one:

1. Use the schema check attached to the latest revision in `GetProposal`. It is returned as `latestRevision.checkWorkflow`. Pass its `id` to `GetCheckResults` as `checkId`, with `graphId`.
2. If the revision has no `checkWorkflow`, call `GetSchemaChecks` filtered by `variants` and `subgraphs` to find a check, then `GetCheckResults`.
3. Only if no usable check exists, or it predates the latest revision, offer to call `RunSubgraphCheck` with `graphId`, `variant` (the base variant), `subgraphName` and `proposedSchema` (the head SDL from step 3). Wait for the user's go-ahead. The call returns a workflow ID and Studio URL, not a result. Pass the returned ID to `GetCheckResults` as `checkId`. The tool description calls it a workflow ID while `GetCheckResults` takes `checkId`, so if the call is rejected, say so rather than guessing at another ID.

Before you use the results, read these fields and put them in the report:

- `baseVariant`: the variant the check compared against. For a proposal check this can be the proposal variant and not the source variant, so the change list may not match your source-to-proposal diff.
- `implementingServiceName`: the subgraph the check was run for. The change list can describe a different subgraph. If it does, say so and report what the list says. Do not infer why.
- `numberOfCheckedOperations`: how many client operations were tested. If it is 0, report "no operations were checked", not "no affected operations".
- `createdAt`: `GetCheckResults` does not say which revision the check ran against. Compare it with `latestRevision.createdAt` from `GetProposal` and report the comparison. A check created before the latest revision is stale.

The check may still be running. If so, report it as pending and do not infer results.

`GetCheckResults` pages affected operations with `affectedOperationsLimit` (maximum 50) and `affectedOperationsOffset`, and reports `areChangesTruncated` when the change list was capped. Fetch further pages when the count matters, and note any truncation.

### Step 6: Lint with the source schema as the base

For each changed subgraph, call `LintSchema` with `graphId`, `sdl` (the proposal variant's subgraph schema) and `baseSdl` (the source variant's schema for the same subgraph). With `baseSdl` set, the tool reports only the diagnostics the proposed schema introduces, so existing debt on the source variant does not drown out the proposal's own findings.

Pass both schemas exactly as `GetSubgraphSchema` returned them, because a transcription slip can add or hide a diagnostic. If a schema is too large to pass verbatim, say so and report that subgraph as not linted. An empty diagnostics list with a base means the proposal introduces no new violations, so report exactly that. Record each diagnostic's coordinate, severity level, rule and message, plus the error, warning, total and ignored counts. For a subgraph that is only on the proposal variant, call `LintSchema` without `baseSdl` and say that every diagnostic is reported because there is no base.

Optionally call `GetLintResults` with `graphId` for graph-level context. It returns violations from the graph's most recent schema checks across variants and subgraphs, including ones outside this proposal. Label it as graph-level context, use it only to say whether a pattern recurs, and never use it to attribute a violation to the proposal.

### Step 7: Review the design

Review the proposed schema, concentrating on the changed and added coordinates. Defer to the existing skills rather than restating them:

| Area | Defer to |
|---|---|
| Naming, nullability, input and output types, interfaces, unions | `graphql-schema` |
| Pagination of lists that can grow | `graphql-schema` (pagination reference) |
| Error modeling and mutation payloads | `graphql-schema` (errors reference) |
| Security exposure in the schema | `graphql-schema` (security reference) |
| Entities, `@key`, `@shareable`, `@external`, `@requires`, `@provides`, `@override` | `apollo-federation` |

Load those skills and apply their rules. Use [Review checklist](references/review-checklist.md) to make sure nothing is skipped. Do not copy their rules into the report. Cite the area and say what you observed at which coordinate. Do not repeat a lint finding as a design observation. If a design observation overlaps a lint rule, point to the lint finding and add only what lint does not say.

### Step 8: Classify and reconcile

Mark each diff entry breaking or non-breaking using the table in [Diff method](references/diff-method.md). Then compare your classification with the check results and list every disagreement:

- The diff shows a removal or type change, but the check reports no affected operations. Report this as "no observed client impact", not as safe. Check results reflect operations observed in the check's usage window, so unseen clients can still break. If `numberOfCheckedOperations` is 0, the check tested nothing and says nothing about client impact.
- The check's `baseVariant` or `implementingServiceName` differs from what you diffed. Report which comparison the check actually made.
- The check reports a schema change that your diff missed. Re-run the diff for that coordinate before reporting.
- The check reports composition errors. Treat the proposal as blocked regardless of your classification.
- The check was run against a different base or an older revision than the one you diffed. Flag it as stale.

### Step 9: Report

Use [Report template](references/report-template.md). Lead with the verdict and the contradictions, then the detail. The report MUST keep three things in separate sections: the change set, lint findings (verbatim, with the rule name) and design observations (each tagged with its area and source skill). Never label a design observation as a lint violation, and never describe a lint finding as your opinion. State the proposal ID, variants, subgraphs, revisions and check ID so a reader can reproduce the result.

## Reference files

- [Diff method](references/diff-method.md) - Normalization, schema coordinates, change taxonomy and the breaking/non-breaking table
- [Review checklist](references/review-checklist.md) - Design review prompts mapped to the skills they defer to
- [Report template](references/report-template.md) - Output structure that keeps the change set, lint findings and judgment separate

For federation directive rules behind a composition error, use the `apollo-federation` skill. For naming, nullability, pagination and error design, use `graphql-schema`.

## Ground rules

- ALWAYS state the base variant, head variant and the revision of each fetched schema in the report
- ALWAYS pass the source variant's subgraph schema as `baseSdl` when linting a changed subgraph
- ALWAYS keep the change set, lint findings and design observations in separate, labeled sections
- ALWAYS tell the user before calling `RunSubgraphCheck`
- ALWAYS report check results that contradict your diff, even if they favor the proposal
- ALWAYS report staleness when the source variant changed after the proposal was created
- ALWAYS say when `GetLintResults` data is graph-level context and not proposal-specific
- NEVER call a proposal write tool, `Publish*` tool or `Delete*` tool unless the user explicitly asks
- NEVER post findings to the proposal from this skill
- NEVER claim a change is safe because a check found no affected operations
- NEVER report a subgraph that is missing from one variant as added or removed by the proposal without evidence. It may be upstream drift on the source variant
- NEVER restate `graphql-schema` or `apollo-federation` rules in the report. Cite and apply them
- NEVER invent tool names or parameters. Use only the tools named in this skill
- PREFER an existing check over starting a new one
- PREFER one subgraph at a time over whole-graph schema reads
- PREFER fewer, higher-impact design observations over exhaustive lists
- USE schema coordinates to identify every finding
