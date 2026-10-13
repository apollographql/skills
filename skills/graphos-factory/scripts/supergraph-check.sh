#!/usr/bin/env bash
# supergraph-check.sh — check the subgraph against the user's published
# supergraph with `rover subgraph check`.
#
#   supergraph-check.sh [workspace-dir]
#
# The graphos target's evidence layer, supergraph_check. `evidence` runs it
# after the core layers; by hand it does the same and prints the same lines.
# The compose layer composes the subgraph alone. This one sends the rendered
# schema to GraphOS, which composes it with the variant's other subgraphs
# and runs the variant's configured checks (operations against recorded
# traffic, and lint, custom, proposal or downstream checks when the graph has
# them). Nothing is published: a check changes no variant.
#
# Inputs, from the environment only (never from a file in the workspace):
#   GRAPHOS_FACTORY_GRAPH_REF  <graph>@<variant>, the graph to check
#                     against on this run (mode explicit). The agent sets it
#                     for the commands it runs once the user has named the
#                     graph. It wins over the automatic mode.
#   GRAPHOS_FACTORY_SUPERGRAPH_CHECK=auto, with APOLLO_GRAPH_REF set
#                     check against $APOLLO_GRAPH_REF on every run without
#                     being asked (mode auto): the user's own switch, set in
#                     their shell profile. Any other value is refused,
#                     not_run. APOLLO_GRAPH_REF alone is never enough: shell
#                     profiles export it for other tools, and a check sends
#                     the rendered schema to GraphOS, which keeps it.
#   APOLLO_KEY        the user's GraphOS API key, from their environment.
#                     rover reads it itself; this script tests only that it
#                     is set, never prints it, and redacts it from every
#                     line it prints. A key stored only in a rover profile
#                     does not count.
# A graph ref of any shape but <graph>@<variant> (a value starting with `-`
# would read as a rover flag) is refused, not_run.
# The subgraph name is workspace.yaml's `directory`. The schema is a rendered
# copy in a temporary directory: the base URL from <SERVICE>_BASE_URL when
# set, else template.yaml's test default (composition does not read the
# host, so either checks the same thing), and AUTH_EXPR always from
# template.yaml's test default, a {$env.NAME} expression, so no value a
# <SERVICE>_AUTH_EXPR override holds ever reaches GraphOS. A base URL that
# carries userinfo, or a query parameter named like a credential (token,
# key, secret, password, auth, signature, credential), is not sent.
#
# Output: one `supergraph_check: rover X, subgraph S, graph G` line, then
# `SUPERGRAPH_CHECK_JSON=<path>`, rover's full `--format json` output with
# the key's value removed (at $SUPERGRAPH_CHECK_JSON when set, which
# `evidence` sets and reads, else a temporary file left for you to read;
# rover's raw output stays in this script's own mode-0700 temporary
# directory, removed on exit), then a summary: on a failure the
# build errors, failing checks and failing changes, at most 20 lines, and
# the Studio URL rover reports.
#
# Exit codes: 0 pass (composition and every check rover ran passed) · 1 fail
# (build errors, or a check that failed) · 2 usage · 3 not_run (no graph
# ref by either mode, a graph ref that is not <graph>@<variant>, an unknown
# GRAPHOS_FACTORY_SUPERGRAPH_CHECK value, APOLLO_KEY unset, a base URL with
# a credential in it, or rover could not
# run the check: no such graph, a refused key, no network) · 127 rover, jq
# or the binary missing. 3 is a first-class result: evidence records it as
# `not_run` with the reason, never as a pass.
#
# The Elastic License v2 gate the core wrappers apply does not apply here:
# `rover subgraph check` downloads and runs neither the composition plugin
# nor the Apollo Router (it has no --elv2-license flag); composition runs in
# GraphOS. Bash 3.2 compatible (macOS /bin/bash).
set -euo pipefail

case "${1:-}" in
  -h|--help) sed -n '2,/^set -euo/p' "$0" | sed -e '$d' -e 's/^# \{0,1\}//'; exit 0 ;;
  -*) echo "supergraph_check: unknown flag $1; usage: supergraph-check.sh [workspace-dir]" >&2; exit 2 ;;
esac
if [ $# -gt 1 ]; then
  echo "supergraph_check: usage: supergraph-check.sh [workspace-dir]" >&2
  exit 2
fi
WORKSPACE="${1:-.}"

# Every line this script prints, with the key (should anything echo it)
# replaced.
say() {
  local line="$*"
  if [ -n "${APOLLO_KEY:-}" ]; then line="${line//"$APOLLO_KEY"/<redacted>}"; fi
  printf '%s\n' "$line"
}

# The graph to check against, and the mode that chose it: an explicit
# GRAPHOS_FACTORY_GRAPH_REF first, else APOLLO_GRAPH_REF when the user
# switched automatic checks on. Nothing else reads either variable.
case "${GRAPHOS_FACTORY_SUPERGRAPH_CHECK:-}" in
  ""|auto) ;;
  *)
    echo "supergraph_check: GRAPHOS_FACTORY_SUPERGRAPH_CHECK is set to something other than auto, its only value — not checked against your supergraph (not_run)"
    echo "supergraph_check:   unset it, or set it to auto to check against \$APOLLO_GRAPH_REF on every run"
    exit 3
    ;;
esac
GRAPH_REF="" MODE="" FROM=""
if [ -n "${GRAPHOS_FACTORY_GRAPH_REF:-}" ]; then
  GRAPH_REF="$GRAPHOS_FACTORY_GRAPH_REF" MODE=explicit FROM=GRAPHOS_FACTORY_GRAPH_REF
elif [ "${GRAPHOS_FACTORY_SUPERGRAPH_CHECK:-}" = auto ] && [ -n "${APOLLO_GRAPH_REF:-}" ]; then
  GRAPH_REF="$APOLLO_GRAPH_REF" MODE=auto FROM=APOLLO_GRAPH_REF
fi
if [ -z "$GRAPH_REF" ]; then
  echo "supergraph_check: no graph to check against — set GRAPHOS_FACTORY_GRAPH_REF=<graph>@<variant> for this run (the agent asks you first), or GRAPHOS_FACTORY_SUPERGRAPH_CHECK=auto to check against \$APOLLO_GRAPH_REF on every run (not_run)"
  echo "supergraph_check:   a check sends the rendered schema to GraphOS and publishes nothing; APOLLO_GRAPH_REF alone does not start one"
  exit 3
fi
# <graph>@<variant>, never a leading `-`, which rover would read as a flag.
if ! [[ "$GRAPH_REF" =~ ^[A-Za-z0-9][A-Za-z0-9_-]*@[A-Za-z0-9_.-]+$ ]]; then
  say "supergraph_check: $FROM is not <graph>@<variant> (a letter or digit first, then letters, digits, _ and - in the graph id; also . in the variant) — not checked against your supergraph (not_run)"
  exit 3
fi
if [ -z "${APOLLO_KEY:-}" ]; then
  echo "supergraph_check: APOLLO_KEY is not set — not checked against your supergraph (not_run)"
  echo "supergraph_check:   export your GraphOS API key as APOLLO_KEY in the environment the agent's commands inherit (your shell profile, or the shell you start it from)"
  echo "supergraph_check:   the key is yours: it stays in your environment, is never written to the workspace and is never printed"
  exit 3
fi

command -v rover >/dev/null 2>&1 || { echo "supergraph_check: rover is not installed" >&2; exit 127; }
command -v jq >/dev/null 2>&1 || { echo "supergraph_check: jq is not installed" >&2; exit 127; }

# The core's scripts: $GRAPHOS_FACTORY_CORE_SCRIPTS first (what `evidence`
# hands this script: the core the rest of the run used), else the copy
# inside this skill (an installed skill carries one), else the one at the
# root of the checkout that holds skills/.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE=""
for c in "${GRAPHOS_FACTORY_CORE_SCRIPTS:-}" "$HERE/../graphos-factory-core/scripts" "$HERE/../../../graphos-factory-core/scripts"; do
  if [ -n "$c" ] && [ -f "$c/resolve-bin.sh" ]; then CORE="$(cd "$c" && pwd)"; break; fi
done
if [ -z "$CORE" ]; then
  echo "supergraph_check: GRAPHOS_FACTORY_CORE_SCRIPTS names no core scripts, and there are none beside $HERE or at the checkout root: the core scripts are not installed" >&2
  exit 127
fi
# The product binary, refused (exit 78) when older than the pin.
# shellcheck source=SCRIPTDIR/../../../graphos-factory-core/scripts/resolve-bin.sh
. "$CORE/resolve-bin.sh"

if [ ! -f "$WORKSPACE/.factory/workspace.yaml" ]; then
  echo "supergraph_check: $WORKSPACE holds no .factory/workspace.yaml" >&2
  exit 2
fi

OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# The render, with no <SERVICE>_AUTH_EXPR override in its environment.
unset_auth=()
while IFS= read -r name; do
  case "$name" in *_AUTH_EXPR) unset_auth+=(-u "$name") ;; esac
done < <(env | sed -n 's/^\([A-Za-z_][A-Za-z0-9_]*\)=.*/\1/p')
if ! rendered="$(env ${unset_auth[@]+"${unset_auth[@]}"} "$RC" render "$WORKSPACE" --out "$OUT" 2> "$OUT/render.err")"; then
  say "supergraph_check: FAIL — the schema did not render: $(head -1 "$OUT/render.err")"
  exit 1
fi
eval "$rendered"
if grep -Eq 'baseURL:[[:space:]]*"[A-Za-z][A-Za-z0-9+.-]*://[^/"]*@' "$RENDERED_SCHEMA"; then
  echo "supergraph_check: the base URL carries userinfo, so the schema was not sent to GraphOS — not checked against your supergraph (not_run)"
  echo "supergraph_check:   GraphOS keeps the schemas it checks; send the credential through AUTH_EXPR, not the URL"
  exit 3
fi
if grep -Eiq 'baseURL:[[:space:]]*"[^"]*[?&][^"=&]*(token|key|secret|passw|auth|sig|credential)[^"=&]*=' "$RENDERED_SCHEMA"; then
  echo "supergraph_check: the base URL carries a query parameter named like a credential, so the schema was not sent to GraphOS — not checked against your supergraph (not_run)"
  echo "supergraph_check:   GraphOS keeps the schemas it checks; send the credential through AUTH_EXPR, not the URL"
  exit 3
fi

ROVER_VERSION="$(rover --version 2>/dev/null | sed -n 's/^Rover \([0-9][^ ]*\).*/\1/p' | head -1)"
say "supergraph_check: rover ${ROVER_VERSION:-unknown}, subgraph $DIRECTORY, graph $GRAPH_REF, mode $MODE"

JSON="${SUPERGRAPH_CHECK_JSON:-}"
if [ -z "$JSON" ]; then JSON="$(mktemp "${TMPDIR:-/tmp}/supergraph-check.XXXXXX")"; fi
rc=0
# rover reads APOLLO_KEY from its environment; no command line carries it.
NO_COLOR=1 rover subgraph check "$GRAPH_REF" --name "$DIRECTORY" --schema "$RENDERED_SCHEMA" --format json \
  > "$OUT/raw.json" 2> "$OUT/rover.err" || rc=$?
# Only the redacted JSON leaves $OUT: jq reads the key from its environment
# (env.APOLLO_KEY), never from its command line, so `ps` never shows it.
# Output that is not JSON is never copied out.
: > "$JSON"
jq 'if (env.APOLLO_KEY // "") == "" then . else walk(if type == "string" then (split(env.APOLLO_KEY) | join("<redacted>")) else . end) end' \
  "$OUT/raw.json" > "$JSON" 2>/dev/null || : > "$JSON"
echo "SUPERGRAPH_CHECK_JSON=$JSON"

if ! jq -e 'type == "object"' "$JSON" >/dev/null 2>&1; then
  say "supergraph_check: rover subgraph check printed no JSON (exit $rc) — not checked against your supergraph (not_run)"
  head -5 "$OUT/rover.err" | while IFS= read -r l; do say "supergraph_check:   $l"; done
  exit 3
fi

url="$(jq -r '[.data.tasks // {} | .[] | .target_url? // empty] | first // empty' "$JSON")"
build_errors="$(jq '.error.details.build_errors // [] | length' "$JSON")"
code="$(jq -r '.error.code // empty' "$JSON")"

if [ "$build_errors" -gt 0 ] || [ "$code" = E029 ]; then
  say "supergraph_check: FAIL — composition with $GRAPH_REF: $build_errors build error(s)"
  jq -r '.error.details.build_errors // [] | .[] | "  build error [\(.code // "no code")]: \(.message // "")"' "$JSON" \
    | head -20 | while IFS= read -r l; do say "$l"; done
  [ "$build_errors" -gt 0 ] || say "  $(jq -r '.error.message // ""' "$JSON")"
  exit 1
fi

if jq -e '.data.tasks | type == "object"' "$JSON" >/dev/null 2>&1; then
  ops="$(jq -r '.data.tasks.operations // empty | "operations \(.task_status): \(.operation_check_count // 0) checked, \(.failure_count // 0) failing change(s)"' "$JSON")"
  if [ "$rc" -eq 0 ] && [ "$(jq -r '.data.success' "$JSON")" = true ] && [ -z "$code" ]; then
    say "supergraph_check: pass — composes with $GRAPH_REF${ops:+; $ops}"
    [ -z "$url" ] || say "supergraph_check: details: $url"
    exit 0
  fi
  failed="$(jq -r '[.data.tasks | to_entries[] | select(.value.task_status != "PASSED") | "\(.key) \(.value.task_status)"] | join(", ")' "$JSON")"
  say "supergraph_check: FAIL — composes with $GRAPH_REF, but checks did not pass: ${failed:-$(jq -r '.error.message // "rover reported a failure"' "$JSON")}"
  {
    jq -r '.data.tasks.operations.changes // [] | .[] | select(.severity == "FAIL") | "  operations [\(.code)]: \(.description)"' "$JSON"
    jq -r '.data.tasks.lint.diagnostics // [] | .[] | select(.level == "ERROR") | "  lint [\(.rule)] \(.coordinate // ""): \(.message)"' "$JSON"
    jq -r '.data.tasks.custom.violations // [] | .[] | select(.level == "ERROR") | "  custom [\(.rule)]: \(.message)"' "$JSON"
  } | head -20 | while IFS= read -r l; do say "$l"; done
  [ -z "$url" ] || say "supergraph_check: details: $url"
  exit 1
fi

# An error with no check behind it: the graph ref, the key or the network.
say "supergraph_check: rover subgraph check did not run the check: $(jq -r '.error.message // "no result"' "$JSON")${code:+ ($code)} — not checked against your supergraph (not_run)"
exit 3
