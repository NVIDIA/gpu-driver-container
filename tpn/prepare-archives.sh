#!/usr/bin/env bash
# Build-stage adapter; dpkg-deb is already supplied by precompiled Ubuntu images.
set -euo pipefail
mkdir -p "$2"
: > "$2/packages"
shopt -s nullglob
for archive in "$1"/*.deb; do
    IFS=$'\t' read -r name version arch source < <(
        dpkg-deb --show --showformat='${Package}\t${Version}\t${Architecture}\t${Source}\n' "$archive")
    key="$name-$version.$arch"
    # Source fields without a version inherit the binary version.
    source=${source:-$name}
    if [[ "$source" != *' ('* ]]; then source="$source ($version)"; fi
    printf '%s\t%s\t%s\t%s\n' "$name" "$version" "$arch" "$source" >> "$2/packages"
    dpkg-deb -x "$archive" "$2/$key"
done
LC_ALL=C sort -u -o "$2/packages" "$2/packages"
