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
# GitHub Container Registry (recommended for CI)
docker pull ghcr.io/apollographql/rover:1.0.0
docker run --rm -e APOLLO_KEY -v "$PWD:/workspace" -w /workspace \
  ghcr.io/apollographql/rover:1.0.0 subgraph check my-graph@prod \
  --name products --schema ./schema.graphql

# Docker Hub
docker pull apollograph/rover:1.0.0
```

Pin to a specific version tag for reproducible CI builds. Tags are immutable per release.

### Verify Installation

```bash
rover --version
rover --help
```

## Authentication

Rover supports two authentication methods: OAuth browser login and API key authentication.

### OAuth Login (recommended for local development)

```bash
# Opens browser for OAuth authentication
rover auth login

# Login on a specific profile
rover auth login --profile staging

# Login without browser (device code flow)
rover auth login --no-browser
```

### OAuth Logout

```bash
rover auth logout
rover auth logout --profile staging
```

### OAuth Identity

```bash
rover auth whoami
rover auth whoami --profile staging
```

### API Key Authentication

```bash
# Interactive API key entry
rover config auth

# Set via environment variable (recommended for CI/CD)
export APOLLO_KEY=your-api-key

# Configure directly on a profile
rover config auth --profile staging
```

### Client Credentials (OAuth 2.0)

For CI/CD environments, you can authenticate with client credentials instead of an API key:

```bash
export APOLLO_CLIENT_ID=your-client-id
export APOLLO_CLIENT_SECRET=your-client-secret
```

### Verify Authentication

```bash
# Check with config auth
rover config whoami

# Check with OAuth auth
rover auth whoami
```

## Configuration Profiles

Use profiles for different environments or accounts. Each profile stores its own API key and settings.

### Create Profile

```bash
rover config auth --profile staging
# or
rover auth login --profile staging
```

### Use Profile

```bash
rover subgraph fetch my-graph@staging --name products --profile staging
```

### List Profiles

```bash
rover config list
```

### Delete Profile

```bash
rover config delete staging
```

### Clear All Profiles

```bash
rover config clear
```

## Profile Settings

Store and manage settings on configuration profiles.

### Set a Setting

```bash
rover config set APOLLO_REGISTRY_URL https://custom.registry.example.com --profile staging
```

### Show All Settings

```bash
# Show effective values and sources for all settings
rover config show
rover config show --profile staging
```

### Unset a Setting

```bash
rover config unset APOLLO_REGISTRY_URL --profile staging
```

## Environment Variables

### Core Variables

| Variable | Description |
|----------|-------------|
| `APOLLO_KEY` | API key for GraphOS |
| `APOLLO_GRAPH_REF` | Default graph reference (`graph@variant`) |
| `APOLLO_CLIENT_ID` | OAuth client ID for client-credentials auth |
| `APOLLO_CLIENT_SECRET` | OAuth client secret for client-credentials auth |

### VCS Variables

| Variable | Description |
|----------|-------------|
| `APOLLO_VCS_REMOTE_URL` | Override the Git remote URL reported on check/publish |
| `APOLLO_VCS_BRANCH` | Override the Git branch reported on check/publish |
| `APOLLO_VCS_COMMIT` | Override the Git commit reported on check/publish |
| `APOLLO_VCS_AUTHOR` | Override the Git commit author reported on check/publish |

### Configuration Variables

| Variable | Description |
|----------|-------------|
| `APOLLO_HOME` | Override the location Rover installs its binary and plugins to |
| `APOLLO_CONFIG_HOME` | Override the location of Rover's config directory |
| `APOLLO_TELEMETRY_DISABLED` | Set to disable anonymous telemetry |
| `APOLLO_LOG_LEVEL` | Set log level (`error`, `warn`, `info`, `debug`, `trace`) |
| `APOLLO_FORMAT` | Set output format (`plain` or `json`) |
| `APOLLO_CHECKS_TIMEOUT_SECONDS` | Override how long check/launch polling waits |
| `APOLLO_CLIENT_TIMEOUT` | Configure HTTP request timeout in seconds (default: 30s) |
| `APOLLO_ROVER_DOWNLOAD_HOST` | Override the host for plugin binary downloads |
| `APOLLO_ROVER_SKIP_UPDATE` | Skip all auto-updating (self-update check and plugin downloads) |
| `NO_COLOR` | Disable colored output |

### CI/CD Environment

```yaml
# GitHub Actions
env:
  APOLLO_KEY: ${{ secrets.APOLLO_KEY }}
  APOLLO_GRAPH_REF: my-graph@production

steps:
  - run: rover subgraph check $APOLLO_GRAPH_REF --name products --schema ./schema.graphql
```

## Output Formats

```bash
# JSON output for scripting (envelope: {"json_version", "data", "error"})
rover subgraph fetch my-graph@production --name products --format json

# Write output to file
rover graph fetch my-graph@production --output schema.graphql

# Extract SDL from JSON with jq
rover subgraph fetch my-graph@production --name products --format json | jq -r '.data.sdl'
```

Match on `error.code` for scripting (codes are stable; messages may change).

## Logging, Proxy, and TLS

```bash
# Set log level (error, warn, info, debug, trace)
rover --log debug subgraph fetch my-graph@production --name products

# HTTP/SOCKS5 proxy
export HTTPS_PROXY=socks5://127.0.0.1:1086

# Accept invalid certs or hostnames (not recommended)
rover --insecure-accept-invalid-certs subgraph fetch my-graph@prod --name products
```

## Troubleshooting

```bash
# Re-authenticate
rover auth logout && rover auth login

# Explain error codes
rover explain E001

# Debug with verbose logging
rover --log debug config whoami

# Increase timeout for slow connections
rover --client-timeout 60 subgraph check my-graph@prod --name products --schema ./schema.graphql

# Open docs
rover docs open configuring
```
