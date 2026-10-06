#!/usr/bin/env bash
# compose.sh — `rover supergraph compose` against the rendered schema.
#
#   compose.sh [workspace-dir]
#
# Layer 1 of the validation stack. It proves the schema is a valid Federation
# subgraph and that every @connect directive parses against the linked connect
# spec. It proves nothing about what the API returns — that is what the unit,
# e2e and conformance layers are for (references/testing.md).
#
# Exit 127 means "rover is not installed": the layer is `skipped` with that
# reason in evidence/latest.json, never `pass`. Exit 3 means the user has not
# accepted the composition plugin's Elastic License v2 (APOLLO_ELV2_LICENSE,
# see elv2.sh): the layer is `not_run` with that reason, never `pass`.
set -euo pipefail

WORKSPACE="${1:-.}"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# The product binary, and a refusal (exit 78) when it is older than
# the version these scripts pin — see resolve-bin.sh for the order and why.
# shellcheck source=SCRIPTDIR/resolve-bin.sh
. "$(dirname "$0")/resolve-bin.sh"

if ! command -v rover >/dev/null 2>&1; then
  echo "compose: rover is not installed — https://www.apollographql.com/docs/rover/getting-started" >&2
  exit 127
fi

# shellcheck source=SCRIPTDIR/elv2.sh
. "$(dirname "$0")/elv2.sh"
elv2_require compose

# `render` substitutes template.yaml test_defaults into a temporary copy and
# refuses a supergraph.yaml whose federation pin disagrees with workspace.yaml.
eval "$("$RC" render "$WORKSPACE" --out "$OUT")"

echo "compose: $(rover --version | head -1), federation $FEDERATION_VERSION, connect $CONNECT_SPEC"

# The composition plugin is ELv2-gated; rover reads the user's own
# APOLLO_ELV2_LICENSE=accept (checked above), so no prompt and no flag.
if NO_COLOR=1 rover supergraph compose --config "$COMPOSE_CONFIG" > "$OUT/supergraph.graphql"; then
  echo "compose: pass — $(wc -l < "$OUT/supergraph.graphql") lines of supergraph SDL"
else
  status=$?
  echo "compose: FAIL (rover exit $status)" >&2
  exit "$status"
fi
