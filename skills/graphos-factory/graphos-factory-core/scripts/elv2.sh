# shellcheck shell=bash
# elv2.sh — the Elastic License v2 gate. Sourced (never executed) by
# compose.sh, unit.sh, e2e.sh and live.sh before their first rover call that
# needs the supergraph composition plugin (and before e2e.sh downloads or
# live.sh runs the Apollo Router), and by toolchain.sh before it installs
# the plugin or downloads the Router.
#
# rover's supergraph composition plugin, which `rover supergraph compose`
# and `rover connector test` download and run, and the Apollo Router are
# licensed under the Elastic License v2. Accepting it is the user's act: read the licence,
# then set APOLLO_ELV2_LICENSE=accept in the environment. rover reads that
# variable itself (it is the environment form of `--elv2-license accept`), so
# these scripts never set it, never pass the flag, and never accept on the
# user's behalf.
#
#   elv2_accepted        0 when APOLLO_ELV2_LICENSE is `accept`, 1 otherwise
#   elv2_explain PREFIX [SUFFIX]  the instruction, on stderr, each line led
#                        by PREFIX; SUFFIX ends the first line
#   elv2_require LAYER   elv2_accepted, or elv2_explain and exit 3
#
# Exit 3 is `not_run`: `evidence` records the layer as `not_run`, its reason
# the first line below, never `pass` and never `fail`. The tool is present,
# so this is not the 127 `skipped`; what is missing is the user's own
# acceptance, the way a missing credential leaves the live layer `not_run`.
# Bash 3.2 compatible (macOS /bin/bash).

ELV2_URL="https://www.elastic.co/licensing/elastic-license"

elv2_accepted() {
  [ "${APOLLO_ELV2_LICENSE:-}" = accept ]
}

elv2_explain() {
  {
    echo "$1: APOLLO_ELV2_LICENSE is not set to accept, and only you can accept the Elastic License v2${2:-}"
    echo "$1:   rover's supergraph composition plugin, which \`rover supergraph compose\` downloads, and the Apollo Router, which e2e and live run, are licensed under the Elastic License v2: $ELV2_URL"
    echo "$1:   read it, then set \`APOLLO_ELV2_LICENSE=accept\` (rover reads the variable itself); these scripts never set it on their own, and an agent sets it only after you say yes"
    echo "$1:   until it is set, the compose, unit, e2e and live layers report not_run"
  } >&2
}

elv2_require() {
  elv2_accepted && return 0
  elv2_explain "$1" " (not_run)"
  exit 3
}
