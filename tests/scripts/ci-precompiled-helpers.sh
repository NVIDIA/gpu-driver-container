get_kernel_versions_to_test() {
    if [[ "$#" -ne 4 ]]; then
	    echo " Error:$0 must be called with KERNEL_FLAVORS DRIVER_BRANCHES DIST LTS_KERNEL" >&2
	    exit 1
    fi

    local -a KERNEL_FLAVORS=("${!1}")
    local -a DRIVER_BRANCHES=("${!2}")
    local DIST="$3"
    local LTS_KERNEL="$4"

    kernel_versions=()
    for kernel_flavor in "${KERNEL_FLAVORS[@]}"; do
        for DRIVER_BRANCH in "${DRIVER_BRANCHES[@]}"; do
            source ./tests/scripts/findkernelversion.sh "${kernel_flavor}" "$DRIVER_BRANCH" "$DIST" "$LTS_KERNEL" >&2
            if [[ "$should_continue" == true ]]; then
                break
            fi
        done
        if [[ "$should_continue" == true ]]; then
            KERNEL_VERSION=$(echo "$KERNEL_VERSION" | tr -d ' \n')
            kernel_versions+=("$KERNEL_VERSION")
        fi
    done
    # Remove duplicates
    kernel_versions=($(printf "%s\n" "${kernel_versions[@]}" | sort -u))
    for i in "${!kernel_versions[@]}"; do
        kernel_versions[$i]="${kernel_versions[$i]}-$DIST"
    done
    echo "${kernel_versions[@]}"
}
