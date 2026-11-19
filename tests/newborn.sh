#!/bin/sh
# A newborn repo passes its own lint and its pinned `plx doctor`: the working tree, uncommitted
# changes included, is rendered with its birth tasks as an app repo and as a package repo, each also with the
# tenant's private packages.
#
#   tests/newborn.sh           # render both shapes, lint and doctor them
#   KEEP=1 tests/newborn.sh    # leave the rendered repos in place and say where, even on failure
set -eu

# Left set by a hook, GIT_DIR and GIT_WORK_TREE would point the newborn's `git init` and copier's
# clones at the pushing repository: from a linked worktree, `git init` marks it bare.
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
newborn private-app -d private_packages_scope=@acme
newborn private-packages -d publishes_packages=true -d package_registry=github -d private_packages_scope=@acme
