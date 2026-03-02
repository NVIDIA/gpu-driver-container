#!/bin/bash
# Args: DIST LTS_KERNEL
# Env:  KERNEL_FLAVORS_JSON, DRIVER_BRANCHES_JSON, EXCLUDE_PAIRS_JSON, PLATFORMS_JSON
#
# Writes ./matrix_values_<DIST>_<LTS_KERNEL>[<PLATFORM_SUFFIX>].json for each
# platform that has at least one kernel version to test.
set -euo pipefail

DIST="$1"
LTS_KERNEL="$2"

mapfile -t KERNEL_FLAVORS < <(jq -r '.[]' <<<"$KERNEL_FLAVORS_JSON")
mapfile -t PLATFORMS < <(jq -r '.[]' <<<"$PLATFORMS_JSON")

DRIVER_BRANCHES=()
for branch in $(jq -r '.[]' <<<"$DRIVER_BRANCHES_JSON"); do
  if ! jq -e --arg dist "$DIST" --arg driver_branch "$branch" \
       'any(.[]; .dist == $dist and .driver_branch == $driver_branch)' \
       <<<"$EXCLUDE_PAIRS_JSON" >/dev/null; then
    DRIVER_BRANCHES+=("$branch")
  fi
done

source ./tests/scripts/ci-precompiled-helpers.sh

for PLATFORM in "${PLATFORMS[@]}"; do
  if [[ "$PLATFORM" == "arm64" && ( "$DIST" == "ubuntu22.04" || "$DIST" == "ubuntu26.04" ) ]]; then
    continue
  fi
  if [[ "$PLATFORM" == "arm64" ]]; then
    PLATFORM_SUFFIX="-arm64"
    # arm64 does not support azure-fde
    FLAVORS_FOR_PLATFORM=()
    for flavor in "${KERNEL_FLAVORS[@]}"; do
      if [[ "$flavor" != "azure-fde" ]]; then
        FLAVORS_FOR_PLATFORM+=("$flavor")
      fi
    done
  else
    PLATFORM_SUFFIX=""
    FLAVORS_FOR_PLATFORM=("${KERNEL_FLAVORS[@]}")
  fi
  KERNEL_VERSIONS=($(get_kernel_versions_to_test FLAVORS_FOR_PLATFORM[@] DRIVER_BRANCHES[@] "$DIST" "$LTS_KERNEL" "$PLATFORM_SUFFIX"))
  if [[ ${#KERNEL_VERSIONS[@]} -gt 0 ]]; then
    printf '%s\n' "${KERNEL_VERSIONS[@]}" | jq -R . | jq -s . \
      > "./matrix_values_${DIST}_${LTS_KERNEL}${PLATFORM_SUFFIX}.json"
  fi
done
