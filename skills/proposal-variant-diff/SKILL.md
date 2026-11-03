---
name: proposal-variant-diff
description: >
  Guide for comparing the schema changes in a GraphOS schema proposal against another variant of the same
  subgraph, using the hosted GraphOS MCP server. Use this skill when:
  (1) asked what a schema proposal changes compared with its source variant,
  (2) asked whether a proposal contains breaking changes,
  (3) comparing a subgraph schema between two variants, such as a proposal variant and production,
  (4) summarizing composition errors and affected client operations for a proposal,
  (5) reviewing a proposal before approving it, when the focus is the change set rather than design quality.
license: MIT
compatibility: Requires the GraphOS MCP server (graphos-tools) with an authenticated GraphOS session or API key. Works with Claude Code and similar AI coding assistants that support Agent Skills and MCP.
metadata:
  author: apollographql
  version: "1.0.0"
allowed-tools: Read Glob Grep mcp__graphos-tools__GetProposals mcp__graphos-tools__GetProposal mcp__graphos-tools__GetVariantDetails mcp__graphos-tools__GetSubgraphSchema mcp__graphos-tools__GetSchemaChecks mcp__graphos-tools__GetCheckResults
---

# Proposal variant diff

Compare the schema changes in a GraphOS schema proposal against another variant of the same subgraph, then combine that diff with schema check results. The GraphOS MCP server has no diff tool, so you produce the diff yourself from the two SDL documents.

## Prerequisites

This skill needs the hosted GraphOS MCP server, registered as `graphos-tools` (`https://mcp.apollographql.com`). The Claude Code plugin for this repository registers it through `.mcp.json`. For other installs, add the server to your MCP client yourself.

The graph tools require authentication, either GraphOS sign-in through the MCP client or an `x-api-key` header. If a tool fails with an authentication error such as `API_KEY_MISSING_OR_INVALID`, or returns a null identity or empty data, STOP. Tell the user the server is not authenticated and how to fix it. Do not guess at schema contents or produce a diff from memory.

You also need the graph ID. Ask the user if it is not in the conversation.

## Security

> **Security: read-only by default.** This skill reads schemas, proposals and check results. NEVER call `CreateProposal`, `PublishProposalRevision`, `UpdateProposalStatus`, `ReviewProposal`, `AddProposalComment`, or any `Publish*` or `Delete*` tool unless the user explicitly asks for that action. Posting findings back to a proposal as comments is out of scope for this skill.

`RunSubgraphCheck` is not read-only in the strict sense. It starts a check that appears in Studio, but it publishes nothing. Use it only as described in step 5, and tell the user before you call it.

## Process

Copy this checklist and complete each step in order:

- [ ] Step 1: Find the proposal
- [ ] Step 2: Identify what to compare
- [ ] Step 3: Fetch both subgraph schemas
- [ ] Step 4: Produce the structured diff
- [ ] Step 5: Get check results
- [ ] Step 6: Classify and reconcile
- [ ] Step 7: Report

### Step 1: Find the proposal

If the user gave a proposal ID, call `GetProposal` with `proposalId`. Otherwise call `GetProposals` with `graphId`, narrowing with `status`, `sourceVariants` or `subgraphs`, and page with `limit` and `offset`. Confirm the match with the user if more than one proposal fits.

From `GetProposal`, record the title, status, source variant (`sourceVariant`), proposal variant (`backingVariant`), latest revision (ID and summary), the schema check attached to that revision (`latestRevision.checkWorkflow`), and `hasUpstreamChanges`. That flag is true when the source variant has changed since the proposal was created. If it is true, say so prominently. The diff may then mix the proposal's changes with unrelated changes on the source variant. The flag does not say which subgraphs changed. To narrow it, compare each source subgraph's `updatedAt` (from `GetSubgraphSchema`) with the proposal's `createdAt`. A source subgraph updated after the proposal was created has changed upstream. One updated before has not. This covers only the subgraphs you fetched, so state it as partial evidence and say you cannot tell about the others.

### Step 2: Identify what to compare

Default comparison: source variant (base) against proposal variant (head). If the user names a different variant, such as `production`, use that as the base and say so in the report.

Call `GetVariantDetails` for both variants and compare the subgraph name lists.

A proposal variant is partial. It holds only the subgraphs the proposal changes, so it usually lists far fewer subgraphs than the source variant. Apply these rules:

- A subgraph on the source variant but not on the proposal variant is not part of the proposal. Do NOT report it as removed. List it once as "not part of the proposal" and move on.
- A subgraph on the proposal variant but not on the source variant is new. Report it as added and do not diff it field by field.
- A subgraph on both sides can still be identical. Compare the normalized SDL, not revision labels. A proposal variant's revision label differs from the source variant's even when the SDL is the same. Report identical subgraphs as unchanged.

When you compare two full variants instead of a proposal, a subgraph on only one side is added or removed.

### Step 3: Fetch both subgraph schemas

For each subgraph in scope, call `GetSubgraphSchema` with `graphId`, `variant` and `subgraphName`, once for the base and once for the head. Fetch one subgraph at a time. Whole supergraph documents can exceed the model's token limit. If the proposal touches many subgraphs, ask the user which to prioritize, or work through them one at a time and summarize each before moving on.

Record the revision and last update time returned for each fetch. They go in the report.

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

### Step 6: Classify and reconcile

Mark each diff entry breaking or non-breaking using the table in [Diff method](references/diff-method.md). Then compare your classification with the check results and list every disagreement:

- The diff shows a removal or type change, but the check reports no affected operations. Report this as "no observed client impact", not as safe. Check results reflect operations observed in the check's usage window, so unseen clients can still break. If `numberOfCheckedOperations` is 0, the check tested nothing and says nothing about client impact.
- The check's `baseVariant` or `implementingServiceName` differs from what you diffed. Report which comparison the check actually made.
- The check reports a schema change that your diff missed. Re-run the diff for that coordinate before reporting.
- The check reports composition errors. Treat the proposal as blocked regardless of your classification.
- The check was run against a different base or an older revision than the one you diffed. Flag it as stale.

### Step 7: Report

Use [Report template](references/report-template.md). Lead with the verdict and the contradictions, then the detail. State the proposal ID, variants, subgraphs, revisions and check ID so a reader can reproduce the result.

## Reference files

- [Diff method](references/diff-method.md) - Normalization, schema coordinates, change taxonomy and the breaking/non-breaking table
- [Report template](references/report-template.md) - Output structure for the diff report

For design feedback on the proposed schema rather than the change set, use the `proposal-schema-review` skill. For federation directive rules behind a composition error, use the `apollo-federation` skill.

## Ground rules

- ALWAYS state the base variant, head variant and the revision of each fetched schema in the report
- ALWAYS tell the user before calling `RunSubgraphCheck`
- ALWAYS report check results that contradict your diff, even if they favor the proposal
- ALWAYS report staleness when the source variant changed after the proposal was created
- NEVER call a proposal write tool, `Publish*` tool or `Delete*` tool unless the user explicitly asks
- NEVER claim a change is safe because a check found no affected operations
- NEVER report a subgraph that is missing from the proposal variant as removed
- NEVER invent tool names or parameters. Use only the tools named in this skill
- PREFER an existing check over starting a new one
- PREFER one subgraph at a time over whole-graph schema reads
- USE schema coordinates to identify every changed element
