#!/usr/bin/env bash
# unit.sh — `rover connector test` over every tests/*.connector.yaml suite.
#
#   unit.sh [workspace-dir] [--only PATTERN]
#
# Layer 2. It asserts the *outbound request* a connector builds (method, URL,
# headers, body) and how a supplied response body maps back into the schema.
# It never reaches the network, so it cannot tell you the API agrees with the
# fixture — only that the connector sends what you meant and maps what it is
# given (references/testing.md).
#
# Two rover behaviours this wrapper exists to absorb:
#   * `connector test` reads no supergraph.yaml pin, so it resolves its
#     composition plugin from the network on every run unless --skip-update is
#     given and a plugin is already cached. We seed the cache with the pin.
#   * it prints "TEST RESULTS: FAILED" and still exits 0. Its exit status
#     cannot gate anything; the summary line is the verdict, and a run with no
#     summary at all fails closed.
#
# Zero cases is not a pass: rover reports an empty suite as SUCCESSFUL with
# "0 passed; 0 failed", and nothing was proven. Cases are counted per suite
# from rover's TEST SUITE / TEST CASE listing, subdirectories of tests/
# included; a suite rover lists that unit.sh cannot match to a file, or the
# reverse, fails the run. Every suite that ran no case must cite, in the
# first sentence of its header comment, the decision behind it (a D-nnnn
# or random D-k7m2qx id from the decision log), or the run fails (exit
# 1), the way live.sh fails an exclusion with no reason. When no suite ran a
# case, the run exits 3 (not_run) with "unit: no runnable cases:" and each
# suite's sentence; when others did, it passes and names the empty ones. A
# `skip: true` case is not a pass either: any skipped count fails. A missing
# suite file is still a failure.
#
# Exit codes: 0 pass · 1 fail · 3 not_run (no suite ran a case, each citing
# its decision; or APOLLO_ELV2_LICENSE is not `accept`, see elv2.sh) · 127 a
# tool is missing.
#
# --only PATTERN runs only the `tests:` entries (rover's own unit of "one
# test") whose quoted `name:` contains PATTERN as a literal substring, across
# every suite file. rover has no name-level filter, so a suite that has any
# match is rewritten to a temporary copy holding only the matching entries
# under its own `config:` header, and that copy is what gets tested — a
# suite with zero matches is left out entirely. A PATTERN matching no entry
# in any suite fails closed (exit 1, no rover invocation) rather than let
# rover report a vacuous "0 passed; 0 failed" as a green summary.
set -euo pipefail

WORKSPACE="."
ONLY=""
while [ $# -gt 0 ]; do
  case "$1" in
    --only)
      if [ $# -lt 2 ] || [ -z "$2" ]; then echo "unit: --only requires a non-empty pattern" >&2; exit 1; fi
      ONLY="$2"; shift 2 ;;
    *)
      WORKSPACE="$1"; shift ;;
  esac
done
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

# Rewrites $2 to hold only the $1 suite's `tests:` entries whose quoted
# `name:` contains $3 as a substring, keeping $1's own `config:` header.
# Prints the number of entries kept.
extract_only() {
  local src="$1" dst="$2" pattern="$3"
  local tests_line body_end
  tests_line="$(grep -n '^tests:$' "$src" | head -1 | cut -d: -f1)"
  if [ -z "$tests_line" ]; then
    # A deliberately empty suite (`tests: []`) has nothing to match.
    if grep -Eq '^tests:[[:space:]]*\[[[:space:]]*\][[:space:]]*(#.*)?$' "$src"; then echo 0; return 0; fi
    echo "unit: $src has no top-level 'tests:' key" >&2
    return 1
  fi
  body_end="$(awk -v start="$tests_line" '
    NR>start && /^[A-Za-z_][A-Za-z0-9_-]*:/ && !found { boundary=NR-1; found=1 }
    END { if (found) print boundary; else print NR }
  ' "$src")"
  sed -n "1,${tests_line}p" "$src" > "$dst"
  awk -v pattern="$pattern" -v from="$((tests_line + 1))" -v to="$body_end" '
    NR<from || NR>to { next }
    /^  - name: "/ {
      if (block != "" && index(name, pattern) > 0) printf "%s", block
      block = $0 "\n"
      name = $0
      sub(/^  - name: "/, "", name)
      sub(/"$/, "", name)
      next
    }
    { block = block $0 "\n" }
    END { if (block != "" && index(name, pattern) > 0) printf "%s", block }
  ' "$src" >> "$dst"
  # `grep -c` exits 1 on a zero count, which is an ordinary outcome here
  # (this suite just has no matching entry) — never let it read as the
  # function's own failure, which is reserved for the missing-`tests:` case.
  grep -c '^  - name: "' "$dst" || true
}

# The product binary, and a refusal (exit 78) when it is older than
# the version these scripts pin — see resolve-bin.sh for the order and why.
# shellcheck source=SCRIPTDIR/resolve-bin.sh
. "$(dirname "$0")/resolve-bin.sh"

if ! command -v rover >/dev/null 2>&1; then
  echo "unit: rover is not installed" >&2
  exit 127
fi

# shellcheck source=SCRIPTDIR/elv2.sh
. "$(dirname "$0")/elv2.sh"
elv2_require unit

shopt -s nullglob
suites=("$WORKSPACE"/tests/*.connector.yaml)
shopt -u nullglob
if [ ${#suites[@]} -eq 0 ]; then
  echo "unit: no tests/*.connector.yaml suite in $WORKSPACE" >&2
  echo "unit: every selected operation whose arguments are scalars needs one — this is a failure, not a skip" >&2
  exit 1
fi

# --unit also rewrites static {$env.NAME} to {$config.NAME} in the temporary
# copy: the framework injects $config, $args, $context, $this and $batch, but
# not $env. The committed schema keeps {$env...}.
eval "$("$RC" render "$WORKSPACE" --out "$OUT" --unit)"

# rover reads the user's own APOLLO_ELV2_LICENSE=accept (checked above) for
# the plugin install and the test run alike.
if ! ls "$HOME/.rover/bin"/supergraph-v* >/dev/null 2>&1; then
  echo "unit: no supergraph plugin cached; installing the pinned v$FEDERATION_VERSION"
  rover install --plugin "supergraph@=$FEDERATION_VERSION"
fi

TESTDIR="$WORKSPACE/tests"
if [ -n "$ONLY" ]; then
  mkdir -p "$OUT/only"
  total=0
  for suite in "${suites[@]}"; do
    n="$(extract_only "$suite" "$OUT/only/$(basename "$suite")" "$ONLY")" || exit 1
    total=$((total + n))
    [ "$n" -gt 0 ] || rm -f "$OUT/only/$(basename "$suite")"
  done
  if [ "$total" -eq 0 ]; then
    echo "unit: --only '$ONLY' matched no case in ${#suites[@]} suite(s) under $TESTDIR" >&2
    exit 1
  fi
  TESTDIR="$OUT/only"
  echo "unit: --only '$ONLY' matched $total case(s)"
fi

echo "unit: $(rover --version | head -1), ${#suites[@]} suite(s)"
# The temporary schema reads each static credential as {$config.NAME}, and
# only the suite supplies it: a suite with a case that lacks one fails every
# case for the wrong reason. Each suite this run executes (with --only, the
# ones holding a matching case) must hold every name render listed under
# config.common.variables.$config; a suite with no case needs none.
if [ -n "${CONFIG_VARS:-}" ]; then
  if ! command -v jq >/dev/null 2>&1; then
    echo "unit: jq is not installed (it reads each suite's \$config variables)" >&2
    exit 127
  fi
  read -ra config_vars <<<"$CONFIG_VARS"
  config_missing=0
  for suite in "${suites[@]}"; do
    if [ -n "$ONLY" ] && [ ! -f "$OUT/only/$(basename "$suite")" ]; then continue; fi
    if ! supplied="$("$RC" yaml2json "$suite" | jq -r '
        if type != "object" then "!suite"
        elif ((.tests // []) | length) == 0 then "-"
        else (.config.common.variables["$config"] // {}) as $c
          | if ($c | type) == "object" then ($c | keys[]) else "!config" end
        end')"; then
      echo "unit: FAIL — $suite is not readable YAML" >&2
      exit 1
    fi
    case "$supplied" in
      -) continue ;;
      '!suite')
        echo "unit: FAIL — $suite is not a mapping: a suite is a YAML mapping with config: and tests: keys" >&2
        config_missing=1; continue ;;
      '!config')
        echo "unit: FAIL — $suite: config.common.variables.\$config is not a mapping; give it one key per variable (${config_vars[0]}: test-value)" >&2
        config_missing=1; continue ;;
    esac
    lacking=()
    for var in "${config_vars[@]}"; do
      grep -qxF -- "$var" <<<"$supplied" || lacking+=("$var")
    done
    if [ ${#lacking[@]} -gt 0 ]; then
      echo "unit: FAIL — $suite does not supply ${lacking[*]}: add each under config.common.variables.\$config (config: {common: {variables: {\$config: {${lacking[0]}: test-value}}}})" >&2
      config_missing=1
    fi
  done
  [ "$config_missing" -eq 0 ] || exit 1
fi

log="$OUT/result.log"
NO_COLOR=1 rover connector --skip-update --skip-update-check test \
  --schema "$RENDERED_SCHEMA" -d "$TESTDIR" --no-fail-fast | tee "$log"

# rover's exit status does not reflect suite failures; the summary line does,
# so the failure quotes it (evidence records this line as the reason).
if grep -q "TEST RESULTS: FAILED" "$log" || ! grep -q "TEST RESULTS: SUCCESSFUL" "$log"; then
  verdict="$(grep -m1 -o 'TEST RESULTS:.*' "$log" || true)"
  echo "unit: FAIL — ${verdict:-rover printed no TEST RESULTS summary line}" >&2
  exit 1
fi


summary="$(grep -m1 '^TEST RESULTS: SUCCESSFUL' "$log")"

# A `skip: true` case never runs; rover counts it as skipped and still says
# SUCCESSFUL. Skipped is not passed, and it is not the zero-case not_run
# either (the case exists and asserts nothing), so any skipped count fails.
skipped="$(sed -nE 's/.*[^0-9]([0-9]+)[[:space:]]+skipped.*/\1/p' <<<"$summary")"
if [ -n "$skipped" ] && [ "$skipped" -gt 0 ]; then
  echo "unit: FAIL — $skipped case(s) marked skip: true did not run; a skipped case is not a pass (make it run, or delete it and record the decision)" >&2
  exit 1
fi

# Each suite's reason for having no cases: the first sentence of its header
# comment, past the generic title line.
suite_reason() {
  awk '
    { sub(/\r$/, "") }
    !/^#/ { exit }
    { sub(/^#[ \t]*/, ""); if (tolower($0) ~ /^rover connector test suite/) next; text = text (text == "" ? "" : " ") $0 }
    END {
      if (text == "") { print "the suite header gives no reason"; exit }
      n = index(text, ". ")
      print (n > 0 ? substr(text, 1, n) : text)
    }
  ' "$1"
}

# Cases per suite, from rover's own listing: each `TEST SUITE: <path>` line
# is followed by one `TEST CASE:` line per case it ran (a skipped case prints
# none). The FAILURES section repeats both, so counting stops there. Printed
# as `<count>\t<path>`, keyed by the whole path rover gave.
suite_cases="$(awk '
  /^FAILURES:/ || /^TEST RESULTS:/ { exit }
  /^TEST SUITE: / {
    cur = $0; sub(/^TEST SUITE: /, "", cur); sub(/[ \t]+$/, "", cur)
    if (!(cur in count)) { order[++k] = cur; count[cur] = 0 }
    next
  }
  /^TEST CASE: / && cur != "" { count[cur]++ }
  END { for (i = 1; i <= k; i++) print count[order[i]] "\t" order[i] }
' "$log")"

# rover walks subdirectories of $TESTDIR, so a suite is its path relative to
# $TESTDIR. Every suite rover listed must be a file there, and every suite
# file there must be one rover listed; anything else fails rather than
# escaping the count.
cases=0
reasons=""
uncited=0
listed=""
while IFS=$'\t' read -r n path; do
  [ -n "$path" ] || continue
  rel="${path#"$TESTDIR"/}"
  if [ "$rel" = "$path" ] || [ ! -f "$TESTDIR/$rel" ]; then
    echo "unit: FAIL — rover ran $path, which unit.sh cannot account for as a suite under $TESTDIR" >&2
    exit 1
  fi
  listed="$listed$rel"$'\n'
  cases=$((cases + n))
  [ "$n" -eq 0 ] || continue
  reason="$(suite_reason "$TESTDIR/$rel")"
  # The reason is only as good as the decision it cites: without one, an
  # empty suite (or a header that says nothing about it) would clear the
  # publication gate on the fallback text alone.
  if ! grep -Eq '(^|[^[:alnum:]])D-([0-9]{4,}|[0-9a-z]{6})([^[:alnum:]]|$)' <<<"$reason"; then
    echo "unit: FAIL — $rel has no cases and its header's first sentence cites no decision (D-0019 or D-k7m2qx): $reason" >&2
    uncited=$((uncited + 1))
  fi
  reasons="${reasons:+$reasons; }$rel: $reason"
done <<<"$suite_cases"
while IFS= read -r suite; do
  rel="${suite#"$TESTDIR"/}"
  if ! grep -Fxq -- "$rel" <<<"$listed"; then
    echo "unit: FAIL — rover printed no TEST SUITE line for $rel, so its cases cannot be counted" >&2
    exit 1
  fi
done < <(find "$TESTDIR" -type f -name '*.connector.yaml')
[ "$uncited" -eq 0 ] || exit 1


# rover's count and its listing must agree on whether anything ran; if its
# output format moves, fail rather than guess.
if grep -Eq '^TEST RESULTS: SUCCESSFUL[[:space:]]+0[[:space:]]+passed;[[:space:]]+0[[:space:]]+failed' <<<"$summary"; then
  zero_summary=1
else
  zero_summary=0
fi
if { [ "$cases" -eq 0 ] && [ "$zero_summary" -eq 0 ]; } || { [ "$cases" -gt 0 ] && [ "$zero_summary" -eq 1 ]; }; then
  echo "unit: FAIL — rover listed $cases case(s) but summarised: $summary" >&2
  exit 1
fi

if [ "$cases" -eq 0 ]; then
  echo "unit: no runnable cases: $reasons (not_run)"
  exit 3
fi
if [ -n "$reasons" ]; then
  echo "unit: empty beside suites that ran: $reasons"
fi
echo "unit: pass"
