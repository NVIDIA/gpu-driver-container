#!/usr/bin/env bash
# Offline notices from the final image's package database and installed texts.
# Run once per platform: bash /path/to/tpn/tpn-gen.sh > THIRD-PARTY-NOTICES.md
set -euo pipefail
export LC_ALL=C
HERE=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
[ -f /var/lib/dpkg/status ] && DEB=1 || DEB=0

if [ "$DEB" = 1 ]; then
    awk -v RS= -F'\n' '{
        n=v=a=""; ok=0
        for(i=1;i<=NF;i++) {
            if($i ~ /^Package: /) n=substr($i,10)
            if($i ~ /^Version: /) v=substr($i,10)
            if($i ~ /^Architecture: /) a=substr($i,15)
            if($i ~ /^Status: .* installed$/) ok=1
        }
        if(ok) printf "%s\t%s\t%s\t-\t-\n",n,v,a
    }' /var/lib/dpkg/status | sort > "$WORK/packages"
else
    # Query the database twice, rather than launching rpm for every package.
    rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\t%{ARCH}\t%{SOURCERPM}\t%{LICENSE}\n' | sort > "$WORK/packages"
    rpm -qa --qf '[%{=NAME}-%{=VERSION}-%{=RELEASE}.%{=ARCH}\t%{FILENAMES}\t%{FILEFLAGS}\n]' |
        awk -F'\t' -v dir="$WORK" '
            int($3/128)%2 || tolower($2) ~ /\/(copying|copyright|licen[cs]e|notices?|third[-_]party[-_]notices?)([._-][^/]*)?$/ {
                print $2 >> (dir "/" $1 ".files"); close(dir "/" $1 ".files")
            }
            $2 ~ /\.pm$/ {print $2 >> (dir "/" $1 ".embedded"); close(dir "/" $1 ".embedded")}'
fi

# Keep each version/architecture separate (including multiple gpg-pubkey entries).
declare -A siblings=() standards=()
while IFS=$'\t' read -r name version arch source license; do
    key="$name-$version.$arch"
    text="$WORK/$key.text"
    : > "$text"
    if [ "$DEB" = 1 ]; then
        for f in "/usr/share/doc/$name:$arch/copyright" "/usr/share/doc/$name/copyright"; do
            if [ -f "$f" ]; then cat "$f" > "$text"; break; fi
        done
    elif [ -f "$WORK/$key.files" ]; then
        while IFS= read -r f; do
            if [ -f "$f" ]; then printf '\n--- %s ---\n' "$f"; cat "$f"; printf '\n'; fi
        done < "$WORK/$key.files" > "$text"
        if [ -s "$text" ] && [ "$source" != '(none)' ]; then
            siblings["$source"]+="$key"$'\n'
        fi
    fi
    awk -v prefix="$WORK/$key" -f "$HERE/parse.awk" "$text"
    if [ "$DEB" = 0 ]; then printf '%s\n' "$license" > "$WORK/$key.license"; fi
done < "$WORK/packages"

if [ "$DEB" = 0 ]; then
    # Some packages keep their notices only in POD sections of installed modules.
    while IFS=$'\t' read -r name version arch source header; do
        key="$name-$version.$arch"
        if [ ! -s "$WORK/$key.text" ] && [ -z "${siblings[$source]:-}" ] && [ -f "$WORK/$key.embedded" ]; then
            while IFS= read -r f; do
                [ -f "$f" ] || continue
                awk '
                    /^=head[1-6] / {on=(tolower($0) ~ /license|copyright/); if(on) printf "\n--- Embedded notice: %s ---\n", FILENAME}
                    /^=cut/ {on=0}
                    on {print}' "$f"
            done < "$WORK/$key.embedded" > "$WORK/$key.text"
            awk -v prefix="$WORK/$key" -f "$HERE/parse.awk" "$WORK/$key.text"
            printf '%s\n' "$header" > "$WORK/$key.license"
        fi
    done < "$WORK/packages"
    cat "$WORK"/*.files 2>/dev/null | sort -u > "$WORK/files" || true
    while IFS= read -r f; do
        [ -s "$f" ] || continue
        while IFS= read -r id; do
            if [ -n "$id" ] && [ -z "${standards[$id]:-}" ]; then standards[$id]="$f"; fi
        done < <(awk -f "$HERE/standard.awk" "$f")
    done < "$WORK/files"
fi

code_block() {
    # Use a fence longer than any backtick run in the original text.
    local fence
    fence=$(awk 'BEGIN {n=3} {s=$0; while(match(s,/`+/)) {if(RLENGTH>=n)n=RLENGTH+1; s=substr(s,RSTART+RLENGTH)}} END {for(i=0;i<n;i++)printf "`"}' "$1")
    printf '%stext\n' "$fence"
    cat "$1"
    printf '\n%s\n' "$fence"
}
anchor() { printf '%s\n' "$*" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9-\n'; }

echo '# Third-Party Notices'
printf '\nImage: `%s`  \nPlatform: `%s`  \nGenerated: %s  \nPackages: %s\n' \
    "${TPN_IMAGE:-}" "${TPN_PLATFORM:-}" "$(date -u +%Y-%m-%d)" "$(wc -l < "$WORK/packages")"
cat <<'TEXT'

This document lists installed packages and reproduces the license files available in this image. Declared names come from DEP-5 fields or RPM headers; prose matches are marked "detected" and are not a legal determination. Borrowed texts are labelled with their source and do not establish a package's copyright holders. Missing information is stated explicitly.

## Package index

| Package | Version | Arch | License |
|---|---|---|---|
TEXT
while IFS=$'\t' read -r name version arch _; do
    key="$name-$version.$arch"
    read -r license < "$WORK/$key.license" || true
    if [ -z "$license" ] && [ -s "$WORK/$key.text" ]; then license='See license text'; fi
    printf '| [%s](#%s) | %s | %s | %s |\n' "$name" "$(anchor "$name $version $arch")" "$version" "$arch" "${license//|/\&#124;}"
done < "$WORK/packages"

printf '\n## Package details\n'
while IFS=$'\t' read -r name version arch source _; do
    key="$name-$version.$arch"
    text="$WORK/$key.text"
    read -r license < "$WORK/$key.license" || true
    printf '\n### %s %s (%s)\n\nLicense: %s\n\n' "$name" "$version" "$arch" "${license:-See license text}"
    if [ -s "$WORK/$key.holders" ]; then
        printf 'Copyright:\n\n'
        sed 's/^/- /' "$WORK/$key.holders"
        echo
    elif [ ! -s "$text" ]; then
        echo 'Package-specific copyright holders are not available in the installed license files.'
        echo
    else
        echo 'No copyright holder statement was identified; see the verbatim text below.'
        echo
    fi
    if [ -s "$text" ]; then
        code_block "$text"
    elif [ "$DEB" = 1 ]; then
        echo 'No copyright file is installed for this package.'
    elif [ -n "${siblings[$source]:-}" ]; then
        while IFS= read -r sibling; do
            [ -n "$sibling" ] || continue
            printf '\nLicense text from sibling package %s (same source RPM: %s). The source RPM may cover additional components.\n\n' "$sibling" "$source"
            code_block "$WORK/$sibling.text"
        done <<< "${siblings[$source]}"
    else
        echo 'No package or same-source RPM license file is installed. The license declaration above is from the RPM header.'
        while IFS= read -r id; do
            base=${id%-or-later}; base=${base%-only}
            f=${standards[$base]:-}
            if [ -n "$f" ]; then
                printf '\nStandard text for %s from installed file %s (fallback; donor notices belong to the donor). Package-specific notices and exceptions remain unavailable.\n\n' "$id" "$f"
                code_block "$f"
            else
                printf '\nNo matching standard text available in this image for: %s.\n' "$id"
            fi
        done < <(printf '%s\n' "$license" | awk -f "$HERE/rpm-license.awk")
    fi
done < "$WORK/packages"

if [ -n "${TPN_ARCHIVES:-}" ]; then source "$HERE/archives.sh"; fi

# Follow common-license references in the image; report broken references as gaps.
cat "$WORK"/*.refs 2>/dev/null | sort -u > "$WORK/common" || true
if [ -s "$WORK/common" ]; then
    printf '\n## Common license texts\n\nThe copyright files above refer to these texts by path.\n'
    while IFS= read -r f; do
        printf '\n### %s\n\n' "${f##*/}"
        if [ -f "$f" ]; then code_block "$f"; else printf 'Referenced file is not installed: %s\n' "$f"; fi
    done < "$WORK/common"
fi

if [ -n "${TPN_DOCKERFILE:-}" ]; then
    # Only downloaded, non-package components are described by a checked-in manifest.
    source "$HERE/standalone.sh"
fi
