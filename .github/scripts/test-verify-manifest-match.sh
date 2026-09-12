#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_SCRIPT="${SCRIPT_DIR}/verify-manifest-match.sh"
WORK_DIR=$(mktemp -d)
trap 'rm -rf "${WORK_DIR}"' EXIT

VERIFICATION_FAILED_EXIT_CODE=1
FAILURE_COUNT=0

assert_pass() {
  local case_name=$1 local_manifest_json=$2 remote_manifest_json=$3
  echo "$local_manifest_json" > "${WORK_DIR}/local.json"
  echo "$remote_manifest_json" > "${WORK_DIR}/remote.json"
  if "${VERIFY_SCRIPT}" "${WORK_DIR}/local.json" "${WORK_DIR}/remote.json" >/dev/null; then
    echo "PASS: ${case_name}"
  else
    echo "FAIL: ${case_name} (expected match, script reported mismatch)"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
  fi
}

assert_fail() {
  local case_name=$1 local_manifest_json=$2 remote_manifest_json=$3
  local exit_code=0
  echo "$local_manifest_json" > "${WORK_DIR}/local.json"
  echo "$remote_manifest_json" > "${WORK_DIR}/remote.json"
  "${VERIFY_SCRIPT}" "${WORK_DIR}/local.json" "${WORK_DIR}/remote.json" >/dev/null 2>&1 || exit_code=$?
  if [[ "${exit_code}" -eq "${VERIFICATION_FAILED_EXIT_CODE}" ]]; then
    echo "PASS: ${case_name}"
  else
    echo "FAIL: ${case_name} (expected exit ${VERIFICATION_FAILED_EXIT_CODE}, got ${exit_code})"
    FAILURE_COUNT=$((FAILURE_COUNT + 1))
  fi
}

MULTI_ARCH_INDEX='{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:5861314d7fccb39c2192173240eab44fa35ca66426201ca2acd0630a6258dd51", "size": 1, "platform": {"architecture": "amd64", "os": "linux"}},
    {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:f69162950f235e3cdbbad33f1f912d1a504be90d8a37d002c735d6f3e3882265", "size": 1, "platform": {"architecture": "arm64", "os": "linux"}},
    {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:813a89a296973e35545cfa74fe3efd172a7d19443c97c625d699e9737229b0a2", "size": 1, "platform": {"architecture": "unknown", "os": "unknown"}, "annotations": {"vnd.docker.reference.type": "attestation-manifest"}}
  ]
}'

MULTI_ARCH_INDEX_WRONG_DIGEST='{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:5861314d7fccb39c2192173240eab44fa35ca66426201ca2acd0630a6258dd51", "size": 1, "platform": {"architecture": "amd64", "os": "linux"}},
    {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:5b8c821bfcb9a4545169cdd6e80c0b7467aefad06b3686d141e8a4eebb089001", "size": 1, "platform": {"architecture": "arm64", "os": "linux"}}
  ]
}'

MULTI_ARCH_INDEX_DROPPED_ARCH='{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:5861314d7fccb39c2192173240eab44fa35ca66426201ca2acd0630a6258dd51", "size": 1, "platform": {"architecture": "amd64", "os": "linux"}}
  ]
}'

MULTI_ARCH_INDEX_ONLY_ATTESTATIONS='{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:813a89a296973e35545cfa74fe3efd172a7d19443c97c625d699e9737229b0a2", "size": 1, "platform": {"architecture": "unknown", "os": "unknown"}, "annotations": {"vnd.docker.reference.type": "attestation-manifest"}}
  ]
}'

ARM_VARIANTS_LOCAL='{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:5ba6c8710dd1369ce61603ab9b7a81b25f92d4a9f74956ab72a7ea75884f07ee", "size": 1, "platform": {"architecture": "arm", "os": "linux", "variant": "v7"}},
    {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:ac232e0a336f18d13b7f1aee7080b6f08c998893c20bac239282ec8f68f4a8d6", "size": 1, "platform": {"architecture": "arm", "os": "linux", "variant": "v8"}}
  ]
}'
ARM_VARIANTS_REMOTE_CROSSED='{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.index.v1+json",
  "manifests": [
    {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:ac232e0a336f18d13b7f1aee7080b6f08c998893c20bac239282ec8f68f4a8d6", "size": 1, "platform": {"architecture": "arm", "os": "linux", "variant": "v7"}},
    {"mediaType": "application/vnd.oci.image.manifest.v1+json", "digest": "sha256:5ba6c8710dd1369ce61603ab9b7a81b25f92d4a9f74956ab72a7ea75884f07ee", "size": 1, "platform": {"architecture": "arm", "os": "linux", "variant": "v8"}}
  ]
}'

SINGLE_ARCH_MANIFEST='{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "config": {"digest": "sha256:b79606fb3afea5bd1609ed40b622142f1c98125abcfe89a76a661b0e8e343910"},
  "layers": [
    {"digest": "sha256:77ea7eee3d80b1a38f83906dd3048e2689457eb90e18a7d12f839c5ae37106a2"},
    {"digest": "sha256:95cf1a2e1698fe3ca1fcc3f653119146b271d0b62e487ec264441e886a11bd06"}
  ]
}'

SINGLE_ARCH_MANIFEST_WRONG_LAYER='{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json",
  "config": {"digest": "sha256:b79606fb3afea5bd1609ed40b622142f1c98125abcfe89a76a661b0e8e343910"},
  "layers": [
    {"digest": "sha256:77ea7eee3d80b1a38f83906dd3048e2689457eb90e18a7d12f839c5ae37106a2"},
    {"digest": "sha256:b65ca8dd8051dc117f51fd1df452e8ef107be2f84ca0f99b18c12311bd10b9c8"}
  ]
}'

assert_pass "multi-arch index, identical" "$MULTI_ARCH_INDEX" "$MULTI_ARCH_INDEX"
assert_fail "multi-arch index, wrong digest for one platform" "$MULTI_ARCH_INDEX" "$MULTI_ARCH_INDEX_WRONG_DIGEST"
assert_fail "multi-arch index, dropped architecture" "$MULTI_ARCH_INDEX" "$MULTI_ARCH_INDEX_DROPPED_ARCH"
assert_fail "same architecture, crossed variant/digest" "$ARM_VARIANTS_LOCAL" "$ARM_VARIANTS_REMOTE_CROSSED"
assert_pass "single-arch manifest, identical" "$SINGLE_ARCH_MANIFEST" "$SINGLE_ARCH_MANIFEST"
assert_fail "single-arch manifest, wrong layer digest" "$SINGLE_ARCH_MANIFEST" "$SINGLE_ARCH_MANIFEST_WRONG_LAYER"
assert_fail "multi-arch index published as single-arch manifest" "$MULTI_ARCH_INDEX" "$SINGLE_ARCH_MANIFEST"
assert_fail "index holding only attestation manifests" "$MULTI_ARCH_INDEX_ONLY_ATTESTATIONS" "$MULTI_ARCH_INDEX_ONLY_ATTESTATIONS"
assert_fail "empty manifest files" "" ""

if [[ "${FAILURE_COUNT}" -gt 0 ]]; then
  echo "${FAILURE_COUNT} case(s) failed"
  exit 1
fi
echo "All cases passed"
