#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${REPO_ROOT}"

distros=(ubuntu22.04 ubuntu24.04 ubuntu26.04 rhel8 rhel9 rhel10)
helpers=()
drivers=()

for distro in "${distros[@]}"; do
    helpers+=("${distro}/module-tree-cache.sh")
    drivers+=("${distro}/nvidia-driver")
done

hashes=$(
    for helper in "${helpers[@]}"; do
        if command -v sha256sum >/dev/null 2>&1; then
            sha256sum "${helper}" | awk '{print $1}'
        else
            shasum -a 256 "${helper}" | awk '{print $1}'
        fi
    done | sort -u
)
if [[ $(wc -l <<< "${hashes}" | tr -d ' ') -ne 1 ]]; then
    echo "module-tree-cache.sh copies have drifted"
    exit 1
fi

for script in "${helpers[@]}" "${drivers[@]}" \
    rhel{8,9,10}/{common.sh,ocp_dtk_entrypoint}; do
    bash -n "${script}"
done

python3 - <<'PY'
from pathlib import Path

distros = ("ubuntu22.04", "ubuntu24.04", "ubuntu26.04", "rhel8", "rhel9", "rhel10")

def assert_ordered(text, tokens, description):
    cursor = 0
    for token in tokens:
        cursor = text.find(token, cursor)
        if cursor < 0:
            raise SystemExit(f"{description}: missing or out-of-order {token}")
        cursor += len(token)

for distro in distros:
    text = (Path(distro) / "nvidia-driver").read_text()
    assert_ordered(
        text,
        ("\n    _load_driver", "\n    module_tree_save", "\n    _mount_rootfs", "\n    _start_daemons"),
        f"{distro}/nvidia-driver full install",
    )
    fast_start = text.find("module_tree_restore")
    if fast_start < 0:
        raise SystemExit(f"{distro}/nvidia-driver fast path lacks restore")
    assert_ordered(
        text[fast_start:],
        ("module_tree_restore", "_mount_rootfs", "_start_daemons"),
        f"{distro}/nvidia-driver fast path",
    )

for distro in ("rhel8", "rhel9", "rhel10"):
    text = (Path(distro) / "ocp_dtk_entrypoint").read_text()
    if text.count("module-tree-cache.sh") != 3:
        raise SystemExit(f"{distro}/ocp_dtk_entrypoint does not package the helper in all paths")
    if "force_module_build" not in text:
        raise SystemExit(f"{distro}/ocp_dtk_entrypoint lacks the shared build decision")
    force_marker = text.find('touch "$DRIVER_TOOLKIT_SHARED_DIR/force_module_build"')
    prepared_marker = text.find('touch "$DRIVER_TOOLKIT_SHARED_DIR/dir_prepared"')
    if force_marker < 0 or prepared_marker < 0 or force_marker > prepared_marker:
        raise SystemExit(f"{distro}/ocp_dtk_entrypoint publishes dir_prepared before its decision")
    for carve_out in (
        r"sed 's|rm -rf /lib/modules/${KERNEL_VERSION}/video||'",
        r"sed 's|rm -rf /lib/modules/${KERNEL_VERSION}||'",
    ):
        if carve_out not in text:
            raise SystemExit(f"{distro}/ocp_dtk_entrypoint lost DTK carve-out: {carve_out}")
PY

bash tests/scripts/test-module-tree-cache.sh
