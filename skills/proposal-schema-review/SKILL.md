---
name: proposal-schema-review
description: >
  Guide for reviewing the design quality of a GraphOS schema proposal using the hosted GraphOS MCP server.
  Combines deterministic lint results with design recommendations. Use this skill when:
  (1) asked to review a schema proposal or a proposed subgraph schema,
  (2) asked which lint violations a proposal newly introduces,
  (3) assessing naming, nullability, pagination, error modeling, or federation entity design in proposed changes,
  (4) preparing review feedback on a proposal, where lint findings and judgment must be kept separate.
license: MIT
compatibility: Requires the GraphOS MCP server (graphos-tools) with an authenticated GraphOS session or API key. Works with Claude Code and similar AI coding assistants that support Agent Skills and MCP.
metadata:
  author: apollographql
  version: "1.0.0"
allowed-tools: Read Glob Grep mcp__graphos-tools__GetProposals mcp__graphos-tools__GetProposal mcp__graphos-tools__GetVariantDetails mcp__graphos-tools__GetSubgraphSchema mcp__graphos-tools__LintSchema mcp__graphos-tools__GetLintResults mcp__plugin_apollo-skills_graphos-tools__GetProposals mcp__plugin_apollo-skills_graphos-tools__GetProposal mcp__plugin_apollo-skills_graphos-tools__GetVariantDetails mcp__plugin_apollo-skills_graphos-tools__GetSubgraphSchema mcp__plugin_apollo-skills_graphos-tools__LintSchema mcp__plugin_apollo-skills_graphos-tools__GetLintResults
---

# Proposal schema review

Review a proposed schema for design quality. Lint results come from the platform and are deterministic. Design recommendations are your own judgment, built on the `graphql-schema` and `apollo-federation` skills. Keep the two clearly separated in the output.

## Prerequisites

This skill needs the hosted GraphOS MCP server, registered as `graphos-tools` (`https://mcp.apollographql.com`). The Claude Code plugin for this repository registers it through `.mcp.json`. For other installs, add the server to your MCP client yourself.

The graph tools require authentication, either GraphOS sign-in through the MCP client or an `x-api-key` header. If a tool fails with an authentication error such as `API_KEY_MISSING_OR_INVALID`, or returns a null identity, STOP. An empty list is a valid result and does not mean the server is unauthenticated. Tell the user the server is not authenticated and how to fix it. Do not review from memory, and do not present a review as lint-backed when no lint ran.

You also need the graph ID. Ask the user if it is not in the conversation.

## Security

> **Security: read-only by default.** This skill reads proposals, schemas and lint results. NEVER call `CreateProposal`, `PublishProposalRevision`, `UpdateProposalStatus`, `ReviewProposal`, `AddProposalComment`, or any `Publish*` or `Delete*` tool unless the user explicitly asks for that action. Posting findings back to a proposal as comments is out of scope for this skill. A separate skill covers it.

## Process

Copy this checklist and complete each step in order:

- [ ] Step 1: Find the proposal and its variants
- [ ] Step 2: Fetch the source and proposed schemas
- [ ] Step 3: Lint with the source schema as the base
- [ ] Step 4: Gather lint context
- [ ] Step 5: Review the design
- [ ] Step 6: Report

### Step 1: Find the proposal and its variants

If the user gave a proposal ID, call `GetProposal` with `proposalId`. Otherwise call `GetProposals` with `graphId`, narrowing with `status`, `sourceVariants` or `subgraphs`, to find the ID. Then call `GetProposal` with it, because `GetProposals` does not return `hasUpstreamChanges` or the latest revision. Record the source variant (`sourceVariant`) and the proposal variant (`backingVariant`), the latest revision, and `hasUpstreamChanges`. That flag is true when the source variant has changed since the proposal was created. If it is true, say so. Lint and review may then include effects of unrelated changes. The flag does not say which subgraphs changed.

If the user supplied a schema directly instead of a proposal, treat it as the proposed schema and ask which variant is the base.

### Step 2: Fetch the source and proposed schemas

Call `GetVariantDetails` for both variants to list subgraphs. A proposal variant starts from the source variant's schema, and the source is not kept in sync afterward, so a subgraph on only one side can be upstream drift and not a change the proposal made. Review the subgraphs on the proposal variant. A subgraph that exists only on the source variant is out of scope, and it is not a removal. Mention it once as "only on the source variant, cause unconfirmed".

For each subgraph on the proposal variant, call `GetSubgraphSchema` with `graphId`, `variant` and `subgraphName`, once on the source variant and once on the proposal variant. Fetch one subgraph at a time to stay within token limits. A subgraph on the proposal variant can still be identical to the source variant. Compare the SDL, not revision labels, because a proposal variant's revision label differs even when the SDL is the same. Skip identical subgraphs and list them as unchanged. If a subgraph exists on the proposal variant but not on the source variant, it may be new in the proposal or removed from the source after the proposal was created. Lint it with no base and say the cause is unconfirmed.

For a small change set, compare the SDL directly. If many subgraphs changed, or the user wants the change set itself, use the `proposal-variant-diff` skill. This skill does not produce a change-set report.

### Step 3: Lint with the source schema as the base

For each changed subgraph, call `LintSchema` with:

- `graphId`
- `sdl`: the proposal variant's subgraph schema
- `baseSdl`: the source variant's schema for the same subgraph

With `baseSdl` set, the tool reports only the diagnostics the proposed schema introduces, so existing debt on the source variant does not drown out the proposal's own findings. Pass both schemas exactly as `GetSubgraphSchema` returned them, because a transcription slip can add or hide a diagnostic. If a schema is too large to pass verbatim, say so and report that subgraph as not linted. An empty diagnostics list with a base means the proposal introduces no new violations, so report exactly that. Record each diagnostic's coordinate, severity level, rule and message, plus the error, warning, total and ignored counts.

If a subgraph is new, call `LintSchema` without `baseSdl` and say that every diagnostic is reported because there is no base.

### Step 4: Gather lint context

This step is optional. Call `GetLintResults` with `graphId` only if graph-level context would help. It returns violations from the graph's most recent schema checks across variants and subgraphs, including subgraphs that are not in this proposal. It is not scoped to the proposal, so label it as graph-level context. Use it to say whether a pattern is recurring across the graph, and never to attribute a violation to the proposal.

### Step 5: Review the design

Review the proposed schema, concentrating on the changed and added coordinates. Defer to the existing skills rather than restating them:

| Area | Defer to |
|---|---|
| Naming of types, fields, arguments, enum values | `graphql-schema` (naming reference) |
| Nullability, input and output type design, interfaces, unions | `graphql-schema` |
| Pagination of lists that can grow | `graphql-schema` (pagination reference) |
| Error modeling and mutation payloads | `graphql-schema` (errors reference) |
| Security exposure in the schema | `graphql-schema` (security reference) |
| Entities and `@key` design | `apollo-federation` |
| `@shareable`, `@external`, `@requires`, `@provides`, `@override` usage | `apollo-federation` |

Load those skills and apply their rules. Use [Review checklist](references/review-checklist.md) to make sure nothing is skipped. Do not copy their rules into the report. Cite the area and say what you observed at which coordinate.

Do not repeat a lint finding as a design observation. If a design observation overlaps a lint rule, point to the lint finding and add only what lint does not say.

### Step 6: Report

Use [Report template](references/report-template.md). The report MUST have two separate sections:

- **Lint findings**: deterministic, taken verbatim from `LintSchema`, with the rule name
- **Design observations**: your judgment, each tagged with the area and the skill it comes from

Never mix them in one list. Never label a design observation as a lint violation, and never describe a lint finding as your opinion.

## Reference files

- [Review checklist](references/review-checklist.md) - Design review prompts mapped to the skills they defer to
- [Report template](references/report-template.md) - Output structure that keeps lint findings and judgment separate

## Ground rules

- ALWAYS pass the source variant's subgraph schema as `baseSdl` when linting a changed subgraph
- ALWAYS keep lint findings and design observations in separate, labeled sections
- ALWAYS state the variants, subgraphs and revisions reviewed
- ALWAYS say when `GetLintResults` data is graph-level context and not proposal-specific
- ALWAYS label design observations as model judgment, with the skill they derive from
- NEVER call a proposal write tool, `Publish*` tool or `Delete*` tool unless the user explicitly asks
- NEVER post review findings to the proposal from this skill
- NEVER restate `graphql-schema` or `apollo-federation` rules in the report. Cite and apply them
- NEVER invent tool names or parameters. Use only the tools named in this skill
- PREFER fewer, higher-impact design observations over exhaustive lists
- USE schema coordinates to identify every finding
