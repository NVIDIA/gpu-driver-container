#!/usr/bin/env bash
# tpn-gen.sh prints a third-party notice document for the container it runs in.
#
# It reads the package database of the image (dpkg or rpm) and copies each
# package's license text from the image itself. It writes Markdown to stdout.
# Run it once per image and platform. Do not merge documents across platforms.
#
# Manual run against a built image:
#   docker run --rm -v "$PWD/tpn:/tpn:ro" --entrypoint /tpn/tpn-gen.sh IMAGE > tpn.md
#
# Debian and Ubuntu: names from the DEP-5 "License:" fields, text from
# /usr/share/doc/<pkg>/copyright. Free-text copyright files give no names.
# RHEL: names from the rpm %{LICENSE} header, text from "rpm -q --licensefiles".
set -euo pipefail

COMMON=/usr/share/common-licenses
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
[ -f /var/lib/dpkg/status ] && DEB=1 || DEB=0

# list_packages prints one "name<TAB>version<TAB>arch<TAB>license" line per package.
list_packages() {
    if [ "$DEB" = 1 ]; then
        # Status is "install ok installed", or "hold ok installed" for packages on apt-mark hold.
        awk -v RS= -F'\n' '{
            n=v=a=""; ok=0
            for (i=1;i<=NF;i++) {
                if ($i ~ /^Package: /) n=substr($i,10)
                if ($i ~ /^Version: /) v=substr($i,10)
                if ($i ~ /^Architecture: /) a=substr($i,15)
                if ($i ~ /^Status: .* installed$/) ok=1
            }
            if (ok) printf "%s\t%s\t%s\t\n", n, v, a
        }' /var/lib/dpkg/status
    else
        rpm -qa --qf '%{NAME}\t%{VERSION}-%{RELEASE}\t%{ARCH}\t%{LICENSE}\n'
    fi | LC_ALL=C sort
}

# license_text prints the verbatim license file(s) of a package, or nothing.
license_text() {
    if [ "$DEB" = 1 ]; then
        # cat follows the symlink when /usr/share/doc/<pkg> points at another package.
        cat "/usr/share/doc/$1/copyright" 2>/dev/null || true
    else
        for f in $(rpm -q --licensefiles "$1" 2>/dev/null); do
            if [ -f "$f" ]; then echo "--- $f ---"; cat "$f"; fi
        done
    fi
}

# dep5_names prints the license names of a DEP-5 file, one per line.
# Split only on the DEP-5 separators "and", "or" and comma. "GPL-2+" must stay one name.
dep5_names() {
    awk '/^License:/ { sub(/^License:[ \t]*/, ""); if ($0 != "") print }' "$1" |
        sed -E 's/[ \t]+(and|or)[ \t]+/\n/g; s/,[ \t]*/\n/g' |
        sed -E 's/^[ \t]+|[ \t]+$//g' | grep -v '^$' | LC_ALL=C sort -u
}

# dep5_holders prints the "Copyright:" field values of a DEP-5 file, one per line.
dep5_holders() {
    awk '/^Copyright:/ { on=1; sub(/^Copyright:[ \t]*/, ""); if ($0 != "") print; next }
         /^[ \t]/ && on   { sub(/^[ \t]+/, ""); print; next }
         { on=0 }' "$1" | awk '!seen[$0]++'
}

# text_holders prints lines of a free-text file that carry a copyright statement:
# the word "copyright", "(c)" or "©" followed by a year. License boilerplate that
# only talks about copyright does not match.
text_holders() {
    grep -iE '(copyright|\(c\)|©)[[:space:](c)©]*[0-9]{4}' "$1" | awk 'length < 200' |
        sed -E 's/^[ \t]+|[ \t]+$//g' | awk '!seen[$0]++' || true
}

# code_block prints a file as a fenced text block without trailing blank lines.
code_block() {
    echo '```text'
    sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "$1"
    echo '```'
}

anchor() {
    echo "$*" | tr 'A-Z ' 'a-z-' | tr -cd 'a-z0-9-\n'
}

list_packages > "$WORK/packages"

echo "# Third-Party Notices"
echo
echo "Image: \`${TPN_IMAGE:-}\`  "
echo "Platform: \`${TPN_PLATFORM:-}\`  "
echo "Generated: $(date -u +%Y-%m-%d)  "
echo "Packages: $(wc -l < "$WORK/packages")"
echo
echo "This document lists every package installed in the image and reproduces the license text that the package installs in the image."
echo
echo "## Package index"
echo
echo "| Package | Version | Arch | License |"
echo "|---|---|---|---|"

# First pass: collect text, names and holders per package, and print the index.
while IFS=$'\t' read -r name version arch license; do
    text="$WORK/$name.text"
    license_text "$name" > "$text"
    if [ "$DEB" = 1 ] && [ -s "$text" ]; then
        if head -1 "$text" | grep -q '^Format:'; then
            license=$(dep5_names "$text" | paste -sd, - | sed 's/,/, /g')
            dep5_holders "$text" > "$WORK/$name.holders"
        else
            license="See license text"
            text_holders "$text" > "$WORK/$name.holders"
        fi
    else
        text_holders "$text" > "$WORK/$name.holders"
    fi
    echo "$license" > "$WORK/$name.license"
    echo "| [$name](#$(anchor "$name $version $arch")) | $version | $arch | $license |"
done < "$WORK/packages"

echo
echo "## Package details"

# Second pass: one section per package.
while IFS=$'\t' read -r name version arch _; do
    text="$WORK/$name.text"
    echo
    echo "### $name $version ($arch)"
    echo
    echo "License: $(cat "$WORK/$name.license")"
    echo
    if [ -s "$WORK/$name.holders" ]; then
        echo "Copyright:"
        echo
        sed 's/^/- /' "$WORK/$name.holders"
        echo
    fi
    if [ -s "$text" ]; then
        code_block "$text"
    elif [ "$DEB" = 1 ]; then
        echo "No copyright file is installed for this package."
    else
        echo "No license file is installed for this package. The license name comes from the rpm header."
    fi
done < "$WORK/packages"

# Debian copyright files often point at /usr/share/common-licenses instead of
# inlining the text. Append each referenced text once.
refs=$(cat "$WORK"/*.text | grep -oE "$COMMON/[A-Za-z0-9.+-]+" | sed "s#$COMMON/##" | LC_ALL=C sort -u || true)
if [ -n "$refs" ]; then
    echo
    echo "## Common license texts"
    echo
    echo "The copyright files above refer to these texts by path."
    for name in $refs; do
        [ -f "$COMMON/$name" ] || continue
        echo
        echo "### $name"
        echo
        code_block "$COMMON/$name"
    done
fi
