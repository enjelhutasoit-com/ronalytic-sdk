#!/usr/bin/env bash
# Prints the CHANGELOG section of one version. Fails when it is missing or empty.
set -euo pipefail

VERSION="${1:?usage: release-notes.sh <version, for example 1.0.0>}"
cd "$(dirname "$0")/.."

NOTES="$(awk -v version="$VERSION" '
  index($0, "## [" version "]") == 1 { found = 1; next }
  found && /^## \[/ { exit }
  found { print }
' CHANGELOG.md)"

if [ -z "$(printf '%s' "$NOTES" | tr -d '[:space:]')" ]; then
  echo "No changelog entry for $VERSION" >&2
  exit 1
fi

printf '%s\n' "$NOTES"
