# shellcheck shell=bash
# live-env.sh — the live layer's credentials file. Sourced by live.sh only.
#
# Live cases need real credentials (and sometimes a real <SERVICE>_BASE_URL),
# and every other layer must NOT see them. The unit render has ignored
# <SERVICE>_BASE_URL, but compose and e2e render with every
# override, so a real value exported into a whole `graphos-factory-core evidence`
# run would still change what those layers test. So the file is loaded here,
# inside the live.sh process, and nowhere else.
#
# Which file:
#   1. $GRAPHOS_FACTORY_CORE_LIVE_ENV, when set — it must exist;
#   2. otherwise the nearest `smoke.env`, from the workspace up to the top of
#      the git checkout it sits in (the workspace alone when it is not in git).
#      A shared monorepo keeps one gitignored smoke.env at its root for every
#      service. A git worktree has its own top: point GRAPHOS_FACTORY_CORE_LIVE_ENV
#      at the main checkout's file from there.
#
# Format: `NAME=value` lines. Blank lines and `#` comment lines are skipped, an
# `export ` prefix is allowed, and one pair of matching quotes around the value
# is removed. Nothing after the `=` is interpreted — the file is parsed, never
# sourced, so a value may contain `#`, `$` or spaces. A variable already set in
# the environment wins (CI secrets override a local file). Values are never
# printed; only the file path and the number of names loaded are.

# live_env_find WORKSPACE — print the file to load, or nothing. Exit 1 when
# $GRAPHOS_FACTORY_CORE_LIVE_ENV names a file that does not exist.
live_env_find() {
  local named="${GRAPHOS_FACTORY_CORE_LIVE_ENV:-}"
  if [ -n "$named" ]; then
    if [ ! -f "$named" ]; then
      echo "live: GRAPHOS_FACTORY_CORE_LIVE_ENV=$named is not a file" >&2
      return 1
    fi
    printf '%s\n' "$named"
    return 0
  fi
  local dir top
  dir="$(cd "$1" && pwd -P)" || return 1
  top="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] && top="$(cd "$top" && pwd -P)"
  while :; do
    if [ -f "$dir/smoke.env" ]; then
      printf '%s\n' "$dir/smoke.env"
      return 0
    fi
    { [ -z "$top" ] || [ "$dir" = "$top" ] || [ "$dir" = "/" ]; } && return 0
    dir="$(dirname "$dir")"
  done
}

# live_env_load WORKSPACE — export the file's variables into this process.
live_env_load() {
  local file line key value n=0 skipped=0
  file="$(live_env_find "$1")" || return 1
  [ -n "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="${line#"${line%%[![:space:]]*}"}"
    case "$line" in ''|'#'*) continue ;; esac
    line="${line#export }"
    case "$line" in *=*) ;; *) skipped=$((skipped + 1)); continue ;; esac
    key="${line%%=*}"
    value="${line#*=}"
    if ! [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then skipped=$((skipped + 1)); continue; fi
    if [ "${#value}" -ge 2 ]; then
      case "$value" in
        \"*\") value="${value:1:${#value}-2}" ;;
        \'*\') value="${value:1:${#value}-2}" ;;
      esac
    fi
    [ -n "${!key+x}" ] && continue
    export "$key=$value"
    n=$((n + 1))
  done < "$file"
  echo "live: loaded $n variable(s) from $file (values not shown)"
  [ "$skipped" -eq 0 ] || echo "live: skipped $skipped line(s) in $file that are not NAME=value" >&2
  return 0
}
