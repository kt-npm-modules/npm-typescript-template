#!/bin/bash

# Optionally link locally-developed packages into node_modules after install.
#
# This script links a package iff ALL THREE are true:
#   1. The package name appears in LINK_PACKAGES below.
#   2. The package is a direct entry of dependencies/devDependencies in
#      package.json (no transitive walk).
#   3. The package is currently registered as a global npm link
#      (`npm ls -g --depth=0 --link=true`).
#
# When nothing matches (e.g. on CI runners with no global links, or on a
# developer machine that has not run `npm link` in the package's repo),
# the script exits 0 without invoking `npm link`. This is the safety
# mechanism — no separate $CI guard is required.

set -eu

LINK_PACKAGES=(
)

separator="------------------------------------------"

if [ ${#LINK_PACKAGES[@]} -eq 0 ]; then
  echo "LINK_PACKAGES is empty — nothing to link."
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to run this script. Skipping link step."
  exit 0
fi

# Direct deps + devDeps of THIS project (no transitive walk).
direct_deps=$(
  jq -r '((.dependencies // {}) + (.devDependencies // {})) | keys[]' package.json
)

# Globally available npm links — clean JSON parse, no awk/sed acrobatics.
global_linked=$(
  npm ls -g --depth=0 --link=true --json 2>/dev/null \
    | jq -r '.dependencies // {} | keys[]'
)

echo -e "Globally linked packages:\n${separator}\n${global_linked:-<none>}\n${separator}\n"

# Triple intersection: declared ∩ direct deps ∩ globally linked.
to_link=()
for pkg in "${LINK_PACKAGES[@]}"; do
  printf '%s\n' "$direct_deps"   | grep -qxF "$pkg" || continue
  printf '%s\n' "$global_linked" | grep -qxF "$pkg" || continue
  to_link+=("$pkg")
done

if [ ${#to_link[@]} -eq 0 ]; then
  echo "No packages to link."
  exit 0
fi

echo -e "Packages to link:\n${separator}\n${to_link[*]}\n${separator}\n"
npm link "${to_link[@]}"
echo -e "\033[1;33mWarning: You may need to make sure that the linked packages are released and up to date.\033[0m"
echo -e "\033[1;33mWarning: While the checks may work locally, they may fail on CI/CD if the linked packages are not released and up to date.\033[0m"
