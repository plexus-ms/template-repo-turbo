#!/bin/sh
# A newborn repo passes its own lint and the contracts' checks: the template is
# rendered as copier would render it for a new repo, birth tasks included, and
# the generated repo's own `mise run lint` and its pinned `plx doctor` are run
# in it. Nothing else reads the template's files the way a consumer's tools do,
# so a file the formatter rejects would otherwise ship and fail the lint of
# every repo that takes the version (0.120.0's turbo.json).
#
# Both shapes of the template are rendered: an app repo, and a package repo
# (`publishes_packages`). The working tree is what is rendered, uncommitted
# changes included.
#
#   tests/newborn.sh           # render both shapes, lint and doctor them
#   KEEP=1 tests/newborn.sh    # leave the rendered repos in place and say where, even on failure
set -eu

# git runs a hook with GIT_DIR (and GIT_WORK_TREE) pointing at the pushing repository. Left set,
# the newborn's `git init` and copier's clones act on that repository instead of the scratch
# directory: from a linked worktree `git init` marks the shared repository bare.
# shellcheck disable=SC2046
unset $(git rev-parse --local-env-vars)

here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/newborn.XXXXXX")
if [ -n "${KEEP:-}" ]; then trap 'echo "kept: $tmp"' EXIT; else trap 'rm -rf "$tmp"' EXIT; fi

newborn() {
  name=$1
  shift
  echo "→ $name: render"
  copier copy --quiet --defaults --trust --vcs-ref HEAD -d tenant=acme "$@" "$here" "$tmp/$name"
  # A tool mise builds through uv (uv, and a `pipx:`/`pypi:` key or `uvx = true`) needs python
  # pinned: mise's Python keeps the uv tools' environments inside the cached data directory.
  python3 - "$tmp/$name/mise.toml" "$name" <<'EOF'
import sys, tomllib
tools = tomllib.load(open(sys.argv[1], "rb")).get("tools", {})
built = [k for k, v in tools.items() if k.startswith(("pipx:", "pypi:")) or (isinstance(v, dict) and str(v.get("uvx")).lower() == "true")]
if "uv" in tools and built and "python" not in tools:
    sys.exit(f"✗ {sys.argv[2]}: mise.toml builds {', '.join(built)} through uv but pins no python")
EOF
  echo "→ $name: lint"
  (cd "$tmp/$name" && mise run lint)
  echo "→ $name: doctor"
  (cd "$tmp/$name" && mise exec -- plx doctor)
  echo "✓ $name"
}

newborn app
newborn packages -d publishes_packages=true
