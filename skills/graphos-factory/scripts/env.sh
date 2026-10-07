# shellcheck shell=bash
# env.sh — put graphos-factory, its graphos-factory-core link and rover on
# PATH, point GRAPHOS_FACTORY_CORE_SCRIPTS at the wrapper scripts and
# GRAPHOS_FACTORY_TARGET_SCRIPTS at this directory (supergraph-check.sh), for
# the shell that sources it.
#
#   . path/to/skills/graphos-factory/scripts/env.sh
#
# For any agent or terminal without the Claude Code plugin's SessionStart
# hook, which writes the same lines into the session's environment. A
# shell that keeps no state between commands sources it at the start of each
# one. It installs nothing: run scripts/bootstrap.sh once first. It finds
# the core the way bootstrap.sh does: inside this skill, else at the root of
# the checkout that holds skills/. Bash or zsh.
_gf_here="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
_gf_core=""
for _gf_c in "$_gf_here/../graphos-factory-core" "$_gf_here/../../../graphos-factory-core"; do
  if [ -f "$_gf_c/scripts/cache.sh" ]; then _gf_core="$(cd "$_gf_c" && pwd)"; break; fi
done
if [ -z "$_gf_core" ]; then
  echo "env.sh: no graphos-factory-core/scripts in $_gf_here/.. or at the checkout root" >&2
else
  # cache.sh locates itself through BASH_SOURCE, so it runs in bash even
  # when this file is sourced by zsh (macOS's default shell).
  # shellcheck disable=SC2016 # expanded by the inner bash
  _gf_bin="$(bash -c '. "$1/scripts/cache.sh" && printf "%s" "$GRAPHOS_FACTORY_CORE_CACHE_DIR/bin"' env.sh "$_gf_core")"
  export GRAPHOS_FACTORY_CORE_SCRIPTS="$_gf_core/scripts"
  export GRAPHOS_FACTORY_TARGET_SCRIPTS="$_gf_here"
  export PATH="$HOME/.rover/bin:$_gf_bin:$PATH"
  if ! [ -x "$_gf_bin/graphos-factory" ]; then
    echo "env.sh: graphos-factory is not installed yet; run: bash \"$_gf_here/bootstrap.sh\"" >&2
  fi
fi
unset _gf_here _gf_core _gf_c _gf_bin
