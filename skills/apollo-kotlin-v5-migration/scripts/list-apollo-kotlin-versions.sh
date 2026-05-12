#!/usr/bin/env bash
# Usage: ./list-apollo-kotlin-versions.sh
# Lists all release tags of apollographql/apollo-kotlin (newest last).
# Requires SSH access to github.com; falls back to HTTPS if SSH fails.
set -euo pipefail

if ! git ls-remote --tags git@github.com:apollographql/apollo-kotlin.git 2>/dev/null | cut -d / -f 3; then
  git ls-remote --tags https://github.com/apollographql/apollo-kotlin.git | cut -d / -f 3
fi
