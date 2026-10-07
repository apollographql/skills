#!/usr/bin/env bash
# session-start.sh — the plugin's SessionStart hook (hooks/hooks.json), also
# run by this repository's own .claude/settings.json in a remote session.
#
#   session-start.sh        # what Claude Code runs; by hand it does the same
#
# Other agents have no SessionStart hook: they run scripts/bootstrap.sh once
# and source scripts/env.sh, which sets the same variables.
#
# 1. Puts the graphos-factory binary (and the graphos-factory-core link) in
#    the bootstrap cache: no network when a binary at least as new as this
#    checkout's pin is already there, else scripts/bootstrap.sh downloads the
#    release (never --build: a plugin user has no reason to need cargo).
# 2. Appends PATH (the cache's bin/ and ~/.rover/bin),
#    GRAPHOS_FACTORY_CORE_SCRIPTS and GRAPHOS_FACTORY_TARGET_SCRIPTS (this
#    directory, where `evidence` finds supergraph-check.sh) to
#    $CLAUDE_ENV_FILE, so the agent runs `graphos-factory` and the wrappers
#    bare for the rest of the session.
# 3. Runs toolchain.sh --check and never toolchain.sh itself: that install
#    downloads about 100 MB, its rover installer edits shell profiles and it
#    needs the user's own ELv2 acceptance (APOLLO_ELV2_LICENSE=accept), so it is a step the user sees.
# 4. Prints a few lines for the agent's context (SessionStart stdout is
#    context): the version, the scripts paths, what supergraph_check needs
#    (the user's APOLLO_KEY and a graph ref given for the run), and either
#    "toolchain ready" or the command to run.
#
# The hook is synchronous on purpose: the first run downloads about 3 MB, and
# every later one makes no network call, while an async hook's env file is
# not guaranteed to reach the session's first commands. Two copies at once
# (the plugin's and a remote clone's project hook) take turns on a lock in
# the cache, so only one downloads: the other waits up to 60 s and finds the
# binary in place, or skips the install with one line, never running
# bootstrap.sh beside the first. bootstrap.sh bounds every curl (135 s at
# most), so the wait and one download fit the hooks' 240 s timeout.
# It never fails the session: every step that can fail prints one line and
# the script exits 0. Bash 3.2 compatible (macOS /bin/bash).
set -euo pipefail

NAME=graphos-factory
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP="$HERE/bootstrap.sh"
# The core: the copy inside this skill (the public tree carries one, so a
# skill installed on its own has it too), else the plugin's or checkout's
# root copy.
SCRIPTS=""
for core in "$HERE/../graphos-factory-core" "${CLAUDE_PLUGIN_ROOT:-$HERE/../../..}/graphos-factory-core"; do
  if [ -f "$core/scripts/cache.sh" ]; then SCRIPTS="$(cd "$core/scripts" && pwd)"; break; fi
done
if [ -z "$SCRIPTS" ] || [ ! -f "$BOOTSTRAP" ]; then
  echo "$NAME: no graphos-factory-core/scripts beside $HERE or at the plugin root; the binary was not installed"
  exit 0
fi

# shellcheck source=SCRIPTDIR/../../../graphos-factory-core/scripts/cache.sh
. "$SCRIPTS/cache.sh"
CACHE="$GRAPHOS_FACTORY_CORE_CACHE_DIR"
BIN_DIR="$CACHE/bin"
BIN="$BIN_DIR/$NAME"
LOG="$CACHE/session-start.log"
# The pin bootstrap.sh installs and resolve-bin.sh checks, read the same way:
# $GRAPHOS_FACTORY_CORE_VERSION when set, else cache.sh's (crate/Cargo.toml
# in a checkout, release.env in the skill's own copy of the core).
PIN="${GRAPHOS_FACTORY_CORE_VERSION:-$GRAPHOS_FACTORY_CORE_PIN}"

# The environment first: static, so it is right whether or not the install
# below succeeds. $HOME and $PATH reach the env file unexpanded.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  {
    # shellcheck disable=SC2016
    printf 'export PATH="$HOME/.rover/bin":%q:"$PATH"\n' "$BIN_DIR"
    printf 'export GRAPHOS_FACTORY_CORE_SCRIPTS=%q\n' "$SCRIPTS"
    printf 'export GRAPHOS_FACTORY_TARGET_SCRIPTS=%q\n' "$HERE"
  } >> "$CLAUDE_ENV_FILE" || echo "$NAME: could not write $CLAUDE_ENV_FILE"
fi

installed_version() {
  if [ -x "$BIN" ]; then "$BIN" version 2>/dev/null | sed -n 's/^[a-z][a-z0-9-]* \([0-9][^ ]*\).*/\1/p' | head -1; fi
  true
}

# 0 when version $1 is older than $2 (or unreadable), the rule resolve-bin.sh
# applies: a newer binary (the edge build) is accepted, an older one is not.
older() {
  local a b i x y
  IFS=. read -r -a a <<< "${1%%[-+]*}"
  IFS=. read -r -a b <<< "${2%%[-+]*}"
  for i in 0 1 2; do
    x="${a[$i]:-0}"; y="${b[$i]:-0}"
    case "$x$y" in *[!0-9]*) return 0 ;; esac
    if [ "$((10#$x))" -lt "$((10#$y))" ]; then return 0; fi
    if [ "$((10#$x))" -gt "$((10#$y))" ]; then return 1; fi
  done
  return 1
}

current() {
  local have
  have="$(installed_version)"
  [ -n "$have" ] && [ -n "$PIN" ] && [ -x "$BIN_DIR/graphos-factory-core" ] && ! older "$have" "$PIN"
}

# One installer at a time per cache. A run that cannot take the lock within
# 60 s skips the install rather than racing the holder. A lock older than
# four minutes (the hooks' timeout) was left by a killed run.
LOCK="$CACHE/.session-start.lock"
WAIT=60
if ! current; then
  locked=0 waited=0
  if ! mkdir -p "$CACHE" 2>/dev/null; then
    echo "$NAME: cannot create $CACHE; the binary was not installed"
  else
    while :; do
      if mkdir "$LOCK" 2>/dev/null; then locked=1; break; fi
      if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +4 2>/dev/null)" ] && rmdir "$LOCK" 2>/dev/null; then continue; fi
      [ "$waited" -lt "$WAIT" ] || break
      sleep 1; waited=$((waited + 1))
    done
    if [ "$locked" -eq 1 ]; then
      trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT
      if ! current; then
        if ! bash "$BOOTSTRAP" > "$LOG" 2>&1 || ! current; then
          echo "$NAME: not installed ($(grep -v '^ ' "$LOG" 2>/dev/null | tail -1)); full log $LOG; retry with: bash \"$BOOTSTRAP\""
        fi
      fi
      rmdir "$LOCK" 2>/dev/null || true
      trap - EXIT
    elif ! current; then
      echo "$NAME: install skipped: another install held $LOCK for ${WAIT} s; run: bash \"$BOOTSTRAP\""
    fi
  fi
fi

if current; then
  echo "Installed: $("$BIN" version 2>/dev/null | head -1) at $BIN_DIR, on PATH for this session with its graphos-factory-core link."
fi
echo "Wrapper scripts: GRAPHOS_FACTORY_CORE_SCRIPTS=$SCRIPTS (supergraph-check.sh: GRAPHOS_FACTORY_TARGET_SCRIPTS=$HERE)"
echo "supergraph_check runs rover subgraph check only with the user's APOLLO_KEY in the environment and a graph ref: ask once which <graph>@<variant>, then set GRAPHOS_FACTORY_GRAPH_REF on your commands (their GRAPHOS_FACTORY_SUPERGRAPH_CHECK=auto uses \$APOLLO_GRAPH_REF; never set it). Never ask for, set or print the key."
if missing="$(bash "$SCRIPTS/toolchain.sh" --check 2>&1 >/dev/null)"; then
  echo "Toolchain: ready (rover, supergraph plugin, Apollo Router, WireMock)."
else
  echo "Toolchain: not installed (${missing%%$'\n'*}). Compose, unit, e2e and live need it."
  echo "Before running them, ask the user, then run: bash \"\$GRAPHOS_FACTORY_CORE_SCRIPTS/toolchain.sh\""
  echo "It downloads about 100 MB: rover (whose installer edits ~/.profile and ~/.zshenv), its supergraph plugin, the Apollo Router and WireMock."
  echo "Java 17+ and jq are prerequisites it does not install. The composition plugin and the Apollo Router are under the Elastic License v2 (https://www.elastic.co/licensing/elastic-license). Ask the user once, showing the link; on an explicit yes, set APOLLO_ELV2_LICENSE=accept for the commands you run this session and tell them an \`export\` in their shell profile makes it permanent. Never set it unasked; until it is set, compose, unit, e2e and live report not_run."
fi
exit 0
