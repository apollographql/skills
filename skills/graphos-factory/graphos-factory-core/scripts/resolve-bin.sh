# shellcheck shell=bash
# resolve-bin.sh — which product binary a wrapper runs, and whether it is
# new enough. Sourced (never executed) by compose.sh, unit.sh, e2e.sh,
# live.sh and export.sh; sets RC to the binary's path.
#
# Resolution order: $GRAPHOS_FACTORY_CORE_BIN, then the graphos-factory-core link
# bootstrap.sh installs beside the product binary in its cache
# ($GRAPHOS_FACTORY_CORE_CACHE/bin, default
# ~/.cache/graphos-factory-core/<owner>-<repo>/bin, see cache.sh), then
# graphos-factory-core on PATH. The first hit is used — and the cache wins over
# PATH, so a binary a long-ago bootstrap left there shadows a newer one on
# PATH. That is why the version is checked here and never assumed.
#
# The expected version is the one bootstrap.sh installs: $GRAPHOS_FACTORY_CORE_VERSION
# when set, else crate/Cargo.toml's `version` in the checkout that holds these
# scripts, else the `version` of the release.env beside scripts/ (a copy of
# the core installed inside a skill; cache.sh reads both). A binary reporting an OLDER version is refused; a newer one (the
# edge pre-release is built from main's head) is accepted. Either way the path
# and version go to stderr, so a log always says which binary produced it.
# With no pin to read (no crate/ or release.env beside the scripts and no
# GRAPHOS_FACTORY_CORE_VERSION)
# the binary is used with a warning — never silently.
#
# Exit codes: 127 no binary found · 78 the binary is older than the pin, or
# does not report a version at all. 78 is neither 0, 3 nor 127, so `evidence`
# records the layer as `fail` — never `skipped`, never `pass`.
# Bash 3.2 compatible (macOS /bin/bash).

_sf_layer="$(basename "$0" .sh)"
_sf_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=SCRIPTDIR/cache.sh
. "$_sf_here/cache.sh"
_sf_cache="$GRAPHOS_FACTORY_CORE_CACHE_DIR"

RC="${GRAPHOS_FACTORY_CORE_BIN:-}"
_sf_from=GRAPHOS_FACTORY_CORE_BIN
if [ -z "$RC" ] && [ -x "$_sf_cache/bin/graphos-factory-core" ]; then
  RC="$_sf_cache/bin/graphos-factory-core"; _sf_from="the bootstrap cache"
fi
if [ -z "$RC" ]; then
  RC="$(command -v graphos-factory-core || true)"; _sf_from="PATH"
fi
if [ -z "$RC" ]; then
  echo "$_sf_layer: the product binary is not installed (no graphos-factory-core link in the cache or on PATH) — run your skill's scripts/bootstrap.sh" >&2
  exit 127
fi

_sf_want="${GRAPHOS_FACTORY_CORE_VERSION:-}"
_sf_pin_from=GRAPHOS_FACTORY_CORE_VERSION
# Else cache.sh's pin: crate/Cargo.toml in a checkout, release.env in a copy.
if [ -z "$_sf_want" ] && [ -n "$GRAPHOS_FACTORY_CORE_PIN" ]; then
  _sf_want="$GRAPHOS_FACTORY_CORE_PIN"
  _sf_pin_from="$GRAPHOS_FACTORY_CORE_PIN_FROM"
fi
_sf_have="$("$RC" version 2>/dev/null | sed -n 's/^[a-z][a-z0-9-]* \([0-9][^ ]*\).*/\1/p' | head -1 || true)"

_sf_refuse() {
  echo "$_sf_layer: FAIL — $1" >&2
  echo "$_sf_layer:   rebuild the cache with scripts/bootstrap.sh --build (or bootstrap.sh to download), or point GRAPHOS_FACTORY_CORE_BIN at a current binary" >&2
  exit 78
}

# 0 when version $1 is older than $2, 1 when not, 2 when either is unreadable.
# Pre-release and build suffixes (-edge, +sha) are ignored.
_sf_older() {
  local _sf_va _sf_vb _sf_i _sf_x _sf_y
  IFS=. read -r -a _sf_va <<< "${1%%[-+]*}"
  IFS=. read -r -a _sf_vb <<< "${2%%[-+]*}"
  for _sf_i in 0 1 2; do
    _sf_x="${_sf_va[$_sf_i]:-0}"; _sf_y="${_sf_vb[$_sf_i]:-0}"
    case "$_sf_x$_sf_y" in *[!0-9]*) return 2 ;; esac
    if [ "$((10#$_sf_x))" -lt "$((10#$_sf_y))" ]; then return 0; fi
    if [ "$((10#$_sf_x))" -gt "$((10#$_sf_y))" ]; then return 1; fi
  done
  return 1
}

if [ -z "$_sf_have" ]; then
  _sf_refuse "$RC (from $_sf_from) does not report a version (\`$RC version\` printed nothing usable)"
fi
if [ -z "$_sf_want" ]; then
  echo "graphos-factory-core: $_sf_layer runs $RC (from $_sf_from), version $_sf_have — WARNING: no pin to check it against (no crate/Cargo.toml or release.env beside the scripts, GRAPHOS_FACTORY_CORE_VERSION unset)" >&2
else
  _sf_cmp=0; _sf_older "$_sf_have" "$_sf_want" || _sf_cmp=$?
  case "$_sf_cmp" in
    0) _sf_refuse "$RC (from $_sf_from) is version $_sf_have, older than the $_sf_want these scripts expect ($_sf_pin_from)" ;;
    2) _sf_refuse "cannot compare $RC's version '$_sf_have' with the expected '$_sf_want' ($_sf_pin_from)" ;;
  esac
  echo "graphos-factory-core: $_sf_layer runs $RC (from $_sf_from), version $_sf_have (expected >= $_sf_want)" >&2
fi
unset -f _sf_older _sf_refuse
