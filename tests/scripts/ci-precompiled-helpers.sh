get_kernel_versions_to_test() {
    if [[ "$#" -ne 4 ]]; then
	    echo " Error:$0 must be called with BASE_TARGET DRIVER_BRANCHES DRIVER_BRANCHES DIST" >&2
	    exit 1
    fi

    local BASE_TARGET="$1"
    local -a KERNEL_FLAVORS=("${!2}")
    local -a DRIVER_BRANCHES=("${!3}")
    local DIST="$4"

    kernel_versions=()
    for kernel_flavor in "${KERNEL_FLAVORS[@]}"; do
        # FIXME -- remove if condition, once azure kernel upgrade starts working
        if [[ "$kernel_flavor" == "azure" ]]; then
            continue
        fi
        for DRIVER_BRANCH in "${DRIVER_BRANCHES[@]}"; do
            source ./tests/scripts/findkernelversion.sh "$BASE_TARGET" "${kernel_flavor}" "$DRIVER_BRANCH" "$DIST" >&2
            if [[ "$should_continue" == true ]]; then
                break
            fi
        done
        if [[ "$should_continue" == true ]]; then
            KERNEL_VERSION=$(echo "$KERNEL_VERSION" | tr -d ' \n')
            kernel_versions+=("$KERNEL_VERSION")
        fi
    done
    echo "${kernel_versions[@]}"
}
