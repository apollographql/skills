# Apollo GraphQL Agent Skills

A collection of Agent Skills for working with Apollo GraphQL tools and technologies.

## Installation

Install skills using the skills CLI:

```bash
npx skills add apollographql/skills/apollo-connectors
```

## Available Skills

### apollo-connectors

Help users write Apollo Connectors schemas to integrate REST APIs into GraphQL supergraphs.

**Features:**
- 5-step guided process: Research, Implement, Validate, Execute, Test
- Selection mapping with `@source` and `@connect` directives
- Entity patterns and batching support
- Validation with `rover` CLI commands

**Documentation:**
- [SKILL.md](skills/apollo-connectors/SKILL.md) - Main skill definition
- [Grammar Reference](skills/apollo-connectors/references/grammar.md)
- [Methods Reference](skills/apollo-connectors/references/methods.md)
- [Variables Reference](skills/apollo-connectors/references/variables.md)
- [Entities Guide](skills/apollo-connectors/references/entities.md)
- [Validation Commands](skills/apollo-connectors/references/validation.md)
- [Troubleshooting](skills/apollo-connectors/references/troubleshooting.md)

## License

Apache-2.0
