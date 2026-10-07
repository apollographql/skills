#!/usr/bin/env bash
# e2e.sh — WireMock-backed cases through a real Apollo Router.
#
#   e2e.sh [workspace-dir] [--generate] [--only PATTERN]
#
# Layer 3, and the only layer where a real router parses the real GraphQL
# documents and sends real HTTP requests. WireMock runs from its standalone
# JAR (Java), and unmatched upstream requests are printed WITH their
# bodies, because "what did the connector actually send?" is the question
# this layer is for.
#
# All-stubs-at-once loading (references/testing.md): every classified mapping
# loads into WireMock once, before the first case runs, and stays loaded for
# the whole suite — every stub is mounted flat, unlike this script's own
# former per-case reset-and-reload. Two stubs whose
# `request` matcher is identical can then only ever be answered by one of
# them, WireMock's own tie-break deciding which; that is a fixture defect
# any flat-mounting runner downstream would also hit, so it must fail here
# first.
# Only the request journal and WireMock's scenario state reset between
# cases (`DELETE $ADMIN/requests`, `POST $ADMIN/scenarios/reset`; neither
# touches loaded mappings), so per-case stub-hit accounting is unaffected
# by every other case's stubs also being loaded. A case whose own stub
# declares a `requiredScenarioState` other than `Started` (references/
# testing.md — a WireMock Scenario, the only way to disambiguate a request
# that is identical by definition, e.g. an operation with no body) has that
# state set directly before its request fires. Every mapping must still be
# classifiable — by `metadata."x-cases"`, by a basename matching a case
# name (hyphens and underscores interchangeable), or by `metadata."x-shared"`
# — or the run fails before any case executes.
# Stub-hit accounting after each case: every upstream request matched a
# loaded stub and at least one was made, unless the .graphql declares
# `# expect-unmatched-upstream`. Every stub that answered must also be the
# case's own (its case list or shared.list): with every stub loaded at once,
# another case's stub can answer a request the connector got wrong (a
# dropped query parameter matching a sibling's `absent` matcher), and that
# must fail the case, as per-case loading did. The request
# journal names the stub that answered each request (`stubMapping.name`,
# the fixture's filename, set at load). A stub of the case's own marked
# `metadata."x-required": true` must also have answered at least one request,
# or the case fails naming it: a $batch case's lookup, which a
# planner that resolves the fields locally never calls.
#
# Upstream status, before the snapshot diff: a case declaring
# `# expect-upstream-status: CODE` fails unless one of its own stubs
# answered CODE. A router that redacts subgraph errors renders every error
# status alike, so the snapshot alone cannot tell a 401 case from a 404 one.
# A case without the directive whose stub answered a non-2xx status, calling
# a root field whose operation documents more than one, reports UNPROVEN:
# counted apart, never as a pass, and not a failure of the run.
#
# --only PATTERN restricts which cases actually run (each is the 3-file unit
# of tests/cases/NAME.graphql, its .expected.json, and its
# mapping) to those whose NAME contains PATTERN as a literal substring,
# hyphens and underscores interchangeable — same normalisation the mapping
# classifier below already uses. Classification still runs over every
# mapping regardless of --only, so a filtered run cannot mask an
# unclassifiable fixture. A PATTERN matching no case fails closed (exit 1)
# before WireMock or the router starts.
#
# Exit 127 = a tool is missing (java, curl, jq): the layer is `skipped` in
# evidence with that reason, never `pass`. Exit 3 = the user has not accepted
# the Elastic License v2 of the composition plugin and the Router
# (APOLLO_ELV2_LICENSE, see elv2.sh): the layer is `not_run` with that
# reason, never `pass`, and no Router is downloaded.
set -euo pipefail

WORKSPACE="."
GENERATE=0
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --generate) GENERATE=1; shift ;;
    --only)
      if [ $# -lt 2 ] || [ -z "$2" ]; then echo "e2e: --only requires a non-empty pattern" >&2; exit 1; fi
      ONLY="$2"; shift 2 ;;
    *) WORKSPACE="$1"; shift ;;
  esac
done
WIREMOCK_VERSION="${WIREMOCK_VERSION:-3.13.2}"
ROUTER_VERSION="${ROUTER_VERSION:-2.17.0}"
WIREMOCK_PORT="${WIREMOCK_PORT:-8080}"
ROUTER_PORT="${ROUTER_PORT:-4000}"
ROUTER_HEALTH_PORT="${ROUTER_HEALTH_PORT:-8088}"
ADMIN="http://localhost:${WIREMOCK_PORT}/__admin"

for tool in java curl jq; do
  command -v "$tool" >/dev/null 2>&1 || { echo "e2e: $tool is not installed" >&2; exit 127; }
done
command -v rover >/dev/null 2>&1 || { echo "e2e: rover is not installed" >&2; exit 127; }

# shellcheck source=SCRIPTDIR/cache.sh
. "$(dirname "$0")/cache.sh"
CACHE="$GRAPHOS_FACTORY_CORE_CACHE_DIR"
# The product binary, and a refusal (exit 78) when it is older than
# the version these scripts pin — see resolve-bin.sh for the order and why.
# shellcheck source=SCRIPTDIR/resolve-bin.sh
. "$(dirname "$0")/resolve-bin.sh"
# shellcheck source=SCRIPTDIR/elv2.sh
. "$(dirname "$0")/elv2.sh"
elv2_require e2e

OUT="$(mktemp -d)"
WIREMOCK_PID=""
ROUTER_PID=""
cleanup() {
  if [ -n "$ROUTER_PID" ]; then kill "$ROUTER_PID" 2>/dev/null || true; fi
  if [ -n "$WIREMOCK_PID" ]; then kill "$WIREMOCK_PID" 2>/dev/null || true; fi
  rm -rf "$OUT"
}
trap cleanup EXIT

CASES_DIR="$WORKSPACE/tests/cases"
MAPPINGS_DIR="$WORKSPACE/tests/fixtures/mappings"
[ -f "$WORKSPACE/tests/router.yaml" ] || { echo "e2e: $WORKSPACE/tests/router.yaml is missing" >&2; exit 1; }
shopt -s nullglob
case_files=("$CASES_DIR"/*.graphql)
mappings=("$MAPPINGS_DIR"/*.json)
shopt -u nullglob
# Byte order, never the shell's locale: a glob and `sort` collate
# by LC_COLLATE, and under en_US.UTF-8 `X_minimal.json` sorts before
# `X.json` while under C it sorts after. Stubs load in this order, and
# WireMock answers a request two stubs match with the one loaded last, so
# the locale once decided which stub answered. Only these sorts are pinned:
# exporting LC_ALL=C would reach WireMock's JVM, whose default charset
# before Java 18 follows it.
if [ ${#case_files[@]} -gt 0 ]; then
  sorted=(); while IFS= read -r f; do sorted+=("$f"); done < <(printf '%s\n' "${case_files[@]}" | LC_ALL=C sort)
  case_files=("${sorted[@]}")
fi
if [ ${#mappings[@]} -gt 0 ]; then
  sorted=(); while IFS= read -r f; do sorted+=("$f"); done < <(printf '%s\n' "${mappings[@]}" | LC_ALL=C sort)
  mappings=("${sorted[@]}")
fi
[ ${#case_files[@]} -gt 0 ] || { echo "e2e: no tests/cases/*.graphql" >&2; exit 1; }

run_cases=("${case_files[@]}")
if [[ -n "$ONLY" ]]; then
  run_cases=()
  norm_only="$(printf '%s' "$ONLY" | tr '-' '_')"
  for f in "${case_files[@]}"; do
    norm_b="$(printf '%s' "$(basename "${f%.graphql}")" | tr '-' '_')"
    [[ "$norm_b" == *"$norm_only"* ]] && run_cases+=("$f")
  done
  if [[ ${#run_cases[@]} -eq 0 ]]; then
    echo "e2e: --only '$ONLY' matched no case in $CASES_DIR" >&2
    exit 1
  fi
fi

for port in "$WIREMOCK_PORT" "$ROUTER_PORT" "$ROUTER_HEALTH_PORT"; do
  if curl -s "http://localhost:$port/" >/dev/null 2>&1; then
    echo "e2e: port $port is already in use" >&2
    exit 1
  fi
done

# ── Toolchain: fetch once into the cache ─────────────────────────────────────
mkdir -p "$CACHE"
WIREMOCK_JAR="$CACHE/wiremock-standalone-$WIREMOCK_VERSION.jar"
ROUTER_BIN="$CACHE/router-$ROUTER_VERSION"
if [ ! -f "$WIREMOCK_JAR" ]; then
  echo "e2e: downloading WireMock $WIREMOCK_VERSION"
  curl -sfL "https://repo1.maven.org/maven2/org/wiremock/wiremock-standalone/$WIREMOCK_VERSION/wiremock-standalone-$WIREMOCK_VERSION.jar" -o "$WIREMOCK_JAR"
fi
# The Router is ELv2-licensed too: this download sits after elv2_require.
if [ ! -x "$ROUTER_BIN" ]; then
  echo "e2e: downloading Apollo Router $ROUTER_VERSION"
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64) platform="x86_64-unknown-linux-gnu" ;;
    Linux-aarch64) platform="aarch64-unknown-linux-gnu" ;;
    Darwin-arm64) platform="aarch64-apple-darwin" ;;
    Darwin-x86_64) platform="x86_64-apple-darwin" ;;
    *) echo "e2e: unsupported platform $(uname -s)-$(uname -m)" >&2; exit 127 ;;
  esac
  curl -sfL "https://github.com/apollographql/router/releases/download/v$ROUTER_VERSION/router-v$ROUTER_VERSION-$platform.tar.gz" \
    | tar xzf - -C "$OUT" --strip-components=1 dist/router
  mv "$OUT/router" "$ROUTER_BIN"
  chmod +x "$ROUTER_BIN"
fi

# ── Classify every mapping before anything starts ────────────────────────────
INDEX="$OUT/index"
mkdir -p "$INDEX"
for q in "${case_files[@]}"; do
  b="$(basename "$q" .graphql)"
  printf '%s\t%s\n' "$(printf '%s' "$b" | tr '-' '_')" "$b"
done > "$INDEX/cases.tsv"
case_for_name() {
  awk -F'\t' -v n="$(printf '%s' "$1" | tr '-' '_')" '$1==n{print $2; exit}' "$INDEX/cases.tsv"
}
unclassified=""
for m in "${mappings[@]}"; do
  if jq -e '.persistent == true' "$m" >/dev/null 2>&1; then
    echo "e2e: $(basename "$m") sets \"persistent\": true — WireMock would restore it after every reset and it would answer other cases' requests. Remove it." >&2
    exit 1
  fi
  # A scenario's state is set through `PUT $ADMIN/scenarios/<name>/state`,
  # and WireMock 3.13.2 does not decode a percent-encoded name there
  # (measured: `%20`, `%23`, `%C3%A9` all 404). A name that needs encoding
  # could never be set, so refuse it before any case runs.
  scenario="$(jq -r '.scenarioName // empty' "$m")"
  # `.` and `..` alone are refused too: curl collapses them as path
  # dot-segments, so the PUT would never reach the scenario.
  if [[ -n "$scenario" && ( ! "$scenario" =~ ^[A-Za-z0-9._~-]+$ || "$scenario" == "." || "$scenario" == ".." ) ]]; then
    echo "e2e: $(basename "$m") scenarioName '$scenario' cannot be addressed in WireMock's scenario admin API (it does not decode URL-encoding, and '.' or '..' alone is a path dot-segment) — use only letters, digits, '.', '_', '~' and '-', and not '.' or '..' alone" >&2
    exit 1
  fi
  has_xcases="$(jq -r '(.metadata // {}) | has("x-cases")' "$m")"
  xcases="$(jq -r '(.metadata["x-cases"] // [])[]' "$m")"
  xshared="$(jq -r '.metadata["x-shared"] // false' "$m")"
  if [[ "$has_xcases" == "true" && -z "$xcases" ]]; then
    continue # recorded for an operation with no case yet: classified, loaded for nothing
  fi
  if [[ -n "$xcases" ]]; then
    while IFS= read -r c; do
      target="$(case_for_name "$c")"
      [[ -n "$target" ]] || { echo "e2e: $(basename "$m") metadata.x-cases names unknown case '$c'" >&2; exit 1; }
      echo "$m" >> "$INDEX/case-$target.list"
    done <<< "$xcases"
  elif [[ "$xshared" == "true" ]]; then
    echo "$m" >> "$INDEX/shared.list"
  else
    target="$(case_for_name "$(basename "$m" .json)")"
    if [[ -n "$target" ]]; then echo "$m" >> "$INDEX/case-$target.list"; else unclassified="$unclassified $(basename "$m")"; fi
  fi
done
if [[ -n "$unclassified" ]]; then
  echo "e2e: mappings not classifiable to any case:$unclassified" >&2
  echo "e2e: name the file after its case, list cases in metadata.\"x-cases\", or set metadata.\"x-shared\": true" >&2
  exit 1
fi

# Every classified mapping (shared plus every case's), once, deduplicated —
# a mapping named in more than one case's `metadata."x-cases"` appears in
# more than one list file but must still load only once.
# A case whose own stub(s) declare `requiredScenarioState` (WireMock
# Scenarios — the only way to answer two byte-identical requests
# differently once every stub loads together) must be run from exactly
# that state; scenarios reset to `Started` before every case, so a case
# needing anything else sets it directly, derived from its own stub's own
# `requiredScenarioState` — no separate case-file declaration exists or is
# needed (references/testing.md).
set_scenario_states() {
  local list="$INDEX/case-$1.list" m name state
  [[ -f "$list" ]] || return 0
  while IFS= read -r m; do
    name="$(jq -r '.scenarioName // empty' "$m")"
    state="$(jq -r '.requiredScenarioState // empty' "$m")"
    if [[ -n "$name" && -n "$state" && "$state" != "Started" ]]; then
      # The name is a URL path segment here; it needs no encoding because
      # names outside [A-Za-z0-9._~-] are refused before any case runs.
      curl -sf -X PUT "$ADMIN/scenarios/$name/state" -H 'Content-Type: application/json' \
        -d "$(jq -n --arg s "$state" '{state: $s}')" >/dev/null \
        || { echo "e2e: could not set scenario $name to $state" >&2; return 1; }
    fi
  done < "$list"
}

load_all_stubs() {
  curl -sf -X POST "$ADMIN/reset" >/dev/null || return 1
  local list m loaded=()
  for list in "$INDEX"/shared.list "$INDEX"/case-*.list; do
    [[ -f "$list" ]] || continue
    while IFS= read -r m; do loaded+=("$m"); done < "$list"
  done
  while IFS= read -r m; do
    [[ -n "$m" ]] || continue
    # Name each stub after its file: WireMock echoes `name` in the request
    # journal, which is the only stable way to see which fixture answered.
    jq -c --arg n "$(basename "$m")" '.name = $n' "$m" \
      | curl -sf -X POST "$ADMIN/mappings" -H 'Content-Type: application/json' --data-binary @- >/dev/null \
      || { echo "e2e: WireMock rejected stub $m" >&2; return 1; }
  done < <(printf '%s\n' "${loaded[@]-}" | LC_ALL=C sort -u)
}

# ── Render, credential, compose ──────────────────────────────────────────────
# The rendered router config carries this run's ports, so two suites can run
# side by side (WIREMOCK_PORT / ROUTER_PORT / ROUTER_HEALTH_PORT) without
# touching the committed tests/router.yaml.
eval "$("$RC" render "$WORKSPACE" --out "$OUT" --wiremock-port "$WIREMOCK_PORT" --router-port "$ROUTER_PORT" --health-port "$ROUTER_HEALTH_PORT")"
[ -n "${ROUTER_CONFIG:-}" ] || { echo "e2e: render produced no ROUTER_CONFIG" >&2; exit 1; }

# Fixtures assert the forwarded credential, so the router must see one. The
# env var name comes from AUTH_EXPR's test_default; the value is fixed so
# fixtures can match `… test-token` exactly.
AUTH_VAR="$("$RC" auth-env "$WORKSPACE")"
if [ -n "$AUTH_VAR" ]; then
  # Always the test token, even when the real credential is in the
  # environment (CI carries it for the live layer): WireMock's fixtures match
  # `… test-token` exactly, and a real secret must never reach a stub server
  # or its request log.
  export "$AUTH_VAR=test-token"
fi

SUPERGRAPH="$OUT/supergraph.graphql"
NO_COLOR=1 rover supergraph compose --config "$COMPOSE_CONFIG" > "$SUPERGRAPH" 2> "$OUT/compose.err" \
  || { cat "$OUT/compose.err" >&2; echo "e2e: compose failed" >&2; exit 1; }

# ── Start WireMock and the router ────────────────────────────────────────────
WM_ROOT="$OUT/wiremock"
mkdir -p "$WM_ROOT/mappings" "$WM_ROOT/__files"
[ -d "$WORKSPACE/tests/fixtures/__files" ] && cp -r "$WORKSPACE/tests/fixtures/__files/." "$WM_ROOT/__files/"
java -jar "$WIREMOCK_JAR" --port "$WIREMOCK_PORT" --root-dir "$WM_ROOT" --disable-banner > "$OUT/wiremock.log" 2>&1 &
WIREMOCK_PID=$!
deadline=$(( $(date +%s) + 30 ))
until curl -sf "$ADMIN/" >/dev/null 2>&1; do
  [ "$(date +%s)" -ge "$deadline" ] && { echo "e2e: WireMock did not start"; tail -20 "$OUT/wiremock.log" >&2; exit 1; }
  sleep 0.5
done

env -u OTEL_EXPORTER_OTLP_ENDPOINT "$ROUTER_BIN" --supergraph "$SUPERGRAPH" --config "$ROUTER_CONFIG" > "$OUT/router.log" 2>&1 &
ROUTER_PID=$!
# A large supergraph takes the router longer than 30s to load (Databricks:
# 152.6s to healthy); E2E_ROUTER_START_SECONDS raises the wait, the default
# stays 30.
router_wait=${E2E_ROUTER_START_SECONDS:-30}
router_started=$(date +%s)
deadline=$(( router_started + router_wait ))
until curl -sf "http://localhost:${ROUTER_HEALTH_PORT}/health" >/dev/null 2>&1; do
  # A router that exits (a bad config, a supergraph it rejects) is not waited
  # out to the deadline.
  kill -0 "$ROUTER_PID" 2>/dev/null || { echo "e2e: router exited before it reported healthy"; tail -30 "$OUT/router.log" >&2; exit 1; }
  [ "$(date +%s)" -ge "$deadline" ] && { echo "e2e: router did not start within ${router_wait}s (set E2E_ROUTER_START_SECONDS to wait longer)"; tail -30 "$OUT/router.log" >&2; exit 1; }
  sleep 1
done
echo "e2e: WireMock $WIREMOCK_VERSION (java), Apollo Router $ROUTER_VERSION, $(rover --version | head -1), ${#run_cases[@]} cases"
if [[ -n "$ONLY" ]]; then
  echo "e2e: --only '$ONLY' matched ${#run_cases[@]} of ${#case_files[@]} case(s)"
fi
load_all_stubs || { echo "e2e: could not load stubs" >&2; exit 1; }
# One line per included operation, tab-separated, `-` for an empty column:
# root field, the non-2xx statuses it documents, the ones a recorded run
# already exercised (unused here), and the operation key (`get:/repos/{o}`).
ERROR_STATUSES="$("$RC" error-statuses "$WORKSPACE")" || { echo "e2e: could not read the documented error statuses" >&2; exit 1; }
# The statuses the journal shows answering the operation's OWN request: a
# matched entry with the operation's method whose URL path (query dropped)
# ends with its path template, segment by segment, a {parameter} standing
# for exactly one non-empty segment. A status served to any other request
# in the case (a nested lookup, a side call) is not the operation's.
# shellcheck disable=SC2016
OWN_STATUSES_JQ='
  def segs: split("/");
  def ends_with_template($t):
    segs as $p | ($t | ltrimstr("/") | segs) as $q
    | ($p | length) >= ($q | length)
      and ([range(0; $q | length) as $i
            | ($p[($p | length) - ($q | length) + $i]) as $ps
            | (if ($q[$i] | test("^\\{.*\\}$")) then ($ps | length) > 0 else $ps == $q[$i] end)]
           | all);
  [.requests[] | select(.wasMatched)
   | select((.request.method | ascii_upcase) == ($m | ascii_upcase))
   | select((.request.url | split("?")[0]) | ends_with_template($t))
   | .response.status | tostring] | unique | join(",")'

# ── Cases ────────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; UNPROVEN=0
for query_file in "${run_cases[@]}"; do
  name="$(basename "${query_file%.graphql}")"
  expected="${query_file%.graphql}.expected.json"

  # Only the journal and scenario state reset — every stub loaded above
  # stays in place for every case: every stub is mounted flat.
  if ! curl -sf -X POST "$ADMIN/scenarios/reset" >/dev/null; then echo "FAIL: $name — could not reset scenario state"; FAIL=$((FAIL+1)); continue; fi
  if ! curl -sf -X DELETE "$ADMIN/requests" >/dev/null; then echo "FAIL: $name — could not reset the request journal"; FAIL=$((FAIL+1)); continue; fi
  if ! set_scenario_states "$name"; then echo "FAIL: $name — could not set its stub's scenario state"; FAIL=$((FAIL+1)); continue; fi

  actual="$(curl -sf -X POST "http://localhost:${ROUTER_PORT}/" -H 'Content-Type: application/json' \
    -d "$(jq -n --rawfile query "$query_file" '{query: $query}')")" || { echo "FAIL: $name — router request failed"; FAIL=$((FAIL+1)); continue; }

  # One read of each journal per case, each guarded, so an admin API that
  # fails fails this case with a line saying so instead of aborting the run.
  journal="$(curl -sf "$ADMIN/requests")" || { echo "FAIL: $name — could not read the request journal"; FAIL=$((FAIL+1)); continue; }
  unmatched_journal="$(curl -sf "$ADMIN/requests/unmatched")" || { echo "FAIL: $name — could not read the unmatched-request journal"; FAIL=$((FAIL+1)); continue; }
  unmatched="$(jq '.requests | length' <<< "$unmatched_journal")"
  matched="$(jq '[.requests[] | select(.wasMatched)] | length' <<< "$journal")"
  if grep -q 'expect-unmatched-upstream' "$query_file"; then
    if [[ "$unmatched" == "0" ]]; then echo "FAIL: $name — expected an unmatched upstream request, saw none (matched: $matched)"; FAIL=$((FAIL+1)); continue; fi
  else
    if [[ "$unmatched" != "0" ]]; then
      echo "FAIL: $name — $unmatched upstream request(s) matched no loaded stub:"
      jq -r '.requests[] | "       \(.method) \(.url)\(if .body != "" then "\n       body: \(.body)" else "" end)"' <<< "$unmatched_journal"
      FAIL=$((FAIL+1)); continue
    fi
    if [[ "$matched" == "0" ]]; then echo "FAIL: $name — case made no upstream request (dead stubs?)"; FAIL=$((FAIL+1)); continue; fi
  fi
  own=""
  for list in "$INDEX/shared.list" "$INDEX/case-$name.list"; do
    [[ -f "$list" ]] || continue
    while IFS= read -r m; do own+="$(basename "$m")"$'\n'; done < "$list"
  done
  foreign="$(jq -r '.requests[] | select(.wasMatched) | (.stubMapping.name // "<unnamed stub>")' <<< "$journal" \
    | while IFS= read -r n; do grep -qxF -- "$n" <<< "$own" || echo "$n"; done | LC_ALL=C sort -u | paste -sd, -)"
  if [[ -n "$foreign" ]]; then
    echo "FAIL: $name — answered by another case's stub: $foreign (the connector's request matched a fixture this case does not own)"
    FAIL=$((FAIL+1)); continue
  fi
  # A stub of the case's own marked `metadata."x-required": true` must have
  # answered at least one request: "some stub matched" cannot tell a $batch
  # case whose lookup ran from one the planner resolved without it.
  answered="$(jq -r '.requests[] | select(.wasMatched) | (.stubMapping.name // empty)' <<< "$journal" | LC_ALL=C sort -u)"
  uncalled=""
  if [[ -f "$INDEX/case-$name.list" ]]; then
    while IFS= read -r m; do
      if jq -e '.metadata["x-required"] == true' "$m" >/dev/null 2>&1 \
        && ! grep -qxF -- "$(basename "$m")" <<< "$answered"; then
        uncalled="$uncalled $(basename "$m")"
      fi
    done < "$INDEX/case-$name.list"
  fi
  if [[ -n "$uncalled" ]]; then
    echo "FAIL: $name — required stub(s) never called:$uncalled (metadata.\"x-required\": the case passes only when the router sends that request)"
    FAIL=$((FAIL+1)); continue
  fi
  # Every answering stub is the case's own by now. A status counts for an
  # operation only when the journal shows it answering that operation's own
  # request: the statuses a nested lookup or side call was served
  # belong to no operation under test. `OWN` holds one line per operation
  # whose root field the case calls: key, own statuses, documented statuses.
  served="$(jq -r '[.requests[] | select(.wasMatched) | .response.status] | unique | map(tostring) | join(",")' <<< "$journal")"
  OWN=""
  while IFS=$'\t' read -r field statuses _executed opkey; do
    [[ -n "$field" && -n "$opkey" ]] || continue
    grep -qw -- "$field" "$query_file" || continue
    own="$(jq -r --arg m "${opkey%%:*}" --arg t "${opkey#*:}" "$OWN_STATUSES_JQ" <<< "$journal")" \
      || { own=""; echo "e2e: could not read $opkey's own statuses from the journal" >&2; }
    OWN+="$opkey"$'\t'"${own:--}"$'\t'"$statuses"$'\n'
  done <<< "$ERROR_STATUSES"
  expect_status="$(sed -n 's/^#[[:space:]]*expect-upstream-status:[[:space:]]*\([0-9][0-9][0-9]\).*/\1/p' "$query_file" | head -1)"
  unproven=""
  credit=""
  if [[ -n "$expect_status" ]]; then
    hit=""
    while IFS=$'\t' read -r opkey own _documented; do
      [[ -n "$opkey" ]] || continue
      if grep -qxF -- "$expect_status" <<< "${own//,/$'\n'}"; then hit=1; credit+="$opkey $expect_status"$'\n'; fi
    done <<< "$OWN"
    if [[ -z "$OWN" ]]; then
      # No root field of the case names an included operation: nothing to
      # attribute a status to, so the case's own stubs are all there is.
      if grep -qxF -- "$expect_status" <<< "${served//,/$'\n'}"; then hit=1; fi
    fi
    if [[ -z "$hit" ]]; then
      answered="$(awk -F'\t' 'NF && $1 != "" {printf "%s answered %s; ", $1, ($2 == "-" ? "nothing" : $2)}' <<< "$OWN")"
      echo "FAIL: $name — expected the operation's own request to answer $expect_status (expect-upstream-status); ${answered:-its stubs answered ${served:-nothing}}${served:+(every request in the case: $served)}"
      FAIL=$((FAIL+1)); continue
    fi
  else
    while IFS=$'\t' read -r opkey own documented; do
      [[ -n "$opkey" && "$own" != "-" ]] || continue
      nonok="$(tr ',' '\n' <<< "$own" | grep -E '^[13-9][0-9][0-9]$' | paste -sd, - || true)"
      [[ -n "$nonok" ]] || continue
      if [[ "$documented" == *,* ]]; then
        unproven="$opkey's own request was answered $nonok, and it documents $documented: add \`# expect-upstream-status: CODE\`"
        break
      fi
      for c in ${nonok//,/ }; do credit+="$opkey $c"$'\n'; done
    done <<< "$OWN"
    [[ -z "$unproven" ]] || credit=""
  fi

  if [[ "$GENERATE" -eq 1 ]]; then
    echo "$actual" | jq -S . > "$expected"
    echo "WROTE: $(basename "$expected")"; PASS=$((PASS+1))
    [[ -z "$unproven" ]] || echo "       unproven: $unproven"
  elif [[ ! -f "$expected" ]]; then
    echo "FAIL: $name — no expected file (run with --generate, then audit the snapshot)"; FAIL=$((FAIL+1))
  elif diff <(echo "$actual" | jq -S .) <(jq -S . "$expected") > /dev/null; then
    if [[ -n "$unproven" ]]; then
      echo "UNPROVEN: $name — $unproven"; UNPROVEN=$((UNPROVEN+1))
    else
      echo "PASS: $name"; PASS=$((PASS+1))
      # What this passing case proved, for evidence's per-status coverage:
      # a status served to an operation's own request, never to a side call.
      while read -r opkey code; do
        if [[ -n "$opkey" ]]; then echo "SERVED: $name $opkey $code"; fi
      done <<< "$credit"
    fi
  else
    echo "FAIL: $name"; diff <(echo "$actual" | jq -S .) <(jq -S . "$expected") || true; FAIL=$((FAIL+1))
  fi
done

if [[ "$GENERATE" -eq 1 ]]; then
  echo "e2e: $PASS expected files written, $FAIL failed — audit every snapshot for \"redacted\", \"valueCompletion\" and errors before committing"
else
  echo "e2e: $PASS passed, $FAIL failed$([[ "$UNPROVEN" -eq 0 ]] || echo ", $UNPROVEN unproven")"
fi
[ "$FAIL" -eq 0 ]
