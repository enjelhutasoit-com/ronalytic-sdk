#!/usr/bin/env bash
# Writes (default) or checks (--check) the public macOS API baseline in API/.
set -euo pipefail

MODULES=(RonalyticCore RonalyticLifecycle RonalyticFileStorage RonalyticHTTP RonalyticTestSupport)
MODE="${1:-update}"
if [[ $# -gt 1 || ( "$MODE" != "update" && "$MODE" != "--check" ) ]]; then
  echo "Usage: $0 [--check]" >&2
  exit 2
fi

cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Use an isolated library build; never extract generated SwiftPM test modules.
SWIFT_BUILD=(swift build --scratch-path "$WORK/build")
"${SWIFT_BUILD[@]}" >&2
BIN_PATH=$("${SWIFT_BUILD[@]}" --show-bin-path)
TARGET=$(swift -print-target-info | jq -er '.target.triple | strings | select(length > 0)')
SDK_ARGS=()
if [[ "$(uname -s)" == Darwin ]]; then
  SDK_PATH=$(xcrun --sdk macosx --show-sdk-path)
  PLATFORM_PATH=$(xcrun --sdk macosx --show-sdk-platform-path)
  FRAMEWORKS_PATH="$PLATFORM_PATH/Developer/Library/Frameworks"
  # XCTest is an Xcode developer framework, not part of the macOS SDK.
  if [[ ! -d "$FRAMEWORKS_PATH/XCTest.framework" ]]; then
    echo "XCTest.framework not found in $FRAMEWORKS_PATH; select a full Xcode installation" >&2
    exit 1
  fi
  SDK_ARGS=(-sdk "$SDK_PATH" -F "$FRAMEWORKS_PATH")
fi

for module in "${MODULES[@]}"; do
  GRAPH_DIR="$WORK/$module"
  mkdir -p "$GRAPH_DIR"
  echo "Extracting public API for $module" >&2
  # Match SwiftPM's symbol graph settings but scope extraction to one module.
  swift symbolgraph-extract \
    -module-name "$module" \
    -target "$TARGET" \
    ${SDK_ARGS[@]+"${SDK_ARGS[@]}"} \
    -I "$BIN_PATH/Modules" \
    -output-dir "$GRAPH_DIR" \
    -minimum-access-level public \
    -skip-synthesized-members \
    -omit-extension-block-symbols

  MAIN_GRAPH="$GRAPH_DIR/$module.symbols.json"
  if [[ ! -s "$MAIN_GRAPH" ]]; then
    echo "Missing symbol graph for $module" >&2
    exit 1
  fi

  # Include extension graphs (e.g. Module@Swift.symbols.json) as before.
  shopt -s nullglob
  GRAPHS=("$MAIN_GRAPH" "$GRAPH_DIR/$module"@*.symbols.json)
  shopt -u nullglob
  for graph in "${GRAPHS[@]}"; do
    jq -e '.symbols | type == "array"' "$graph" > /dev/null
  done
  jq -r '
    .symbols[]
    | select(.accessLevel == "public" or .accessLevel == "open")
    | "\(.pathComponents | join(".")) :: \(.kind.identifier) :: \(.declarationFragments | map(.spelling) | join(""))"
  ' "${GRAPHS[@]}" | LC_ALL=C sort -u > "$WORK/$module.txt"

  if [[ ! -s "$WORK/$module.txt" ]]; then
    echo "No public API symbols extracted for $module" >&2
    exit 1
  fi
done

# Only compare or update baselines after all extractions succeed.
status=0
for module in "${MODULES[@]}"; do
  if [[ "$MODE" == "--check" ]]; then
    if ! diff -u "API/$module.txt" "$WORK/$module.txt"; then
      status=1
    fi
  else
    mkdir -p API
    cp "$WORK/$module.txt" "API/$module.txt"
  fi
done

if [[ "$status" -ne 0 ]]; then
  echo "Public API changed. If this is intended, run Scripts/api-dump.sh and commit API/." >&2
fi
exit "$status"
