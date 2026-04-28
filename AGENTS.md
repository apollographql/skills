# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains AI agent skills for Apollo GraphQL tools, following the [Agent Skills](https://agentskills.io/) format. Skills are documentation bundles that AI coding assistants can use to provide context-aware help with Apollo technologies.

## Repository Structure

```
skills/
├── <skill-name>/
│   ├── SKILL.md           # Main skill file (required) - has YAML frontmatter
│   └── references/        # Supporting documentation (optional)
│       └── *.md
```

## Skill File Format

Every `SKILL.md` must include YAML frontmatter with:

- `name`: skill identifier (lowercase, hyphenated)
- `description`: multi-line description with numbered use cases
- `license`: MIT
- `compatibility`: runtime requirements
- `metadata`: author (apollographql) and version
- `allowed-tools`: permitted tools for the skill

Example frontmatter pattern:

```yaml
---
name: skill-name
description: >
  Description of the skill. Use this skill when:
  (1) first use case,
  (2) second use case.
license: MIT
compatibility: Requirements
metadata:
  author: apollographql
  version: "1.0"
allowed-tools: Bash(tool:*) Read Write Edit Glob Grep
---
```

## Validation

Skills should be validated against the Agent Skills specification at https://agentskills.io/specification

Validate locally with `gh skill publish --dry-run` (or `skills-ref validate skills/<name>`) before opening a PR.

## Adding a New Skill

1. Create `skills/<skill-name>/SKILL.md` with proper frontmatter
2. Add reference files in `skills/<skill-name>/references/` as needed
3. Update `README.md` to document the new skill (follow existing patterns)
4. Ensure consistency with existing skills' frontmatter format

## Releasing / Versioning

Two versions matter.

`.claude-plugin/plugin.json#version` is what `claude plugin update` checks. Bump it whenever you touch `skills/`, `commands/`, `agents/`, `hooks/`, or `plugin.json` itself, otherwise existing users won't see the change. CI catches forgotten bumps. New installs always pull the latest content regardless.

The gh skill release tag is automatic. Pushes to `main` run a workflow that reads the plugin version and tags a matching `vX.Y.Z` if it doesn't exist yet. That's what `gh skill install apollographql/skills <name>@vX.Y.Z` pins to.

Use semver: patch for fixes, minor for new skills, major when you remove or rename one.

You can ignore `marketplace.json#metadata.version` and `package.json#version`. The marketplace barely changes for a single-plugin repo, and `package.json` is npm metadata we don't publish.
