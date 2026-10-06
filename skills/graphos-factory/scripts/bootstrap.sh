#!/usr/bin/env bash
# bootstrap.sh — install the graphos-factory binary, and the
# graphos-factory-core link beside it, through the core's bootstrap.sh.
#
#   bootstrap.sh            # download the release binary
#   bootstrap.sh --build    # build it from crate/ with cargo (in a checkout)
#   bootstrap.sh --check    # exit 0 if the pinned version is installed
#
# It names the product (GRAPHOS_FACTORY_CORE_BIN_NAME=graphos-factory) and
# runs the core's bootstrap.sh, which documents the channels, the cache and
# the exit codes. The core is the graphos-factory-core/ directory inside this
# skill when the skill was installed on its own (npx skills, gh skill), else
# the one at the root of the checkout that holds skills/; --build always uses
# the checkout's, the one with crate/ above it. After an install it
# prints how to put the binary on PATH: `. scripts/env.sh` does it.
set -euo pipefail
export GRAPHOS_FACTORY_CORE_BIN_NAME=graphos-factory
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cores=("$HERE/../graphos-factory-core" "$HERE/../../../graphos-factory-core")
# A build needs crate/, which only the checkout root's core sits under.
case " $* " in *" --build "*) cores=("$HERE/../../../graphos-factory-core") ;; esac
for core in "${cores[@]}"; do
  if [ -f "$core/scripts/bootstrap.sh" ]; then
    rc=0
    bash "$core/scripts/bootstrap.sh" "$@" || rc=$?
    case " $* " in
      *" --check "*|*" -h "*|*" --help "*) ;;
      *) [ "$rc" -ne 0 ] || echo "  or, in each shell: . \"$HERE/env.sh\"" ;;
    esac
    exit "$rc"
  fi
done
echo "bootstrap: no graphos-factory-core/scripts/bootstrap.sh in $HERE/.. or at the checkout root" >&2
exit 127
