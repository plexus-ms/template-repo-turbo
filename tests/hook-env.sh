#!/bin/sh
# The newborn test is immune to git's hook environment: tests/newborn.sh runs with GIT_DIR and
# GIT_WORK_TREE pointing at a decoy repository, as a hook's would, and the decoy's config must not change.
#
#   tests/hook-env.sh
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
