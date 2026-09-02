#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <local_raw_manifest_file> <remote_raw_manifest_file>" >&2
  exit 2
fi

INDEX_SUMMARY_FILTER='[(.manifests // [])[] | select(.platform.architecture and .platform.architecture != "unknown") | {os: .platform.os, arch: .platform.architecture, variant: (.platform.variant // null), digest: .digest}] | sort_by(.os, .arch, .variant, .digest)'
MANIFEST_SUMMARY_FILTER='{config: .config.digest, layers: [(.layers // [])[].digest]}'
SUMMARY_HAS_DIGESTS_FILTER='(type == "array" and length > 0) or (type == "object" and .config != null and (.layers | length) > 0)'

summarize_manifest() {
  local manifest_file=$1
  local summary

  if ! jq -e 'type == "object"' "$manifest_file" >/dev/null 2>&1; then
    echo "ERROR: $manifest_file is not a valid JSON manifest" >&2
    return 1
  fi

  if jq -e 'has("manifests")' "$manifest_file" >/dev/null 2>&1; then
    summary=$(jq -c "$INDEX_SUMMARY_FILTER" "$manifest_file") || return 1
  else
    summary=$(jq -c "$MANIFEST_SUMMARY_FILTER" "$manifest_file") || return 1
  fi

  if ! jq -e "$SUMMARY_HAS_DIGESTS_FILTER" >/dev/null 2>&1 <<<"$summary"; then
    echo "ERROR: $manifest_file describes no platform or layer digests" >&2
    return 1
  fi

  printf '%s' "$summary"
}

LOCAL_SUMMARY=$(summarize_manifest "$1") || exit 1
REMOTE_SUMMARY=$(summarize_manifest "$2") || exit 1

if [[ "$LOCAL_SUMMARY" == "$REMOTE_SUMMARY" ]]; then
  echo "OK: published manifest matches built artifact"
else
  echo "ERROR: manifest mismatch between artifact and published image"
  echo "Local:  $LOCAL_SUMMARY"
  echo "Remote: $REMOTE_SUMMARY"
  exit 1
fi
