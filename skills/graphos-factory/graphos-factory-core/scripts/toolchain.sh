#!/usr/bin/env bash
# toolchain.sh — install the tools the validation layers shell out to.
#
#   toolchain.sh            # rover + the pinned supergraph plugin, Apollo Router, WireMock
#   toolchain.sh --check    # exit 0 if all four are present at the pinned versions, 1 otherwise
#
# The supergraph plugin and the Apollo Router are licensed under the Elastic
# License v2, which only the user can accept: read it, then set
# APOLLO_ELV2_LICENSE=accept (see elv2.sh). This script never sets it. Unset,
# it installs rover and WireMock, downloads neither the plugin nor the
# Router, says so, and exits 0; compose, unit, e2e and live then report
# `not_run` until the variable is set. --check reports a missing plugin or
# Router with the same instruction (exit 1), and both present with the
# variable unset as a note (exit 0: the tools are installed).
#
# One source of truth for the pins and their install paths; the SessionStart
# hook and CI both call this instead of carrying their own copy:
#   rover $ROVER_VERSION + supergraph-v$FEDERATION_VERSION   -> $HOME/.rover/bin      (compose.sh, unit.sh, e2e.sh, live.sh)
#   router-$ROUTER_VERSION                                   -> $GRAPHOS_FACTORY_CORE_CACHE      (e2e.sh, live.sh)
#   wiremock-standalone-$WIREMOCK_VERSION.jar                -> $GRAPHOS_FACTORY_CORE_CACHE      (e2e.sh)
# FEDERATION_VERSION must match pilots/*/*/.factory/workspace.yaml; ROUTER_VERSION
# and WIREMOCK_VERSION must match the defaults in e2e.sh and live.sh.
#
# Java is not installed here: e2e.sh and live.sh need it, but every host this
# runs on (the web container, CI's setup-java) already provides it. The
# product binary is bootstrap.sh's job. $GRAPHOS_FACTORY_CORE_CACHE defaults as cache.sh
# says.
#
# Idempotent: every step is skipped when its version is already in place.
# Exit codes: 0 installed · 1 a download failed · 127 no router build for this platform.
set -euo pipefail

ROVER_VERSION="${ROVER_VERSION:-0.41.0}"
FEDERATION_VERSION="${FEDERATION_VERSION:-2.15.2}"
ROUTER_VERSION="${ROUTER_VERSION:-2.17.0}"
WIREMOCK_VERSION="${WIREMOCK_VERSION:-3.13.2}"
# shellcheck source=SCRIPTDIR/cache.sh
. "$(dirname "$0")/cache.sh"
CACHE="$GRAPHOS_FACTORY_CORE_CACHE_DIR"
ROVER_BIN="$HOME/.rover/bin"
ROUTER="$CACHE/router-$ROUTER_VERSION"
WIREMOCK_JAR="$CACHE/wiremock-standalone-$WIREMOCK_VERSION.jar"
export PATH="$ROVER_BIN:$PATH"
# shellcheck source=SCRIPTDIR/elv2.sh
. "$(dirname "$0")/elv2.sh"

MODE="install"
for arg in "$@"; do
  case "$arg" in
    --check) MODE="check" ;;
    -h|--help) sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "toolchain: unknown argument $arg" >&2; exit 1 ;;
  esac
done

have_rover()    { [ "$("$ROVER_BIN/rover" --version 2>/dev/null || true)" = "Rover $ROVER_VERSION" ]; }
have_plugin()   { [ -x "$ROVER_BIN/supergraph-v$FEDERATION_VERSION" ]; }
have_router()   { [ -x "$ROUTER" ]; }
have_wiremock() { [ -f "$WIREMOCK_JAR" ]; }

router_platform() {
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)   echo "x86_64-unknown-linux-gnu" ;;
    Linux-aarch64)  echo "aarch64-unknown-linux-gnu" ;;
    Darwin-x86_64)  echo "x86_64-apple-darwin" ;;
    Darwin-arm64)   echo "aarch64-apple-darwin" ;;
    *) echo "" ;;
  esac
}

if [ "$MODE" = "check" ]; then
  missing=0
  have_rover    || { echo "toolchain: rover $ROVER_VERSION is not at $ROVER_BIN" >&2; missing=1; }
  # The two ELv2-licensed pieces: a missing one fails, and the instruction
  # is printed once when the user has not accepted.
  elv2_missing=0
  have_plugin   || { echo "toolchain: supergraph plugin v$FEDERATION_VERSION is not at $ROVER_BIN" >&2; missing=1; elv2_missing=1; }
  have_router   || { echo "toolchain: Apollo Router $ROUTER_VERSION is not at $ROUTER" >&2; missing=1; elv2_missing=1; }
  have_wiremock || { echo "toolchain: WireMock $WIREMOCK_VERSION is not at $WIREMOCK_JAR" >&2; missing=1; }
  if ! elv2_accepted; then
    [ "$elv2_missing" -eq 1 ] \
      || echo "toolchain: note — the supergraph plugin and the Apollo Router are installed, but APOLLO_ELV2_LICENSE is not set to accept" >&2
    elv2_explain toolchain
  fi
  [ "$missing" -eq 0 ] && echo "toolchain: rover $ROVER_VERSION, supergraph v$FEDERATION_VERSION, router $ROUTER_VERSION, wiremock $WIREMOCK_VERSION present"
  exit "$missing"
fi

# ── rover + composition plugin ───────────────────────────────────────────────
if have_rover; then
  echo "rover $ROVER_VERSION already installed"
else
  echo "installing rover $ROVER_VERSION"
  curl -fsSL "https://rover.apollo.dev/nix/v${ROVER_VERSION}" | sh -s -- --force
fi

# What the user's missing ELv2 acceptance held back, explained once at the end.
held=""
plugin="supergraph v$FEDERATION_VERSION"
if have_plugin; then
  echo "supergraph plugin v$FEDERATION_VERSION already installed"
elif elv2_accepted; then
  # rover reads the user's own APOLLO_ELV2_LICENSE=accept; no flag here.
  echo "installing supergraph plugin v$FEDERATION_VERSION"
  "$ROVER_BIN/rover" install --plugin "supergraph@=$FEDERATION_VERSION"
else
  held="supergraph plugin v$FEDERATION_VERSION"
  plugin="no supergraph plugin"
fi

# ── router + WireMock for the e2e and live layers ────────────────────────────
mkdir -p "$CACHE"
router="router $ROUTER_VERSION"
if have_router; then
  echo "router $ROUTER_VERSION already cached"
elif ! elv2_accepted; then
  held="${held:+$held and the }Apollo Router $ROUTER_VERSION"
  router="no router"
else
  platform="$(router_platform)"
  if [ -z "$platform" ]; then
    echo "toolchain: no Apollo Router build for $(uname -s)-$(uname -m); e2e.sh and live.sh will report it as skipped" >&2
    exit 127
  fi
  echo "caching Apollo Router $ROUTER_VERSION ($platform)"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "https://github.com/apollographql/router/releases/download/v${ROUTER_VERSION}/router-v${ROUTER_VERSION}-${platform}.tar.gz" \
    | tar xzf - -C "$tmp" --strip-components=1 dist/router
  mv "$tmp/router" "$ROUTER" && chmod +x "$ROUTER"
fi

if have_wiremock; then
  echo "WireMock $WIREMOCK_VERSION already cached"
else
  echo "caching WireMock $WIREMOCK_VERSION"
  curl -fsSL "https://repo1.maven.org/maven2/org/wiremock/wiremock-standalone/${WIREMOCK_VERSION}/wiremock-standalone-${WIREMOCK_VERSION}.jar" \
    -o "$WIREMOCK_JAR"
fi

note=""
if [ -n "$held" ]; then
  echo "toolchain: not downloading the $held" >&2
  elv2_explain toolchain
  note=" (APOLLO_ELV2_LICENSE not set to accept)"
fi
echo "toolchain: rover $ROVER_VERSION, $plugin, $router, wiremock $WIREMOCK_VERSION ready$note"
