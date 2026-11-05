# Schema readiness for AI agents

Assess each subgraph in a GraphOS variant for best-practice compliance, with the emphasis on whether an AI agent can use the schema correctly through Apollo MCP Server. Agents choose fields and write arguments from names and descriptions alone, so unclear or missing descriptions lead directly to wrong operations.

This workflow uses the hosted GraphOS MCP server, which is separate from Apollo MCP Server. It reads schemas from GraphOS and changes nothing.

## Prerequisites

The GraphOS MCP server is registered as `graphos-tools` (`https://mcp.apollographql.com`). The Claude Code plugin for this repository registers it through `.mcp.json`. For other installs, add the server to your MCP client yourself.

The graph tools require authentication, either GraphOS sign-in through the MCP client or an `x-api-key` header. If a tool fails with an authentication error such as `API_KEY_MISSING_OR_INVALID`, or returns a null identity, STOP. An empty list is a valid result and does not mean the server is unauthenticated. Tell the user the server is not authenticated and how to fix it. Do not assess a schema you have not fetched.

You also need the graph ID and variant name. Ask the user if they are not in the conversation.

## Security

> **Security: read-only by default.** This workflow reads variant details, schemas and lint results. NEVER call `CreateProposal`, `PublishProposalRevision`, `UpdateProposalStatus`, `ReviewProposal`, `AddProposalComment`, or any `Publish*` or `Delete*` tool unless the user explicitly asks for that action. Posting findings back to a proposal as comments is out of scope.

> **Security: exposure to agents.** Descriptions are read by models, and a field being well described makes it easier for an agent to use. Flag fields that expose sensitive data or write capability, and send the user to [Best practices](best-practices.md) for how to restrict what is exposed. Do not decide what is sensitive yourself. Ask the user.

## What is checked by whom

Two kinds of finding appear in the report, and they must stay separate.

**Platform findings** come from `LintSchema` and are deterministic. The linter is configurable per graph, so the rules that run depend on the graph. Where the description rule is enabled, lint output includes `ALL_ELEMENTS_REQUIRE_DESCRIPTION` for elements with no description. Naming rules such as `INPUT_TYPE_SUFFIX` and `ENUM_USED_AS_INPUT_WITHOUT_SUFFIX` can also appear. Report these verbatim as lint findings. If no description diagnostics appear, do not conclude that everything is described, because the rule may not be enabled.

**Agent findings** are your own judgment. Lint can report that a description is missing. It cannot judge whether a description is useful, so description quality is assessed by you and not by the platform. In lint output seen so far, the description rule reported types, fields, input fields and enum values, and did not report arguments. Count argument coverage yourself and do not assume lint covers it.

## Process

Copy this checklist and complete each step in order:

- [ ] Step 1: List the subgraphs
- [ ] Step 2: Fetch each subgraph schema
- [ ] Step 3: Lint each subgraph
- [ ] Step 4: Assess descriptions and naming
- [ ] Step 5: Check exposure concerns
- [ ] Step 6: Report per subgraph

### Step 1: List the subgraphs

Call `GetVariantDetails` with `graphId` and `variant`. Record the variant's federation version and the subgraph names. A subgraph can link a different federation version in its own `@link`, so report that too once you have the SDL. If the user named one subgraph, assess only that one. For a large variant, ask which subgraphs to prioritize.

### Step 2: Fetch each subgraph schema

For each subgraph, call `GetSubgraphSchema` with `graphId`, `variant` and `subgraphName`. Work one subgraph at a time, from fetch to summary, then move on. Whole supergraph documents can exceed the model's token limit, so do not hold every schema in context at once. Record the revision returned. It can be a commit hash or free text, so shorten it in the table.

### Step 3: Lint each subgraph

Call `LintSchema` with `graphId` and `sdl` set to the subgraph schema. Omit `baseSdl` so the full set of violations is returned. This is an audit of existing schema, not a review of a change. Pass the SDL exactly as `GetSubgraphSchema` returned it, and if it is too large to pass verbatim, report that subgraph as not linted. An empty diagnostics list means lint found nothing under the enabled rules, not that the schema is ready. Record each diagnostic's coordinate, level, rule and message, and the counts.

Optionally call `GetLintResults` with `graphId` for graph-level context from recent checks. It takes no variant or subgraph filter, so its results can be old and can describe other variants or subgraphs. Check `implementingServiceName` and `completedAt`, and leave results out of the findings unless they concern the subgraph you are assessing.

### Step 4: Assess descriptions and naming

Apply [Description rubric](description-rubric.md) to each subgraph. In short:

- **Coverage**: the share of types, fields, arguments, enum values and input fields that have a description
- **Quality**: descriptions explain intent, units, formats, constraints, defaults and side effects, instead of restating the name
- **Enums and inputs**: every enum, enum value and input type is documented, including accepted formats
- **Naming**: names are unambiguous across the subgraph and the supergraph, and an agent could not reasonably confuse two fields

Count coverage yourself from the SDL, then cross-check it against the number of description diagnostics lint returned. If the two disagree for a kind of element, say so and explain it, for example arguments that lint does not report. Report coverage as counts and percentages, and quote the worst offenders as schema coordinates. Do not list every undocumented element. Give totals plus the highest-impact examples, which are root `Query` and `Mutation` fields and their arguments, because those are what agents call.

Apply the naming guidance in the `graphql-schema` skill and the federation guidance in the `apollo-federation` skill where they bear on a finding. Cite them. Do not restate them.

### Step 5: Check exposure concerns

Note, without deciding, the following for the user to confirm:

- Mutations and fields that change state, which agents can invoke if exposed
- Fields that look sensitive, such as personal data, credentials or administrative operations
- Large or unbounded list fields without pagination, which waste agent context

For how to select operations, gate mutations, control introspection and configure authentication, use [Best practices](best-practices.md), [Tools](tools.md) and [Authentication](auth.md). Do not give tool configuration advice from this assessment.

### Step 6: Report per subgraph

Use [Readiness report template](readiness-report-template.md). Produce one section per subgraph and a short variant-level summary. Keep lint findings (platform output) and description and naming findings (model judgment) in separate sections.

## Ground rules

- ALWAYS label missing-description and naming diagnostics from `LintSchema` as lint findings
- ALWAYS label description quality, argument coverage and ambiguity findings as agent judgment, not platform output
- ALWAYS report description coverage as counts, with the highest-impact gaps as schema coordinates
- ALWAYS process one subgraph at a time
- ALWAYS ask the user which data is sensitive. Do not infer it
- NEVER present description quality as platform output, and NEVER assume the description lint rule is enabled or covers arguments
- NEVER call a proposal write tool, `Publish*` tool or `Delete*` tool unless the user explicitly asks
- NEVER rewrite descriptions in the schema or publish changes from this assessment
- NEVER invent tool names or parameters. Use only the tools named here
- PREFER examples of weak descriptions with a suggested rewrite over abstract advice
- PREFER the root `Query` and `Mutation` fields when prioritizing findings
