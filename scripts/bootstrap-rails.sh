#!/usr/bin/env bash
# Bootstrap propitech Rails CI in the current (or specified) consumer repo.
#
# Usage:
#   bash <(curl -sSL https://raw.githubusercontent.com/propitech/medusa/v1/scripts/bootstrap-rails.sh)
#
# Options (env vars):
#   VERSION    medusa tag/branch to fetch from (default: v1)
#   TARGET     target repo root (default: current directory)
#   FORCE=1    overwrite existing files
#   DRY_RUN=1  show what would be fetched without writing

set -euo pipefail

VERSION="${VERSION:-v1}"
TARGET="${TARGET:-.}"
FORCE="${FORCE:-0}"
DRY_RUN="${DRY_RUN:-0}"

BASE="https://raw.githubusercontent.com/propitech/medusa/${VERSION}"

cd "$TARGET"

fetch() {
  local src="$1" dest="$2"
  if [[ -e "$dest" && "$FORCE" != "1" ]]; then
    echo "skip (exists): $dest"
    return
  fi
  mkdir -p "$(dirname "$dest")"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "would fetch: $src -> $dest"
  else
    curl -sSL --fail "$src" -o "$dest"
    echo "wrote:       $dest"
  fi
}

echo "Bootstrapping propitech Rails CI from medusa@${VERSION} into $(pwd)"
echo

fetch "$BASE/templates/ruby-rails/workflows/ci.yml"      ".github/workflows/ci.yml"
fetch "$BASE/templates/common/workflows/stale.yml"       ".github/workflows/stale.yml"
fetch "$BASE/templates/ruby-rails/dependabot.yml"        ".github/dependabot.yml"
fetch "$BASE/templates/common/pull_request_template.md"  ".github/pull_request_template.md"
fetch "$BASE/templates/common/CODEOWNERS"                ".github/CODEOWNERS"

cat <<'EOF'

Bootstrap complete.

Next steps:
  1. Set repo secret CODECOV_TOKEN (Settings -> Secrets and variables -> Actions).
  2. Optional: set QLTY_COVERAGE_TOKEN for Quality.sh coverage upload.
  3. Commit .github/ and open a PR; CI runs on push.
EOF
