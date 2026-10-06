#!/usr/bin/env bash
# Copyright 2026 NVIDIA CORPORATION
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <output.tar> <arch=input.tar> [<arch=input.tar> ...]" >&2
  exit 2
fi
OUTPUT_ARCHIVE=$1
shift
REGCTL=${REGCTL:-regctl}
WORK_DIR=$(mktemp -d)
trap 'rm -rf "$WORK_DIR"' EXIT

REF_ARGS=()
PLATFORM_ARGS=()
EXPECTED_ARCHITECTURES=()
for SOURCE in "$@"; do
  [[ "$SOURCE" == *=* ]] || { echo "Expected <arch>=<archive>, got: $SOURCE" >&2; exit 2; }
  ARCH=${SOURCE%%=*}
  ARCHIVE=${SOURCE#*=}
  case "$ARCH" in
    amd64|arm64) ;;
    *) echo "Unsupported architecture: $ARCH" >&2; exit 1 ;;
  esac
  [[ -f "$ARCHIVE" ]] || { echo "Missing archive: $SOURCE" >&2; exit 1; }
  if [[ " ${EXPECTED_ARCHITECTURES[*]} " == *" $ARCH "* ]]; then
    echo "Duplicate architecture: $ARCH" >&2
    exit 1
  fi
  ARCH_REF="ocidir://${WORK_DIR}/${ARCH}:native"
  "$REGCTL" image import "$ARCH_REF" "$ARCHIVE"
  REF_ARGS+=(--ref "$ARCH_REF")
  PLATFORM_ARGS+=(--platform "linux/$ARCH")
  EXPECTED_ARCHITECTURES+=("$ARCH")
done

# Local OCI references keep untested scheduled images out of the registry.
MERGED_REF="ocidir://${WORK_DIR}/merged:combined"
"$REGCTL" index create "$MERGED_REF" "${REF_ARGS[@]}" "${PLATFORM_ARGS[@]}"
EXPECTED_ARCHITECTURES_JSON=$(jq -cn '$ARGS.positional | sort' --args "${EXPECTED_ARCHITECTURES[@]}")
MERGED_ARCHITECTURES_JSON=$("$REGCTL" manifest get "$MERGED_REF" --format raw-body |
  jq -c '[.manifests[] | select(.platform.os == "linux") | .platform.architecture] | sort')
if [[ "$MERGED_ARCHITECTURES_JSON" != "$EXPECTED_ARCHITECTURES_JSON" ]]; then
  echo "Merged index platforms $MERGED_ARCHITECTURES_JSON do not match $EXPECTED_ARCHITECTURES_JSON" >&2
  exit 1
fi
"$REGCTL" image export "$MERGED_REF" "$OUTPUT_ARCHIVE"
