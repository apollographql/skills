#!/usr/bin/env bash
# bootstrap.sh — put a product binary in place, and the graphos-factory-core
# link beside it.
#
#   bootstrap.sh            # download the binary (the default for users)
#   bootstrap.sh --build    # build it from crate/ with cargo (for developing the skill)
#   bootstrap.sh --check    # exit 0 if a binary reporting the pinned version is installed, 127 if not
#
# Run through a skill's own scripts/bootstrap.sh, which sets
# GRAPHOS_FACTORY_CORE_BIN_NAME to its product's binary and execs this one;
# without the variable this script refuses (exit 1). The binary lands in
# $GRAPHOS_FACTORY_CORE_CACHE/bin/<name> (default
# ~/.cache/graphos-factory-core/<owner>-<repo>, see cache.sh), next to the router
# and WireMock the e2e layer caches, with bin/graphos-factory-core a symlink
# to it: the shared references write `graphos-factory-core <command>`, so a
# command copied from one runs whichever product installed it. Every wrapper
# script looks there first, then on PATH. The wrappers (resolve-bin.sh)
# refuse, with exit 78, a binary older than the version this script
# installs — so a cache left behind by an old bootstrap fails loudly instead
# of rendering silently. Nothing is ever written into the
# repository.
#
# Download channels (GitHub Releases of $GRAPHOS_FACTORY_CORE_RELEASE_REPO, by
# default the `repository` of crate/Cargo.toml, or of release.env in a copy):
#   release   tag <tag>, asset <name>-<tag>-<target>.tar.gz: cache.sh's
#             release tag (a product release, from release.env) or v<pin>.
#   edge      the rolling pre-release rebuilt from main on every push, asset
#             <name>-edge-<target>.tar.gz; re-downloaded whenever the
#             pre-release points at a new commit.
# GRAPHOS_FACTORY_CORE_CHANNEL=auto (default) uses that release when it
# exists and falls back to edge; `release` or `edge`
# force one. A GH_TOKEN / GITHUB_TOKEN is used when present (the repository
# may be private); without one the plain download URL is tried and, when it
# fails, the script says so and how to fix it.
#
# Exit codes: 0 installed · 1 usage error (GRAPHOS_FACTORY_CORE_BIN_NAME unset among them), or the binary just installed reports the wrong version · 127 could not install, or (--check) the pinned version is not installed.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
CRATE="$REPO_ROOT/crate"
# shellcheck source=SCRIPTDIR/cache.sh
. "$HERE/cache.sh"
NAME="${GRAPHOS_FACTORY_CORE_BIN_NAME:-}"
CACHE="$GRAPHOS_FACTORY_CORE_CACHE_DIR"
BIN_DIR="$CACHE/bin"
BIN="$BIN_DIR/$NAME"
# The shared name, a link to the product binary.
LINK="$BIN_DIR/graphos-factory-core"
EDGE_STAMP="$BIN_DIR/$NAME.edge-commit"
OWNER_REPO="$GRAPHOS_FACTORY_CORE_RELEASE_REPO"
CHANNEL="${GRAPHOS_FACTORY_CORE_CHANNEL:-auto}"
API="https://api.github.com/repos/$OWNER_REPO"

MODE="download"
for arg in "$@"; do
  case "$arg" in
    --build) MODE="build" ;;
    --check) MODE="check" ;;
    -h|--help) sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "bootstrap: unknown argument $arg" >&2; exit 1 ;;
  esac
done
case "$NAME" in
  "")
    echo "bootstrap: GRAPHOS_FACTORY_CORE_BIN_NAME is unset: run your skill's own bootstrap (skills/<skill>/scripts/bootstrap.sh), which names its binary and runs this one" >&2
    exit 1 ;;
  graphos-factory-core|*/*|*[!a-z0-9-]*)
    echo "bootstrap: GRAPHOS_FACTORY_CORE_BIN_NAME=$NAME is not a product binary's name" >&2
    exit 1 ;;
esac
case "$CHANNEL" in auto|release|edge) ;; *) echo "bootstrap: GRAPHOS_FACTORY_CORE_CHANNEL must be auto, release or edge" >&2; exit 1 ;; esac

VERSION="${GRAPHOS_FACTORY_CORE_VERSION:-$GRAPHOS_FACTORY_CORE_PIN}"
[ -n "$VERSION" ] || { echo "bootstrap: cannot determine the version (no $CRATE/Cargo.toml, no release.env beside $HERE and no GRAPHOS_FACTORY_CORE_VERSION)" >&2; exit 1; }

# The release that carries the pinned binary: a product release names its
# own tag in release.env; a checkout's binary is released as v<version>.
RELEASE_TAG="${GRAPHOS_FACTORY_CORE_RELEASE_TAG:-v$VERSION}"

TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
# Every request is bounded, so a stalled connection cannot outlast a caller's
# own timeout: an API call or the HEAD probe 15 s, the archive 90 s, each with
# a 10 s connect timeout. A download makes at most three API calls and the
# archive, 135 s in all.
CURL_API=(--connect-timeout 10 --max-time 15)
CURL_GET=(--connect-timeout 10 --max-time 90)

installed_version() {
  if [ -x "$BIN" ]; then "$BIN" version 2>/dev/null | sed -n 's/^[a-z][a-z0-9-]* \([0-9][^ ]*\).*/\1/p'; fi
  true
}

# GET a releases-API path with the token; empty output when it fails.
api() {
  [ -n "$TOKEN" ] || return 1
  curl -fsSL "${CURL_API[@]}" -H "Authorization: Bearer $TOKEN" -H "Accept: application/vnd.github+json" "$API/$1" 2>/dev/null
}

if [ "$MODE" = "check" ]; then
  if [ "$(installed_version)" = "$VERSION" ]; then
    echo "$NAME $VERSION already installed at $BIN"
    exit 0
  fi
  echo "$NAME $VERSION is not installed (found: $(installed_version))" >&2
  exit 127
fi

mkdir -p "$BIN_DIR"

build() {
  if ! command -v cargo >/dev/null 2>&1; then
    echo "bootstrap: --build needs cargo (https://rustup.rs); or run without --build to download the release" >&2
    return 127
  fi
  echo "bootstrap: building $NAME $VERSION from $CRATE"
  cargo build --release --locked --manifest-path "$CRATE/Cargo.toml" --bin "$NAME" --quiet
  install -m 0755 "$CRATE/target/release/$NAME" "$BIN"
  rm -f "$EDGE_STAMP"
}

# Which release tag to install from, given the channel and what exists.
resolve_tag() {
  case "$CHANNEL" in
    release) echo "$RELEASE_TAG" ;;
    edge) echo edge ;;
    auto)
      if [ -n "$TOKEN" ]; then
        if api "releases/tags/$RELEASE_TAG" >/dev/null; then echo "$RELEASE_TAG"; else echo edge; fi
      else
        # No API access: probe the public download URL for the versioned asset.
        if curl -fsSLI "${CURL_API[@]}" -o /dev/null "https://github.com/$OWNER_REPO/releases/download/$RELEASE_TAG/$NAME-$RELEASE_TAG-$1.tar.gz" 2>/dev/null; then echo "$RELEASE_TAG"; else echo edge; fi
      fi ;;
  esac
}

download() {
  local target tmp asset url tag release
  [ -n "$OWNER_REPO" ] || { echo "bootstrap: no release repository: set GRAPHOS_FACTORY_CORE_RELEASE_REPO=owner/repo (neither crate/Cargo.toml nor release.env names one)" >&2; return 1; }
  case "$(uname -s)-$(uname -m)" in
    Linux-x86_64)   target="x86_64-unknown-linux-musl" ;;
    Linux-aarch64)  target="aarch64-unknown-linux-musl" ;;
    Darwin-arm64)   target="aarch64-apple-darwin" ;;
    Darwin-x86_64)  target="x86_64-apple-darwin" ;;
    *) echo "bootstrap: no release binary for $(uname -s)-$(uname -m); run with --build" >&2; return 127 ;;
  esac
  tag="$(resolve_tag "$target")"
  asset="${NAME}-${tag}-${target}.tar.gz"

  # Already current?
  if [ "$tag" != edge ] && [ "$(installed_version)" = "$VERSION" ] && [ ! -f "$EDGE_STAMP" ]; then
    echo "$NAME $VERSION already installed at $BIN"
    return 0
  fi
  release="$(api "releases/tags/$tag" || true)"
  # The commit the edge tag points at: the tag ref is authoritative (a
  # release's target_commitish can be a branch name), fall back to it.
  local edge_sha=""
  if [ "$tag" = edge ] && [ -n "$TOKEN" ]; then
    edge_sha="$(api "git/ref/tags/edge" | jq -r '.object.sha // empty' 2>/dev/null || true)"
    [ -n "$edge_sha" ] || edge_sha="$(printf '%s' "$release" | jq -r '.target_commitish // empty' 2>/dev/null || true)"
  fi
  if [ "$tag" = edge ] && [ -n "$edge_sha" ] && [ -f "$EDGE_STAMP" ] && [ -x "$BIN" ]; then
    local current="$edge_sha"
    if [ "$current" = "$(cat "$EDGE_STAMP")" ]; then
      echo "$NAME edge build ${current:0:7} already installed at $BIN"
      return 0
    fi
  fi

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  if [ -n "$TOKEN" ]; then
    # Private repository: resolve the asset id through the API.
    if [ -z "$release" ]; then
      echo "bootstrap: no release $tag at https://github.com/$OWNER_REPO/releases (token was used)" >&2
      return 127
    fi
    local id
    id="$(printf '%s' "$release" | jq -r --arg n "$asset" '.assets[] | select(.name == $n) | .id')"
    if [ -z "$id" ] || [ "$id" = "null" ]; then echo "bootstrap: release $tag has no asset $asset (still building?)" >&2; return 127; fi
    curl -fsSL "${CURL_GET[@]}" -H "Authorization: Bearer $TOKEN" -H "Accept: application/octet-stream" \
      "$API/releases/assets/$id" -o "$tmp/$asset" \
      || { echo "bootstrap: download of $asset failed" >&2; return 127; }
  else
    url="https://github.com/$OWNER_REPO/releases/download/$tag"
    if ! curl -fsSL "${CURL_GET[@]}" "$url/$asset" -o "$tmp/$asset"; then
      cat >&2 <<EOF
bootstrap: could not download $url/$asset
  The repository is private: export GH_TOKEN (a token with read access to $OWNER_REPO) and re-run,
  or build from source with:  $0 --build   (needs cargo),
  or point GRAPHOS_FACTORY_CORE_BIN at a binary you already have.
EOF
      return 127
    fi
  fi

  tar xzf "$tmp/$asset" -C "$tmp" || { echo "bootstrap: $asset is not a valid archive (truncated download?)" >&2; return 1; }
  local extracted
  extracted="$(find "$tmp" -type f -name "$NAME" | head -1)"
  [ -n "$extracted" ] || { echo "bootstrap: archive $asset contains no $NAME binary" >&2; return 1; }
  install -m 0755 "$extracted" "$BIN"
  if [ "$tag" = edge ]; then
    printf '%s' "$edge_sha" > "$EDGE_STAMP"
    echo "bootstrap: installed $NAME ($target) from the edge pre-release$( [ -s "$EDGE_STAMP" ] && echo " at $(cut -c1-7 "$EDGE_STAMP")")"
  else
    rm -f "$EDGE_STAMP"
    echo "bootstrap: installed $NAME $VERSION ($target) from the $tag release"
  fi
  INSTALLED_TAG="$tag"
}

INSTALLED_TAG=""
case "$MODE" in
  build) build ;;
  download) download ;;
esac

if [ "$(installed_version)" != "$VERSION" ]; then
  if [ "$INSTALLED_TAG" = edge ]; then
    echo "bootstrap: note — the edge build reports $(installed_version); this checkout pins $VERSION (edge is built from main's head)" >&2
  else
    echo "bootstrap: $BIN reports '$(installed_version)', expected $VERSION" >&2
    exit 1
  fi
fi
# The shared name beside it, relative so the cache can move; a link left by
# the other product's bootstrap in the same cache is repointed.
ln -sfn "$NAME" "$LINK"
echo "$NAME $(installed_version) ready at $BIN (and graphos-factory-core, a link to it)"
echo "  add to PATH:  export PATH=\"$BIN_DIR:\$PATH\"   or   export GRAPHOS_FACTORY_CORE_BIN=$BIN"
