#!/usr/bin/env bash
# Writes (default) or checks (--check) the public API baseline in API/.
set -euo pipefail

MODULES=(RonalyticCore RonalyticLifecycle RonalyticFileStorage RonalyticHTTP RonalyticTestSupport)
MODE="${1:-update}"

cd "$(dirname "$0")/.."

# Remove old dumps, so a deleted module cannot leave stale files behind.
rm -rf .build/*/symbolgraph
swift package dump-symbol-graph --minimum-access-level public --skip-synthesized-members > /dev/null

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for module in "${MODULES[@]}"; do
  # One line per symbol: path :: kind :: declaration
  find .build -path '*/symbolgraph/*' -name "${module}*.symbols.json" -print0 \
    | xargs -0 -r jq -r '
        .symbols[]
        | select(.accessLevel == "public" or .accessLevel == "open")
        | "\(.pathComponents | join(".")) :: \(.kind.identifier) :: \(.declarationFragments | map(.spelling) | join(""))"
      ' \
    | LC_ALL=C sort -u > "$WORK/$module.txt" || true
done

status=0
for module in "${MODULES[@]}"; do
  if [ "$MODE" = "--check" ]; then
    if ! diff -u "API/$module.txt" "$WORK/$module.txt"; then
      status=1
    fi
  else
    mkdir -p API
    cp "$WORK/$module.txt" "API/$module.txt"
  fi
done

if [ "$status" -ne 0 ]; then
  echo "Public API changed. If this is intended, run Scripts/api-dump.sh and commit API/." >&2
fi
exit "$status"
