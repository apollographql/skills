---
name: apollo-router
description: >
  Guide for configuring and running Apollo Router for federated GraphQL supergraphs. Use this skill when:
  (1) setting up Apollo Router to run a supergraph,
  (2) configuring routing, headers, or CORS,
  (3) implementing custom plugins (Rhai scripts or coprocessors),
  (4) configuring telemetry (tracing, metrics, logging),
  (5) troubleshooting Router performance or connectivity issues.
license: MIT
compatibility: Linux/macOS/Windows. Requires a composed supergraph schema from Rover or GraphOS.
metadata:
  author: apollographql
  version: "1.0.0"
allowed-tools: Bash(router:*) Bash(./router:*) Bash(rover:*) Bash(curl:*) Bash(docker:*) Read Write Edit Glob Grep
---

# Apollo Router Guide

Apollo Router is a high-performance graph router written in Rust for running Apollo Federation 2 supergraphs. It sits in front of your subgraphs and handles query planning, execution, and response composition.

## Quick Start

### Step 1: Install

```bash
# macOS/Linux
curl -sSL https://router.apollo.dev/download/nix/latest | sh

# Move to PATH
sudo mv router /usr/local/bin/

# Verify installation
router --version
```

Docker:
```bash
docker pull ghcr.io/apollographql/router:latest
```

### Step 2: Get a Supergraph Schema

Create with Rover:
```bash
# Compose from local files
rover supergraph compose --config supergraph.yaml > supergraph.graphql

# Or fetch from GraphOS
rover supergraph fetch my-graph@production > supergraph.graphql
```

### Step 3: Run the Router

```bash
# With local schema
router --supergraph supergraph.graphql

# With configuration file
router --supergraph supergraph.graphql --config router.yaml

# Development mode (relaxed security, better errors)
router --dev --supergraph supergraph.graphql
```

Default endpoint: `http://localhost:4000`

## Configuration Overview

Create `router.yaml` to configure the Router:

```yaml
# Listen address
supergraph:
  listen: 127.0.0.1:4000
  introspection: true

# Enable GraphQL Sandbox
sandbox:
  enabled: true

# Header propagation
headers:
  all:
    request:
      - propagate:
          matching: "^x-.*"

# CORS configuration
cors:
  origins:
    - http://localhost:3000
  allow_headers:
    - Content-Type
    - Authorization
```

## Running Modes

| Mode | Command | Use Case |
|------|---------|----------|
| Local schema | `router --supergraph ./schema.graphql` | Development, CI/CD |
| GraphOS managed | `APOLLO_KEY=... APOLLO_GRAPH_REF=my-graph@prod router` | Production with auto-updates |
| Development | `router --dev --supergraph ./schema.graphql` | Local development |
| Hot reload | `router --hot-reload --supergraph ./schema.graphql` | Schema changes without restart |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `APOLLO_KEY` | API key for GraphOS |
| `APOLLO_GRAPH_REF` | Graph reference (`graph-id@variant`) |
| `APOLLO_ROUTER_CONFIG_PATH` | Path to `router.yaml` |
| `APOLLO_ROUTER_SUPERGRAPH_PATH` | Path to supergraph schema |
| `APOLLO_ROUTER_LOG` | Log level (off, error, warn, info, debug, trace) |
| `APOLLO_ROUTER_LISTEN_ADDRESS` | Override listen address |

## Reference Files

Detailed documentation for specific topics:

- [Configuration](references/configuration.md) - YAML configuration reference
- [Headers](references/headers.md) - Header propagation and manipulation
- [Plugins](references/plugins.md) - Rhai scripts and coprocessors
- [Telemetry](references/telemetry.md) - Tracing, metrics, and logging
- [Troubleshooting](references/troubleshooting.md) - Common issues and solutions

## Common Patterns

### Production Deployment

```yaml
# router.yaml for production
supergraph:
  listen: 0.0.0.0:4000
  introspection: false

sandbox:
  enabled: false

telemetry:
  exporters:
    tracing:
      otlp:
        enabled: true
        endpoint: http://collector:4317

include_subgraph_errors:
  all: false
```

### With Docker

```bash
docker run -p 4000:4000 \
  -v ./supergraph.graphql:/etc/router/supergraph.graphql \
  -v ./router.yaml:/etc/router/router.yaml \
  ghcr.io/apollographql/router:latest \
  --supergraph /etc/router/supergraph.graphql \
  --config /etc/router/router.yaml
```

### GraphOS Managed

```bash
export APOLLO_KEY=service:my-graph:key
export APOLLO_GRAPH_REF=my-graph@production
router
```

The Router automatically fetches and updates the supergraph schema from GraphOS.

## CLI Reference

```
router [OPTIONS]

Options:
  -s, --supergraph <PATH>    Path to supergraph schema file
  -c, --config <PATH>        Path to router.yaml configuration
      --dev                  Enable development mode
      --hot-reload           Watch for schema changes
      --log <LEVEL>          Log level (default: info)
      --listen <ADDRESS>     Override listen address
  -V, --version              Print version
  -h, --help                 Print help
```

## Ground Rules

- ALWAYS use `--dev` mode for local development (enables introspection and sandbox)
- ALWAYS disable introspection and sandbox in production
- PREFER GraphOS managed mode for production (automatic updates, metrics)
- USE `--hot-reload` for local development with file-based schemas
- NEVER expose `APOLLO_KEY` in logs or version control
- USE environment variables for sensitive configuration
- PREFER YAML configuration over command-line arguments for complex setups
- TEST configuration changes locally before deploying to production
