# Rover Configuration

Installation, authentication, and environment configuration for Apollo Rover CLI.

## Installation

### macOS and Linux

```bash
# Install latest version
curl -sSL https://rover.apollo.dev/nix/latest | sh

# Install specific version (recommended for CI)
curl -sSL https://rover.apollo.dev/nix/v1.0.0 | sh

# Add to PATH (if not automatic)
export PATH="$HOME/.rover/bin:$PATH"
```

### npm (Cross-platform)

```bash
# Global install
npm install -g @apollo/rover

# Project-local install
npm install --save-dev @apollo/rover
npx -p @apollo/rover rover --version
```

### Windows PowerShell

```powershell
# Install latest
iwr 'https://rover.apollo.dev/win/latest' | iex

# Install specific version
iwr 'https://rover.apollo.dev/win/v1.0.0' | iex
```

### Docker

```bash
# Immutable versioned images (recommended for CI)
docker pull ghcr.io/apollographql/rover:1.0.0
docker run --rm -e APOLLO_KEY ghcr.io/apollographql/rover:1.0.0 <args>
```

### Verify Installation

```bash
rover --version
rover --help
```

## Authentication

Rover supports two authentication methods: OAuth login and API key profiles.

### OAuth Login (recommended for local development)

```bash
# Log in via browser (OAuth PKCE flow)
rover auth login

# Log in for a specific profile
rover auth login --profile staging
```

This opens your browser for authentication and stores an OAuth session on the profile.

### API Key Authentication

```bash
# Set via environment variable (recommended for CI/CD)
export APOLLO_KEY=your-api-key

# Or store a Personal API Key on a profile interactively
rover config auth

# Or store on a named profile
rover config auth --profile staging
```

### Client Credentials (for CI/CD)

```bash
export APOLLO_CLIENT_ID=your-client-id
export APOLLO_CLIENT_SECRET=your-client-secret
```

### Log Out

```bash
# Clear OAuth session
rover auth logout
```

### Verify Authentication

```bash
# Check current identity (OAuth or API key)
rover auth whoami

# Legacy (API key profiles only)
rover config whoami
```

## Environment Variables

### Core Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `APOLLO_KEY` | API key for GraphOS | `user:gh.xxx:yyy` |
| `APOLLO_GRAPH_REF` | Default graph reference | `my-graph@production` |
| `APOLLO_CLIENT_ID` | Client ID for client-credentials auth | `client-id` |
| `APOLLO_CLIENT_SECRET` | Client secret for client-credentials auth | `client-secret` |
| `APOLLO_TELEMETRY_DISABLED` | Disable anonymous telemetry | `true` |
| `APOLLO_HOME` | Override Rover's binary install directory | `~/.rover` |
| `APOLLO_CONFIG_HOME` | Override config storage location | `./myconfig/` |

### CI/CD Environment

```yaml
# GitHub Actions
env:
  APOLLO_KEY: ${{ secrets.APOLLO_KEY }}
  APOLLO_GRAPH_REF: my-graph@production

steps:
  - run: rover subgraph check $APOLLO_GRAPH_REF --name products --schema ./schema.graphql
```

## Profiles

Use profiles for different environments or accounts.

### Create Profile

```bash
# OAuth login (recommended)
rover auth login --profile staging

# API key
rover config auth --profile staging
```

### Use Profile

```bash
# Specify profile for command
rover subgraph fetch my-graph@staging --name products --profile staging
```

### List Profiles

```bash
rover config list
```

### Delete Profile

```bash
# Delete a single profile
rover config delete staging

# Clear all profiles
rover config clear
```

## Config Settings

Store and manage settings on profiles:

```bash
# Set a value
rover config set APOLLO_GRAPH_REF my-graph@prod --profile default

# Remove a stored setting
rover config unset APOLLO_GRAPH_REF --profile default

# Show all effective settings and their sources
rover config show
```

Settings resolve from a precedence chain: flag > environment > project file (`rover.yaml`) > explicit profile > default profile > builtin default.

## Project Manifest (rover.yaml)

A `rover.yaml` file in your project's `.rover/` directory pins plugin versions and project settings:

```yaml
plugins:
  supergraph: "=2.9.0"
  router: "=2.0.0"

settings:
  APOLLO_GRAPH_REF: my-graph@current
```

Run `rover plugin install` to resolve and lock plugin versions into `plugin-versions.lock`.

## Output Formats

### JSON

```bash
rover subgraph fetch my-graph@production --name products --format json
```

JSON output follows the envelope `{"json_version": "1", "data": {...}, "error": ...}`. Use `jq` for scripting:

```bash
rover subgraph fetch my-graph@production --name products --format json | jq -r '.data.sdl'
```

## Logging

```bash
# Available levels: error, warn, info, debug, trace
rover --log debug subgraph fetch my-graph@production --name products
```

## Telemetry

Rover collects anonymous usage data by default. Disable with:

```bash
export APOLLO_TELEMETRY_DISABLED=1
```

## Proxy and TLS

```bash
# HTTP proxy
export HTTP_PROXY=http://proxy.example.com:8080
export HTTPS_PROXY=http://proxy.example.com:8080

# Skip SSL verification (development only, not recommended)
rover --insecure-accept-invalid-certs <command>
```

## Updating Rover

```bash
# npm
npm update -g @apollo/rover

# curl (reinstall)
curl -sSL https://rover.apollo.dev/nix/latest | sh
```

## Troubleshooting

```bash
# Clear and re-authenticate
rover auth login

# Check installed location and version
which rover
rover --version

# Increase log verbosity
rover --log trace <command>
```
