#!/bin/sh
# The newborn test is immune to git's hook environment. git runs a hook with GIT_DIR and
# GIT_WORK_TREE set to the pushing repository, and a `git init` that inherits them rewrites that
# repository's config (core.bare, core.worktree). This runs tests/newborn.sh with both pointing at
# a decoy repository, as a hook would, and fails if the decoy's config changed.
set -eu

# This script runs from a hook too: its own `git init` must not see the real hook's variables.
# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars)

here=$(cd "$(dirname "$0")" && pwd)
decoy=$(mktemp -d "${TMPDIR:-/tmp}/newborn.XXXXXX")
trap 'rm -rf "$decoy"' EXIT
git init --quiet "$decoy"
before=$(cat "$decoy/.git/config")

GIT_DIR="$decoy/.git" GIT_WORK_TREE="$decoy" "$here/newborn.sh"

[ "$before" = "$(cat "$decoy/.git/config")" ] || {
  echo "newborn.sh changed the config of the repository git's hook environment pointed at:" >&2
  cat "$decoy/.git/config" >&2
  exit 1
}
