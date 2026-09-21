# Sourced by tpn-gen.sh after the installed package details.
if [ -s "$TPN_ARCHIVES/packages" ]; then
    printf '\n## Bundled package archives\n\nThese packages are shipped in the local repository and may not be installed. Versions and texts were read from the bundled archives.\n'
    while IFS=$'\t' read -r name version arch source; do
        printf '\n#### %s %s (%s; bundled archive)\n\n' "$name" "$version" "$arch"
        text="$TPN_ARCHIVES/$name-$version.$arch/usr/share/doc/$name/copyright"
        if [ -f "$TPN_ARCHIVES/$name-$version.$arch/usr/share/doc/$name:$arch/copyright" ]; then
            text="$TPN_ARCHIVES/$name-$version.$arch/usr/share/doc/$name:$arch/copyright"
        fi
        if [ ! -f "$text" ]; then
            while IFS=$'\t' read -r sibling sv sa ss; do
                f="$TPN_ARCHIVES/$sibling-$sv.$sa/usr/share/doc/$sibling/copyright"
                if [ "$ss" = "$source" ] && [ -f "$f" ]; then
                    text="$f"
                    printf 'License text from bundled sibling %s %s (same source: %s).\n\n' "$sibling" "$sv" "$source"
                    break
                fi
            done < "$TPN_ARCHIVES/packages"
        fi
        if [ -f "$text" ]; then
            awk -v prefix="$WORK/archive" -f "$HERE/parse.awk" "$text"
            read -r license < "$WORK/archive.license" || true
            printf 'License: %s\n\n' "${license:-See license text}"
            code_block "$text"
        else
            echo 'No copyright file is included in this archive or an archive with the same source and version.'
        fi
    done < "$TPN_ARCHIVES/packages"
fi
