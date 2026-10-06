# shellcheck shell=bash
# cache.sh — where this checkout's product binary and toolchain are cached.
# Sourced (never executed) by bootstrap.sh, toolchain.sh, resolve-bin.sh,
# e2e.sh and live.sh; sets GRAPHOS_FACTORY_CORE_RELEASE_REPO and
# GRAPHOS_FACTORY_CORE_CACHE_DIR.
#
#   GRAPHOS_FACTORY_CORE_RELEASE_REPO  $GRAPHOS_FACTORY_CORE_RELEASE_REPO, else
#                                 crate/Cargo.toml's `repository` (owner/repo
#                                 on GitHub), else release.env's
#                                 `repository`: the releases bootstrap.sh
#                                 downloads from
#   GRAPHOS_FACTORY_CORE_PIN       the version bootstrap.sh installs and
#                                 resolve-bin.sh checks: crate/Cargo.toml's
#                                 `version`, else release.env's `version`,
#                                 else empty ($GRAPHOS_FACTORY_CORE_VERSION,
#                                 read by those scripts, overrides it)
#   GRAPHOS_FACTORY_CORE_PIN_FROM  where the pin was read: crate/Cargo.toml,
#                                 release.env or empty
#   GRAPHOS_FACTORY_CORE_RELEASE_TAG  $GRAPHOS_FACTORY_CORE_RELEASE_TAG, else
#                                 release.env's `tag` (the release of the
#                                 product this copy ships with, which carries
#                                 the binary it pins), else empty: bootstrap.sh
#                                 then uses v<pin>
#
# crate/Cargo.toml is looked for two levels above this directory, where a
# checkout keeps it. A copy of the core that travels inside an installed
# skill (a skill directory copied on its own, with no crate/ above it)
# carries release.env beside scripts/ instead: `version=X.Y.Z` (the binary),
# `repository=owner/repo` and `tag=vA.B.C` (the product release) lines,
# written when the copy was made. It is read, never sourced.
#   GRAPHOS_FACTORY_CORE_CACHE_DIR     $GRAPHOS_FACTORY_CORE_CACHE, else
#                                 ~/.cache/graphos-factory-core/<owner>-<repo>, so
#                                 two products' builds never overwrite each
#                                 other
#
# Its bin/ holds the product binary bootstrap.sh installed and
# `graphos-factory-core`, a link to it.
# Bash 3.2 compatible (macOS /bin/bash).

_fc_here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# The repository root: these scripts live in graphos-factory-core/scripts/.
_fc_root="$(cd "$_fc_here/../.." && pwd)"
_fc_release="$_fc_here/../release.env"
# shellcheck disable=SC2034 # the pin is read by the scripts that source this one
_fc_repo="" _fc_tag="" GRAPHOS_FACTORY_CORE_PIN="" GRAPHOS_FACTORY_CORE_PIN_FROM=""
# shellcheck disable=SC2034
if [ -f "$_fc_root/crate/Cargo.toml" ]; then
  _fc_repo="$(sed -n 's#^repository = "https://github.com/\([^"]*\)".*#\1#p' "$_fc_root/crate/Cargo.toml" | head -1)"
  GRAPHOS_FACTORY_CORE_PIN="$(sed -n 's/^version = "\([^"]*\)".*/\1/p' "$_fc_root/crate/Cargo.toml" | head -1)"
  [ -z "$GRAPHOS_FACTORY_CORE_PIN" ] || GRAPHOS_FACTORY_CORE_PIN_FROM=crate/Cargo.toml
elif [ -f "$_fc_release" ]; then
  _fc_tag="$(sed -n 's/^tag=\([0-9A-Za-z.+_-]*\)$/\1/p' "$_fc_release" | head -1)"
  _fc_repo="$(sed -n 's#^repository=\([A-Za-z0-9._-]*/[A-Za-z0-9._-]*\)$#\1#p' "$_fc_release" | head -1)"
  GRAPHOS_FACTORY_CORE_PIN="$(sed -n 's/^version=\([0-9A-Za-z.+-]*\)$/\1/p' "$_fc_release" | head -1)"
  [ -z "$GRAPHOS_FACTORY_CORE_PIN" ] || GRAPHOS_FACTORY_CORE_PIN_FROM=release.env
fi
GRAPHOS_FACTORY_CORE_RELEASE_REPO="${GRAPHOS_FACTORY_CORE_RELEASE_REPO:-$_fc_repo}"
# shellcheck disable=SC2034 # read by bootstrap.sh
GRAPHOS_FACTORY_CORE_RELEASE_TAG="${GRAPHOS_FACTORY_CORE_RELEASE_TAG:-$_fc_tag}"
_fc_slug="${GRAPHOS_FACTORY_CORE_RELEASE_REPO:-local}"
# shellcheck disable=SC2034 # read by the scripts that source this one
GRAPHOS_FACTORY_CORE_CACHE_DIR="${GRAPHOS_FACTORY_CORE_CACHE:-$HOME/.cache/graphos-factory-core/${_fc_slug//\//-}}"
unset _fc_here _fc_root _fc_release _fc_repo _fc_tag _fc_slug
