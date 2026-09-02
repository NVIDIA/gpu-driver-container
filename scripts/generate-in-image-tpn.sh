#!/usr/bin/env bash
# Copyright (c) 2026, NVIDIA CORPORATION. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# Generate a third-party notice directly from an already-built container
# root filesystem. Syft is the source of truth for package inventory, package
# ownership, declared licenses, Go modules, and available license content.

set -euo pipefail

SYFT="${SYFT:-syft}"
JQ="${JQ:-jq}"
OUTPUT_DIR="${1:-${TPN_OUTPUT_DIR:-/licenses}}"
DOCUMENT_NAME="${TPN_DOCUMENT_NAME:-THIRD_PARTY_NOTICES.md}"
INVENTORY_NAME="${TPN_INVENTORY_NAME:-third-party-packages.tsv}"
TPN_SYFT_ALL_CATALOGERS="${TPN_SYFT_ALL_CATALOGERS:-0}"
TPN_FETCH_UPSTREAM="${TPN_FETCH_UPSTREAM:-1}"
TPN_STRICT="${TPN_STRICT:-0}"

# Syft cannot reliably map arbitrary binaries and scripts downloaded outside
# RPM/DPKG to an upstream name, version, and license.
# These are the things directly curled by the Dockerfile.
standalone_manifest() {
    cat <<'EOF'
rhel8|/usr/local/bin/donkey|donkey|1.1.0|ISC|https://raw.githubusercontent.com/3XX0/donkey/v1.1.0/donkey.c|c-header|binary-stderr|https://github.com/3XX0/donkey
rhel8|/usr/local/bin/extract-vmlinux|extract-vmlinux||GPL-2.0-only|https://raw.githubusercontent.com/torvalds/linux/master/LICENSES/preferred/GPL-2.0|file|sha256|https://github.com/torvalds/linux
rhel9|/usr/local/bin/donkey|donkey|1.1.0|ISC|https://raw.githubusercontent.com/3XX0/donkey/v1.1.0/donkey.c|c-header|binary-stderr|https://github.com/3XX0/donkey
rhel9|/usr/local/bin/extract-vmlinux|extract-vmlinux||GPL-2.0-only|https://raw.githubusercontent.com/torvalds/linux/master/LICENSES/preferred/GPL-2.0|file|sha256|https://github.com/torvalds/linux
rhel10|/usr/local/bin/donkey|donkey|1.1.0|ISC|https://raw.githubusercontent.com/3XX0/donkey/v1.1.0/donkey.c|c-header|binary-stderr|https://github.com/3XX0/donkey
rhel10|/usr/local/bin/extract-vmlinux|extract-vmlinux||GPL-2.0-only|https://raw.githubusercontent.com/torvalds/linux/master/LICENSES/preferred/GPL-2.0|file|sha256|https://github.com/torvalds/linux
rhel10|/usr/bin/unzboot|unzboot|0.1|GPL-2.0-or-later|https://raw.githubusercontent.com/eballetbo/unzboot/main/LICENSE|file|version-sha256|https://github.com/eballetbo/unzboot
ubuntu22.04|/usr/local/bin/donkey|donkey|1.1.0|ISC|https://raw.githubusercontent.com/3XX0/donkey/v1.1.0/donkey.c|c-header|binary-stderr|https://github.com/3XX0/donkey
EOF
}

WORK_ROOT=""
WARNINGS=0

die() {
    printf 'ERROR: %s\n' "$1" >&2
    shift
    (( $# == 0 )) || printf '%s\n' "$@" >&2
    exit 1
}

log() {
    printf '%s\n' "$*" >&2
}

warn() {
    WARNINGS=$((WARNINGS + 1))
    printf 'WARNING: %s\n' "$*" >&2
}

cleanup() {
    if [[ -n "${WORK_ROOT}" && -d "${WORK_ROOT}" ]]; then
        chmod -R u+w "${WORK_ROOT}" 2>/dev/null || true
        rm -rf "${WORK_ROOT}"
    fi
}

trap cleanup EXIT

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "$1 is required."
}

check_boolean() {
    local name="$1" value="$2"
    [[ "${value}" == 0 || "${value}" == 1 ]] \
        || die "${name} must be 0 or 1."
}

hash_file() {
    sha256sum "$1" | awk '{print $1}'
}

safe_component() {
    printf '%s' "$1" | tr '/[:space:]' '__'
}

detect_distribution() {
    local id version major
    [[ -r /etc/os-release ]] \
        || die "/etc/os-release is missing; cannot identify the distribution."

    id="$(. /etc/os-release >/dev/null 2>&1; printf '%s' "${ID:-}")"
    version="$(. /etc/os-release >/dev/null 2>&1; printf '%s' "${VERSION_ID:-}")"
    [[ -n "${id}" && -n "${version}" ]] \
        || die "/etc/os-release does not declare both ID and VERSION_ID."
    major="${version%%.*}"

    case "${id}" in
        rhel|redhat|rocky|almalinux|centos) DISTRIBUTION="rhel${major}" ;;
        ubuntu) DISTRIBUTION="ubuntu${version}" ;;
        debian) DISTRIBUTION="debian${major}" ;;
        *)
            die "unsupported distribution ${id}${version}; expected an RPM- or DPKG-based image."
            ;;
    esac
}

detect_architecture() {
    local machine
    if [[ -n "${TARGETARCH:-}" ]]; then
        ARCHITECTURE="${TARGETARCH}"
        return
    fi

    machine="$(uname -m)"
    case "${machine}" in
        x86_64|amd64) ARCHITECTURE="amd64" ;;
        aarch64|arm64) ARCHITECTURE="arm64" ;;
        ppc64le) ARCHITECTURE="ppc64le" ;;
        *) ARCHITECTURE="${machine}" ;;
    esac
}

validate_vgpu_binary_modules() {
    local inventory="$1" stdlib_version expected

    stdlib_version="$(awk -F '\t' '$3 == "go-standard-library" { print $2 }' \
        "${inventory}" | LC_ALL=C sort -u)"
    [[ -n "${stdlib_version}" && "${stdlib_version}" != *$'\n'* ]] \
        || die "Syft did not find exactly one Go standard library in vgpu-util."

    if [[ -n "${GOLANG_VERSION:-}" ]]; then
        expected="${GOLANG_VERSION#go}"
        [[ "${stdlib_version#go}" == "${expected}" ]] \
            || die "vgpu-util reports ${stdlib_version}, but GOLANG_VERSION is ${GOLANG_VERSION}."
    fi

    awk -F '\t' '
        $3 == "go-module" {
            count++
            if ($1 == "" || $2 == "") bad = 1
        }
        END { exit !(count > 0 && !bad) }
    ' "${inventory}" \
        || die "Syft did not produce a complete third-party Go module inventory for vgpu-util."
}

scan_rootfs() {
    local records="$1"
    local json="${WORK_ROOT}/rootfs.syft.json"
    local include_vgpu=false
    local -a syft_args=(
        "dir:/" --scope squashed
        --source-name "nvidia-driver-container-${DISTRIBUTION}"
        --source-version "${DRIVER_LABEL}"
        -o "syft-json=${json}"
    )

    if [[ "${DRIVER_TYPE:-passthrough}" == vgpu ]]; then
        include_vgpu=true
    fi
    if [[ "${TPN_SYFT_ALL_CATALOGERS}" != 1 && "${include_vgpu}" != true ]]; then
        syft_args+=(
            --override-default-catalogers rpm-db-cataloger \
            --override-default-catalogers dpkg-db-cataloger \
            --select-catalogers=-file
        )
    fi
    log "Scanning the final root filesystem with Syft..."
    SYFT_CHECK_FOR_APP_UPDATE=false \
    SYFT_LICENSE_CONTENT=all \
    SYFT_GOLANG_SEARCH_REMOTE_LICENSES=false \
        "${SYFT}" "${syft_args[@]}"

    # Emit one normalized stream. P is a component, F is a package-owned file,
    # and L is license content supplied by Syft. Only opaque file contents and
    # paths are base64 encoded.
    "${JQ}" -r \
        --arg architecture "${ARCHITECTURE}" \
        --argjson include_vgpu "${include_vgpu}" '
        def from_vgpu:
            $include_vgpu
            and .type == "go-module"
            and any(.locations[]?;
                (.path | ltrimstr("/")) == "usr/local/bin/vgpu-util");
        def component_type:
            if .type == "go-module" and .name == "stdlib" then "go-standard-library"
            else .type end;
        def component_arch:
            (.metadata.architecture // .metadata.arch // "") as $value
            | if $value == "" then $architecture else $value end;
        def component_licenses:
            ([
                .licenses[]?
                | if (.spdxExpression // "") != "" then .spdxExpression
                  else (.value // empty) end
              ] | unique | join(" / ")) as $value
            | if $value == "" then "Unknown" else $value end;
        def package_source:
            if .type == "rpm" and (.metadata.sourceRpm // "") != ""
            then .metadata.sourceRpm
            elif .type == "deb" and (.metadata.source // "") != ""
            then .metadata.source
            else .name
            end;
        def component_purl:
            if (.purl // "") != "" then .purl
            elif .type == "go-module" then "pkg:golang/\(.name)@\(.version)"
            else "" end;
        .artifacts[] as $package
        | (
            if (($package.type == "rpm" or $package.type == "deb")
                and $package.name != "gpg-pubkey") then
                {
                    type: ($package | component_type),
                    arch: ($package | component_arch),
                    source: ($package | package_source),
                    files: true
                }
            elif (($package | from_vgpu)
                  and $package.name != "vgpu-util"
                  and $package.name != "command-line-arguments") then
                {
                    type: ($package | component_type),
                    arch: $architecture,
                    source: "",
                    files: false
                }
            else empty end
          ) as $component
        | (
            ["P", $package.name, $package.version, $component.type, $component.arch,
                ($package | component_licenses), ($package | component_purl),
                $component.source],
            (
                select($component.files)
                | (
                    ($package.metadata.files // [])[],
                    ($package.locations[]?
                        | select((.path // "")
                            | test("^/?usr/share/doc/.+/copyright"))
                        | {path: .path, flags: ""})
                  )
                | select((.path // "") != "")
                | ["F", $package.name, $package.version, $component.arch,
                    ((if (.path | startswith("/")) then .path
                      else "/" + .path end) | @base64),
                    (.flags // "")]
            ),
            (
                ($package.licenses // [] | to_entries[]?)
                | select((.value.contents // "") != "")
                | ["L", $package.name, $package.version,
                    $component.type, $component.arch, (.key | tostring),
                    (if (.value.spdxExpression // "") != ""
                     then .value.spdxExpression
                     else (.value.value // "license") end),
                    (.value.contents | @base64)]
            )
          )
        | @tsv
    ' "${json}" > "${records}"
}

process_syft_records() {
    local records="$1" inventory="$2" ownership="$3" staged="$4"
    local tag name version type package_arch field5 field6 field7
    local path flags license_id content destination decoded suffix=0
    local coverage="${PLATFORM} (${DRIVER_LABEL})"

    : > "${inventory}"
    : > "${ownership}"
    while IFS=$'\t' read -r tag name version type package_arch field5 field6 field7; do
        case "${tag}" in
            P)
                printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                    "${name}" "${version}" "${type}" "${package_arch}" \
                    "${field5}" "${field6}" "${coverage}" >> "${inventory}"
                ;;
            F)
                path="$(printf '%s' "${package_arch}" | base64 -d)"
                flags="${field5}"
                printf '%s\t%s\t%s\t%s\t%s\n' \
                    "${name}" "${version}" "${type}" "${path}" "${flags}" >> "${ownership}"
                ;;
            L)
                license_id="${field6:-license}"
                content="${field7}"
                destination="${staged}/${type}/${name}/${version}/${package_arch}/syft"
                mkdir -p "${destination}"
                decoded="${WORK_ROOT}/decoded-license"
                printf '%s' "${content}" | base64 -d > "${decoded}"
                [[ -s "${decoded}" ]] || continue
                suffix=$((suffix + 1))
                save_license_file "${decoded}" \
                    "${destination}/${field5}-$(safe_component "${license_id}").txt" \
                    "duplicate.${suffix}"
                ;;
        esac
    done < "${records}"

    LC_ALL=C sort -u -o "${ownership}" "${ownership}"
    [[ -s "${ownership}" ]] || die \
        "Syft did not emit RPM/DPKG package ownership data." \
        "Use a current Syft release with metadata.files support."
}

is_license_path() {
    local path flags base
    path="$(printf '%s' "$1" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
    flags="$(printf '%s' "$2" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
    base="${path##*/}"

    [[ "${flags}" == *l* ]] && return 0
    case "${path}" in
        /usr/share/licenses/*|/usr/share/doc/*/copyright*) return 0 ;;
    esac
    case "${base}" in
        license|license[-._]*|licence|licence[-._]*|notice|notice[-._]*|\
        copying|copying[-._]*|copyright|copyright[-._]*|authors|authors[-._]*|\
        patents|patents[-._]*) return 0 ;;
    esac
    return 1
}

save_license_file() {
    local source="$1" destination="$2" suffix="$3"
    [[ -f "${source}" ]] || return 0
    mkdir -p "$(dirname "${destination}")"
    if [[ ! -e "${destination}" ]]; then
        cp -L "${source}" "${destination}" 2>/dev/null || return 0
    elif [[ "$(hash_file "${source}")" != "$(hash_file "${destination}")" ]]; then
        cp -L "${source}" "${destination}.${suffix}" 2>/dev/null || return 0
    fi
}

path_is_package_owned() {
    local ownership="$1" wanted="$2"
    awk -F '\t' -v wanted="${wanted}" '$4 == wanted { found = 1 } END { exit !found }' "${ownership}"
}

filter_license_rows() {
    awk -F '\t' '
        {
            path = tolower($4)
            flags = tolower($5)
            if (index(flags, "l") > 0) { print; next }
            if (path ~ /^\/usr\/share\/licenses\//) { print; next }
            if (path ~ /^\/usr\/share\/doc\/.*\/copyright/) { print; next }
            n = split(path, segment, "/")
            base = segment[n]
            if (base ~ /^(license|licence|notice|copying|copyright|authors|patents)([-._]|$)/) {
                print
            }
        }
    '
}

detect_standalone_version() {
    local path="$1" expected="$2" mode="$3"
    local detected digest output

    case "${mode}" in
        binary-stderr)
            output="$("${path}" 2>&1 || true)"
            detected="$(printf '%s\n' "${output}" | sed -n 's/^version: //p' | head -n 1)"
            [[ -n "${detected}" ]] \
                || die "could not detect the version of ${path}."
            [[ -z "${expected}" || "${detected}" == "${expected}" ]] \
                || die "${path} reports ${detected}, but its manifest expects ${expected}."
            printf '%s\n' "${detected}"
            ;;
        sha256)
            digest="$(hash_file "${path}")"
            printf 'sha256:%s\n' "${digest}"
            ;;
        version-sha256)
            digest="$(hash_file "${path}")"
            [[ -n "${expected}" ]] || die "${path} needs a declared project version."
            printf '%s+sha256.%s\n' "${expected}" "${digest}"
            ;;
        *)
            die "unknown standalone version mode '${mode}' for ${path}."
            ;;
    esac
}

download_standalone_license() {
    local url="$1" mode="$2" destination="$3"
    local download

    [[ -f "${destination}" ]] && return 0
    [[ "${TPN_FETCH_UPSTREAM}" == 1 ]] || return 1
    mkdir -p "$(dirname "${destination}")"
    download="$(mktemp "${WORK_ROOT}/standalone-license.XXXXXX")"
    curl -fsSL --retry 3 "${url}" > "${download}" || {
        rm -f "${download}"
        return 1
    }

    case "${mode}" in
        file)
            mv "${download}" "${destination}"
            ;;
        c-header)
            awk 'NR == 1 && $0 == "/*" { copying = 1 }
                 copying { print }
                 copying && $0 == " */" { exit }' "${download}" > "${destination}"
            rm -f "${download}"
            if [[ ! -s "${destination}" ]]; then
                rm -f "${destination}"
                return 1
            fi
            ;;
        *)
            rm -f "${download}"
            die "unknown standalone license mode '${mode}'."
            ;;
    esac
}

collect_standalone_components() {
    local distribution="$1" ownership="$2" license_root="$3" inventory="$4"
    local manifest_distribution path name expected license url license_mode version_mode source
    local version destination coverage

    coverage="${PLATFORM} (${DRIVER_LABEL})"
    while IFS='|' read -r manifest_distribution path name expected license url license_mode version_mode source; do
        [[ "${manifest_distribution}" == "${distribution}" ]] || continue
        [[ -f "${path}" ]] || continue
        path_is_package_owned "${ownership}" "${path}" && continue

        version="$(detect_standalone_version "${path}" "${expected}" "${version_mode}")"
        destination="${license_root}/${name}/${version}/${ARCHITECTURE}/upstream/LICENSE"
        download_standalone_license "${url}" "${license_mode}" "${destination}" \
            || warn "could not download the license text for ${name} from ${url}."

        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
            "${name}" "${version}" standalone "${ARCHITECTURE}" "${license}" "${source}" "${coverage}" \
            >> "${inventory}"
    done < <(standalone_manifest)
}

directory_has_files() {
    local directory="$1"
    find "${directory}" -type f -print -quit 2>/dev/null | grep -q .
}

apply_syft_license_content() {
    local inventory="$1" staged="$2" license_root="$3"
    local name version type package_arch _licenses _purl _coverage
    local source destination

    while IFS=$'\t' read -r name version type package_arch _licenses _purl _coverage; do
        source="${staged}/${type}/${name}/${version}/${package_arch}"
        destination="${license_root}/${name}/${version}/${package_arch}"
        [[ -d "${source}" ]] || continue
        if [[ "${type}" == rpm || "${type}" == deb ]]; then
            directory_has_files "${destination}" && continue
        fi
        mkdir -p "${destination}"
        cp -R "${source}/." "${destination}/"
    done < "${inventory}"
}

collect_image_licenses() {
    local distribution="$1" ownership="$2" license_root="$3" inventory="$4"
    local name version package_arch path flags relative destination suffix
    suffix="$(safe_component "${PLATFORM}")"
    while IFS=$'\t' read -r name version package_arch path flags; do
        [[ -n "${name}" && -n "${version}" && "${path}" == /* ]] || continue
        relative="${path#/}"
        destination="${license_root}/${name}/${version}/${package_arch}/${relative}"
        save_license_file "${path}" "${destination}" "${suffix}"
    done < <(filter_license_rows < "${ownership}")

    collect_standalone_components \
        "${distribution}" "${ownership}" "${license_root}" "${inventory}"
}

component_version() {
    local inventory="$1" name="$2"
    awk -F '\t' -v name="${name}" '$1 == name { print $2; exit }' "${inventory}"
}

collect_embedded_notice() {
    local url="$1" destination="$2" mode="$3"
    local source="${WORK_ROOT}/embedded-notice-source"

    mkdir -p "$(dirname "${destination}")"
    curl -fsSL --retry 3 "${url}" > "${source}" || return 0
    case "${mode}" in
        logrus)
            awk '
                /^\/\/ The following code was sourced/ { copying = 1 }
                copying { line = $0; sub(/^\/\/ ?/, "", line); print line }
                copying && /^\/\/ CONNECTION WITH THE SOFTWARE\.$/ { exit }
            ' "${source}" > "${destination}"
            ;;
        urfave)
            awk '
                /Copyright \(c\) 2009 The Go Authors/ { copying = 1 }
                copying {
                    line = $0
                    sub(/^[[:space:]]*/, "", line)
                    sub(/[[:space:]]*$/, "", line)
                    print line
                }
                copying && /OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE\./ { exit }
            ' "${source}" > "${destination}"
            ;;
    esac
    [[ -s "${destination}" ]] || rm -f "${destination}"
}

collect_vgpu_additional_notices() {
    local inventory="$1" license_root="$2"
    local version destination

    [[ "${TPN_FETCH_UPSTREAM}" == 1 ]] || return 0

    version="$(component_version "${inventory}" stdlib)"
    destination="${license_root}/stdlib/${version}/${ARCHITECTURE}/upstream/LICENSE"
    download_standalone_license \
        "https://raw.githubusercontent.com/golang/go/${version}/LICENSE" file "${destination}" \
        || warn "could not download the Go standard library license for ${version}."

    version="$(component_version "${inventory}" github.com/sirupsen/logrus)"
    if [[ -n "${version}" ]]; then
        collect_embedded_notice \
            "https://raw.githubusercontent.com/sirupsen/logrus/${version}/alt_exit.go" \
            "${license_root}/github.com/sirupsen/logrus/${version}/${ARCHITECTURE}/syft/ATEEXIT-LICENSE" \
            logrus
    fi

    version="$(component_version "${inventory}" github.com/urfave/cli/v2)"
    if [[ -n "${version}" ]]; then
        collect_embedded_notice \
            "https://raw.githubusercontent.com/urfave/cli/${version}/sliceflag.go" \
            "${license_root}/github.com/urfave/cli/v2/${version}/${ARCHITECTURE}/syft/GO-FLAG-BSD-LICENSE" \
            urfave
    fi
}

collapse_inventory() {
    LC_ALL=C sort -t $'\t' -k1,1 -k2,2 -k3,3 -k4,4 -k5,5 -k7,7 -u "$1" | awk -F '\t' '
        {
            key = $1 SUBSEP $2 SUBSEP $3 SUBSEP $4
            if (!(key in present)) {
                present[key] = 1; order[++count] = key
                name[key] = $1; version[key] = $2; type[key] = $3
                architecture[key] = $4; purl[key] = $6
            }
            if (!((key SUBSEP $5) in license_seen)) {
                license_seen[key SUBSEP $5] = 1
                licenses[key] = licenses[key] (licenses[key] == "" ? "" : " / ") $5
            }
            if (!((key SUBSEP $7) in coverage_seen)) {
                coverage_seen[key SUBSEP $7] = 1
                coverage[key] = coverage[key] (coverage[key] == "" ? "" : ", ") $7
            }
        }
        END {
            OFS = "\t"
            for (i = 1; i <= count; i++) {
                key = order[i]
                print name[key], version[key], type[key], architecture[key], licenses[key], purl[key], coverage[key]
            }
        }
    '
}

fence_for() {
    local file="$1" longest width
    longest=$( (LC_ALL=C grep -oaE '`+' "${file}" 2>/dev/null || true) \
        | awk '{ if (length($0) > max) max = length($0) } END { print max+0 }')
    width=$((longest + 1))
    (( width < 3 )) && width=3
    printf '%*s' "${width}" '' | tr ' ' '`'
}

materialize_text() {
    local source="$1" destination="$2"
    case "${source}" in
        *.gz)
            command -v gzip >/dev/null 2>&1 || return 1
            gzip -cd "${source}" > "${destination}" 2>/dev/null
            ;;
        *.xz)
            command -v xz >/dev/null 2>&1 || return 1
            xz -cd "${source}" > "${destination}" 2>/dev/null
            ;;
        *.bz2)
            command -v bzip2 >/dev/null 2>&1 || return 1
            bzip2 -cd "${source}" > "${destination}" 2>/dev/null
            ;;
        *.zst|*.zstd)
            command -v zstd >/dev/null 2>&1 || return 1
            zstd -qcd "${source}" > "${destination}" 2>/dev/null
            ;;
        *)
            cp "${source}" "${destination}"
            ;;
    esac
}

emit_sections() {
    local index="$1" license_root="$2"
    local name version type architecture licenses _purl _coverage
    local package_root file relative text fence digest
    local hashes="${WORK_ROOT}/emitted-hashes"

    while IFS=$'\t' read -r name version type architecture licenses _purl _coverage; do
        printf '### %s %s (%s)\n\n' "${name}" "${version}" "${architecture}"
        printf '* License: %s\n' "${licenses}"
        printf '* Package type: %s\n' "${type}"
        printf '* Architecture: %s\n\n' "${architecture}"

        package_root="${license_root}/${name}/${version}/${architecture}"
        : > "${hashes}"
        if ! find "${package_root}" -type f -print -quit 2>/dev/null | grep -q .; then
            printf 'License text unavailable. See the package source for the full license.\n\n'
            continue
        fi

        while IFS= read -r -d '' file; do
            digest="$(hash_file "${file}")"
            grep -Fqx "${digest}" "${hashes}" && continue
            printf '%s\n' "${digest}" >> "${hashes}"

            relative="${file#${package_root}/}"
            text="${WORK_ROOT}/license-text"
            if ! materialize_text "${file}" "${text}"; then
                printf '#### %s\n\n' "${relative}"
                printf 'License text is stored in a compression format this image cannot decode.\n\n'
                continue
            fi
            fence="$(fence_for "${text}")"
            printf '#### %s\n\n' "${relative}"
            printf '%stext\n' "${fence}"
            cat "${text}"
            [[ ! -s "${text}" || $(tail -c 1 "${text}" | wc -l) -eq 1 ]] || printf '\n'
            printf '%s\n\n' "${fence}"
            rm -f "${text}"
        done < <(find "${package_root}" -type f -print0 | LC_ALL=C sort -z)
    done < "${index}"
}

compose_document() {
    local index="$1" license_root="$2"
    local output="${OUTPUT_DIR}/${DOCUMENT_NAME}"
    local temporary="${output}.tmp"
    local name version type architecture licenses _purl _coverage

    log "Composing ${output}..."
    {
        printf '# Third-Party Notices\n\n'
        printf 'NVIDIA GPU driver container %s for %s\n\n' "${DRIVER_LABEL}" "${DISTRIBUTION}"
        printf 'This document covers packages discovered by Syft plus manifested standalone\n'
        printf 'components present in this final %s root filesystem. Build-stage-only\n' "${PLATFORM}"
        printf 'components are excluded.\n\n'

        if [[ "${DRIVER_TYPE:-}" == vgpu ]]; then
            printf '**Scope limitation:** A release-specific vGPU/GRID driver `.run` payload is\n'
            printf 'supplied separately and is not covered by this document.\n\n'
        fi

        printf '## Dependency Index\n\n'
        printf '| Package | Version | Type | Architecture | License |\n'
        printf '|---------|---------|------|--------------|---------|\n'
        while IFS=$'\t' read -r name version type architecture licenses _purl _coverage; do
            printf '| `%s` | `%s` | %s | `%s` | %s |\n' \
                "${name}" "${version}" "${type}" "${architecture}" "${licenses}"
        done < "${index}"
        printf '\n## License Texts\n\n'
        emit_sections "${index}" "${license_root}"
    } > "${temporary}"

    chmod 644 "${temporary}"
    mv "${temporary}" "${output}"
    cp "${index}" "${OUTPUT_DIR}/${INVENTORY_NAME}"
    chmod 644 "${OUTPUT_DIR}/${INVENTORY_NAME}"
}

report_gaps() {
    local index="$1" license_root="$2"
    local name version _type architecture licenses _purl _coverage
    local missing=0 unknown=0

    while IFS=$'\t' read -r name version _type architecture licenses _purl _coverage; do
        [[ "${licenses}" =~ (^| / )(Unknown|NOASSERTION)( / |$) ]] \
            && unknown=$((unknown + 1))
        if ! directory_has_files "${license_root}/${name}/${version}/${architecture}"; then
            missing=$((missing + 1))
            printf 'no license text for %s %s (%s)\n' \
                "${name}" "${version}" "${architecture}" >&2
        fi
    done < "${index}"

    (( unknown == 0 )) || warn "Syft reported an unknown license for ${unknown} component(s)."
    (( missing == 0 )) \
        || warn "${missing} of $(wc -l < "${index}" | tr -d ' ') components have no license text."
}

main() {
    local records raw_inventory ownership staged_content
    local license_root index
    local command

    for command in "${SYFT}" "${JQ}" base64 curl awk sort grep find mktemp sha256sum; do
        require_command "${command}"
    done
    check_boolean TPN_SYFT_ALL_CATALOGERS "${TPN_SYFT_ALL_CATALOGERS}"
    check_boolean TPN_FETCH_UPSTREAM "${TPN_FETCH_UPSTREAM}"
    check_boolean TPN_STRICT "${TPN_STRICT}"

    detect_distribution
    detect_architecture
    PLATFORM="linux/${ARCHITECTURE}"
    DRIVER_LABEL="${DRIVER_VERSION:-unknown}"

    WORK_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/in-image-tpn.XXXXXX")"
    records="${WORK_ROOT}/syft-records.tsv"
    raw_inventory="${WORK_ROOT}/inventory.tsv"
    ownership="${WORK_ROOT}/ownership.tsv"
    staged_content="${WORK_ROOT}/syft-license-content"
    license_root="${WORK_ROOT}/licenses"
    index="${WORK_ROOT}/index.tsv"
    mkdir -p "${license_root}" "${staged_content}" "${OUTPUT_DIR}"

    scan_rootfs "${records}"
    process_syft_records \
        "${records}" "${raw_inventory}" "${ownership}" "${staged_content}"
    if [[ "${DRIVER_TYPE:-passthrough}" == vgpu ]]; then
        validate_vgpu_binary_modules "${raw_inventory}"
    fi

    collect_image_licenses \
        "${DISTRIBUTION}" "${ownership}" "${license_root}" "${raw_inventory}"
    apply_syft_license_content "${raw_inventory}" "${staged_content}" "${license_root}"
    if [[ "${DRIVER_TYPE:-passthrough}" == vgpu ]]; then
        collect_vgpu_additional_notices "${raw_inventory}" "${license_root}"
    fi

    collapse_inventory "${raw_inventory}" > "${index}"
    [[ -s "${index}" ]] || die "Syft produced an empty component index."

    report_gaps "${index}" "${license_root}"
    compose_document "${index}" "${license_root}"

    log "Wrote ${OUTPUT_DIR}/${DOCUMENT_NAME} covering $(wc -l < "${index}" | tr -d ' ') components."
    if (( WARNINGS > 0 )); then
        if [[ "${TPN_STRICT}" == 1 ]]; then
            die "${WARNINGS} warning(s) were raised and TPN_STRICT=1."
        fi
        log "${WARNINGS} warning(s) were raised; set TPN_STRICT=1 to treat these as fatal."
    fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
