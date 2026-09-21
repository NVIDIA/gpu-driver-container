# Sourced by tpn-gen.sh. Only the manifest names standalone components.
printf '\n## Standalone components\n'
matched=0
driver_arch=${TARGETARCH:-${TARGET_ARCH:-unknown}}
driver_arch=${driver_arch/amd64/x86_64}; driver_arch=${driver_arch/arm64/aarch64}
while IFS='|' read -r dockerfile component version url license installed notice; do
    [ "$dockerfile" = "$TPN_DOCKERFILE" ] || continue
    matched=1
    if [ "$notice" = none ]; then echo; echo "No standalone downloads; the driver payload is supplied by packages."; continue; fi
    version=${version/DRIVER_VERSION/${DRIVER_VERSION:-unknown}}
    url=${url/BASE_URL/${TPN_BASE_URL:-https://us.download.nvidia.com/tesla}}
    url=${url/DRIVER_VERSION/$version}
    printf '\n### %s %s\n\nLicense: %s\n\n' "$component" "$version" "$license"
    if [ "$notice" = driver ] || [ "$notice" = extracted-driver ]; then
        if [ "$notice" = driver ]; then
            # The runfile is already in the image. Extract only in the disposable TPN stage.
            shopt -s nullglob
            installers=($installed)
            shopt -u nullglob
            if [ "${#installers[@]}" -eq 0 ]; then
                echo 'No driver installer is present in the image.'
                continue
            fi
            for installer in "${installers[@]}"; do
                printf 'Source: %s\n\n' "${url/INSTALLER/${installer##*/}}"
                sh "$installer" --extract-only --target "$WORK/driver" > "$WORK/extract.log" 2>&1 || { cat "$WORK/extract.log" >&2; exit 1; }
                for f in LICENSE html/acknowledgements.html; do
                    [ -s "$WORK/driver/$f" ] || { echo "Missing driver notice: $f" >&2; exit 1; }
                    printf '\n#### %s\n\n' "$f"
                    code_block "$WORK/driver/$f"
                done
                rm -rf "$WORK/driver"
            done
        else
            printf 'Source: %s (notices retained from the driver build stage)\n\n' "${url/INSTALLER/NVIDIA-Linux-${driver_arch}-$version.run}"
            for f in LICENSE html/acknowledgements.html; do
                [ -s "/tmp/tpn-driver/$f" ] || { echo "Missing driver notice: $f" >&2; exit 1; }
                printf '\n#### %s\n\n' "$f"
                code_block "/tmp/tpn-driver/$f"
            done
        fi
    elif [ "$notice" = retained-installer ]; then
        printf 'Source: %s (installer retained from the driver distribution; acknowledgements cover that distribution)\n\n' "${url/INSTALLER/NVIDIA-Linux-${driver_arch}-$version.run}"
        for f in LICENSE html/acknowledgements.html; do
            printf '\n#### %s\n\n' "$f"
            code_block "/licenses/nvidia-installer/$f"
        done
    elif [ -f "$installed" ]; then
        printf 'Source: %s\n\n' "$url"
        # Retain the script's copyright and SPDX header as well as its full license.
        if [[ "$notice" = header+* ]]; then sed -n '1,/^$/p' "$installed"; echo; notice=${notice#header+}; fi
        code_block "$HERE/$notice"
    else
        printf 'Manifest component is not installed at %s.\n' "$installed"
    fi
done < "$HERE/components.tsv"
[ "$matched" = 1 ] || { echo "No standalone manifest for $TPN_DOCKERFILE" >&2; exit 1; }
