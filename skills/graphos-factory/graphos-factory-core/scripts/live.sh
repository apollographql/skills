#!/usr/bin/env bash
# live.sh — tests/live.yaml through a real router against the real API.
#
#   live.sh [workspace-dir]
#
# Layer 6. The only layer that proves the connector works against the API as
# it exists today, and the only one that catches a silent null: a mapped
# field the payload does not carry yields null with no error anywhere else.
#
# tests/live.yaml:
#   cases:
#     - name: draw_two            # tests/live/draw_two.graphql
#       safety: read              # read | write-safe (documentation)
#       require: >                # optional jq expression over the full
#         .data.x_draw.cards      # response; must evaluate to boolean true
#         | length == 2
#     - name: project             # a case may take GraphQL variables from an
#       variables:                # EARLIER case's response: `from` names the
#         projectId:              # case, `path` is a jq path into its response.
#           from: list_projects   # A path that yields null, or a case that has
#           path: .data.x_listProjects.results[0].id   # not run or failed,
#                                 # fails this case (never a silent skip).
#   exclusions:                   # what this layer cannot exercise, and why
#     - operation: "get:/users/me"  # a selected operation
#       reason: "accepts only a user-scoped token; the CI key is account-level"
#     - field: "X_Payment.card"     # a relationship field, <Type>.<field>
#       reason: "its only parent is a write; no write is sent live"
#
# Each entry names exactly one of `operation` or `field`. An operation
# exclusion is printed as `EXCLUDED: <operation> — <reason>` and lands in
# evidence as that operation's live status `excluded` with the reason, so an
# operation nobody could test live is visible, not an anonymous `n/a`. A
# field exclusion is printed as `EXCLUDED FIELD: <Type>.<field> — <reason>`
# and lands in the live layer's findings: a relationship field has no
# operations row, and an excluded one is never reported as passed.
#
# Baseline per case: no `errors`, non-empty `data`. `require:` is for the
# nullable fields the baseline cannot see (references/testing.md).
#
# Credentials come from the environment, or from a gitignored smoke.env found
# from the workspace up to its checkout's top (or $GRAPHOS_FACTORY_CORE_LIVE_ENV);
# the environment wins. See live-env.sh.
#
# Exit codes: 0 pass · 1 fail · 3 not_run (credential unset, no
# tests/live.yaml, or APOLLO_ELV2_LICENSE not `accept`, see elv2.sh) · 127
# tool missing. 3 is a first-class result: evidence
# records it as `not_run` with the reason, never as a pass.
set -euo pipefail

WORKSPACE="${1:-.}"
ROUTER_VERSION="${ROUTER_VERSION:-2.17.0}"
ROUTER_PORT="${ROUTER_PORT:-4000}"
ROUTER_HEALTH_PORT="${ROUTER_HEALTH_PORT:-8088}"

for tool in curl jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "live: $tool is not installed" >&2; exit 127; }
done
command -v rover >/dev/null 2>&1 || { echo "live: rover is not installed" >&2; exit 127; }

# shellcheck source=SCRIPTDIR/cache.sh
. "$(dirname "$0")/cache.sh"
CACHE="$GRAPHOS_FACTORY_CORE_CACHE_DIR"
# The product binary, and a refusal (exit 78) when it is older than
# the version these scripts pin — see resolve-bin.sh for the order and why.
# shellcheck source=SCRIPTDIR/resolve-bin.sh
. "$(dirname "$0")/resolve-bin.sh"


LIVE="$WORKSPACE/tests/live.yaml"
if [ ! -f "$LIVE" ]; then
  echo "live: no tests/live.yaml — nothing to run (not_run)"
  exit 3
fi

OUT="$(mktemp -d)"
ROUTER_PID=""
cleanup() { if [ -n "$ROUTER_PID" ]; then kill "$ROUTER_PID" 2>/dev/null || true; fi; rm -rf "$OUT"; }
trap cleanup EXIT

# The live layer's credentials file (smoke.env, or $GRAPHOS_FACTORY_CORE_LIVE_ENV),
# loaded into this process only — see live-env.sh for why no other layer does.
# shellcheck source=SCRIPTDIR/live-env.sh
. "$(dirname "$0")/live-env.sh"
live_env_load "$WORKSPACE" || exit 1

# Credential: the env var named by AUTH_EXPR's test_default must be set with a
# REAL value here. Unset means not_run, never a run with `test-token`.
AUTH_VAR="$("$RC" auth-env "$WORKSPACE")"
if [ -n "$AUTH_VAR" ] && [ -z "${!AUTH_VAR:-}" ]; then
  echo "live: $AUTH_VAR is not set — skipping live smoke (not_run)"
  exit 3
fi

# shellcheck source=SCRIPTDIR/elv2.sh
. "$(dirname "$0")/elv2.sh"
elv2_require live

for port in "$ROUTER_PORT" "$ROUTER_HEALTH_PORT"; do
  if curl -s "http://localhost:$port/" >/dev/null 2>&1; then echo "live: port $port is busy" >&2; exit 1; fi
done

ROUTER_BIN="$CACHE/router-$ROUTER_VERSION"
if [ ! -x "$ROUTER_BIN" ]; then
  echo "live: Apollo Router $ROUTER_VERSION is not cached at $ROUTER_BIN — run e2e.sh once, or the SessionStart hook" >&2
  exit 127
fi

eval "$("$RC" render "$WORKSPACE" --out "$OUT")"
NO_COLOR=1 rover supergraph compose --config "$COMPOSE_CONFIG" > "$OUT/supergraph.graphql" 2> "$OUT/compose.err" \
  || { cat "$OUT/compose.err" >&2; echo "live: compose failed" >&2; exit 1; }

# No override_url: connectors hit the real upstream. Subgraph errors stay
# visible so a mapped error is asserted, not redacted.
cat > "$OUT/router.yaml" <<EOF
supergraph:
  listen: 127.0.0.1:${ROUTER_PORT}
  introspection: false
health_check:
  listen: 127.0.0.1:${ROUTER_HEALTH_PORT}
include_subgraph_errors:
  all: true
EOF
env -u OTEL_EXPORTER_OTLP_ENDPOINT "$ROUTER_BIN" --supergraph "$OUT/supergraph.graphql" --config "$OUT/router.yaml" > "$OUT/router.log" 2>&1 &
ROUTER_PID=$!
# The same wait as e2e.sh: E2E_ROUTER_START_SECONDS raises it for a large
# supergraph (Databricks: 152.6s to healthy), the default stays 30.
router_wait=${E2E_ROUTER_START_SECONDS:-30}
deadline=$(( $(date +%s) + router_wait ))
until curl -sf "http://localhost:${ROUTER_HEALTH_PORT}/health" >/dev/null 2>&1; do
  kill -0 "$ROUTER_PID" 2>/dev/null || { echo "live: router exited before it reported healthy"; tail -30 "$OUT/router.log" >&2; exit 1; }
  [ "$(date +%s)" -ge "$deadline" ] && { echo "live: router did not start within ${router_wait}s (set E2E_ROUTER_START_SECONDS to wait longer)"; tail -30 "$OUT/router.log" >&2; exit 1; }
  sleep 1
done

# Cases, as JSON so bash never parses YAML.
"$RC" yaml2json "$LIVE" | jq -c '.cases // []' > "$OUT/cases.json"
count="$(jq 'length' "$OUT/cases.json")"
echo "live: Apollo Router $ROUTER_VERSION against the real API, $count case(s)"

PASS=0; FAIL=0
for ((i = 0; i < count; i++)); do
  name="$(jq -r ".[$i].name" "$OUT/cases.json")"
  safety="$(jq -r ".[$i].safety // \"read\"" "$OUT/cases.json")"
  require="$(jq -r ".[$i].require // \"\"" "$OUT/cases.json")"
  query_file="$WORKSPACE/tests/live/$name.graphql"
  if [ ! -f "$query_file" ]; then echo "FAIL: $name — missing $query_file"; FAIL=$((FAIL+1)); continue; fi

  # Chained variables: each value comes from an earlier case's saved response.
  vars='{}'; chain_error=""
  while IFS=$'\t' read -r vname vfrom vpath; do
    [ -n "$vname" ] || continue
    src="$OUT/responses/$vfrom.json"
    if [ ! -f "$src" ]; then chain_error="variable \$$vname needs case '$vfrom', which has not passed before this one"; break; fi
    if ! value="$(jq -c "$vpath" "$src" 2>/dev/null)"; then chain_error="variable \$$vname: jq path '$vpath' is invalid"; break; fi
    if [ -z "$value" ] || [ "$value" = "null" ]; then chain_error="variable \$$vname resolved to null from $vfrom ($vpath)"; break; fi
    vars="$(jq -c --arg k "$vname" --argjson v "$value" '. + {($k): $v}' <<<"$vars")"
  done < <(jq -r ".[$i].variables // {} | to_entries[] | [.key, .value.from, .value.path] | @tsv" "$OUT/cases.json")
  if [ -n "$chain_error" ]; then echo "FAIL: $name ($safety) — $chain_error"; FAIL=$((FAIL+1)); continue; fi

  response="$(jq -n --rawfile q "$query_file" --argjson v "$vars" '{query: $q, variables: $v}' \
    | curl -sf -X POST -H 'content-type: application/json' -d @- "http://localhost:${ROUTER_PORT}/" \
    || echo '{"errors":[{"message":"curl error"}]}')"
  errors="$(echo "$response" | jq -r '.errors // empty | length' 2>/dev/null || echo parse)"
  has_data="$(echo "$response" | jq -r '(.data // empty) | if . == null or . == {} then "no" else "yes" end' 2>/dev/null || echo no)"
  if [ -n "$errors" ] && [ "$errors" != "0" ]; then
    echo "FAIL: $name ($safety) — $errors error(s):"; echo "$response" | jq -c '.errors' | head -3 | sed 's/^/      /'
    FAIL=$((FAIL+1)); continue
  fi
  if [ "$has_data" != "yes" ]; then echo "FAIL: $name ($safety) — empty data"; FAIL=$((FAIL+1)); continue; fi
  if [ -n "$require" ] && [ "$require" != "null" ]; then
    # Type-strict: the expression must yield exactly one boolean true.
    verdict="$(echo "$response" | jq -r "[ ( ${require}
) ] | if length == 1 and .[0] == true then \"true\" else \"false\" end" 2>/dev/null || echo jq-error)"
    if [ "$verdict" != "true" ]; then
      echo "FAIL: $name ($safety) — require did not evaluate to true ($verdict): $require"
      echo "$response" | jq -c '.data' | cut -c1-400 | sed 's/^/      /'
      FAIL=$((FAIL+1)); continue
    fi
  fi
  mkdir -p "$OUT/responses"; printf '%s' "$response" > "$OUT/responses/$name.json"
  echo "PASS: $name ($safety)"; PASS=$((PASS+1))
done
# Exclusions: named, reasoned, reported.
"$RC" yaml2json "$LIVE" | jq -c '.exclusions // []' > "$OUT/exclusions.json"
excluded="$(jq 'length' "$OUT/exclusions.json")"
EXCL=0
for ((i = 0; i < excluded; i++)); do
  op="$(jq -r ".[$i].operation // \"\"" "$OUT/exclusions.json")"
  field="$(jq -r ".[$i].field // \"\"" "$OUT/exclusions.json")"
  reason="$(jq -r ".[$i].reason // \"\"" "$OUT/exclusions.json")"
  if [ -z "$op" ] && [ -z "$field" ]; then echo "FAIL: exclusion $i names no operation or field"; FAIL=$((FAIL+1)); continue; fi
  if [ -n "$op" ] && [ -n "$field" ]; then echo "FAIL: exclusion $i names both an operation ($op) and a field ($field); give each its own entry"; FAIL=$((FAIL+1)); continue; fi
  if [ -z "$reason" ]; then echo "FAIL: exclusion for ${op:-$field} gives no reason"; FAIL=$((FAIL+1)); continue; fi
  # A field's line has its own prefix, so evidence cannot read it as an
  # operation row (a relationship field has none).
  if [ -n "$field" ]; then echo "EXCLUDED FIELD: $field — $reason"; else echo "EXCLUDED: $op — $reason"; fi
  EXCL=$((EXCL+1))
done
echo "live: $PASS passed, $FAIL failed, $EXCL excluded"
[ "$FAIL" -eq 0 ]
