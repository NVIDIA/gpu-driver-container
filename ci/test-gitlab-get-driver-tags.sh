#!/usr/bin/env bash
# Each unset-regex driver version must select its own registry tags.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${SCRIPT_DIR}/gitlab-get-driver-tags.sh"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

mkdir -p "${WORK_DIR}/bin"
cat > "${WORK_DIR}/bin/curl" << 'EOF'
#!/usr/bin/env bash
url="${@: -1}"
if [[ "${url}" == *"/tags" ]]; then
  printf '%s\n' '[{"name":"570.1-ubuntu","location":"loc570"},{"name":"575.1-ubuntu","location":"loc575"}]'
else
  printf '%s\n' '[{"path":"proj","id":1}]'
fi
EOF
chmod +x "${WORK_DIR}/bin/curl"

(
  cd "${WORK_DIR}"
  PATH="${WORK_DIR}/bin:${PATH}" \
  ALL_DRIVER_VERSIONS="570.1 575.1" \
  API_TOKEN=token \
  CI_API_V4_URL=http://example.test \
  CI_PROJECT_PATH=proj \
  CI_PROJECT_ID=1 \
  bash "${TARGET}" >/dev/null 2>&1
)

tags="$(cat "${WORK_DIR}/driver-tags")"
grep -qx 'loc570' <<< "${tags}"
grep -qx 'loc575' <<< "${tags}"
test "$(grep -c '^loc570$' <<< "${tags}")" -eq 1
test "$(grep -c '^loc575$' <<< "${tags}")" -eq 1

# An explicit pattern still applies to every version.
(
  cd "${WORK_DIR}"
  rm -f driver-tags
  PATH="${WORK_DIR}/bin:${PATH}" \
  ALL_DRIVER_VERSIONS="570.1 575.1" \
  TAGS_REGEX='575\.1' \
  API_TOKEN=token \
  CI_API_V4_URL=http://example.test \
  CI_PROJECT_PATH=proj \
  CI_PROJECT_ID=1 \
  bash "${TARGET}" >/dev/null 2>&1
)
override="$(cat "${WORK_DIR}/driver-tags")"
loc575_count="$(grep -c '^loc575$' <<< "${override}" || true)"
loc570_count="$(grep -c '^loc570$' <<< "${override}" || true)"
test "${loc575_count}" -eq 2
test "${loc570_count}" -eq 0
