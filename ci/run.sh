#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

export TF_IN_AUTOMATION=yes

if [ -z "$DRIVER_VERSION" ]; then
  echo "Driver Version must be specified with environment variable DRIVER_VERSION" >&2
  exit 1
fi

CONTAINER_VERSION=${DRIVER_VERSION}-${CI_COMMIT_TAG}

FORCE=${FORCE:-}
if [ -z "$REGISTRY" ]; then
  REGISTRY=nvidia/driver
fi
SSH_KEY=${SSH_KEY:-${HOME}/.ssh/id_rsa}

UBUNTU_VERSIONS=${UBUNTU_VERSIONS:-"16.04 18.04 20.04"}

mk_long_version() {
  local -r linux_version="${1}" platform="${2}"
  echo "${DRIVER_VERSION}-${CI_COMMIT_TAG}-${linux_version}-${platform}"
}

mk_short_version() {
  local -r platform="${1}"
  echo "${DRIVER_VERSION}-${platform}"
}

log() {
  echo -e "\\033[1;32m[+] $*\\033[0m"
}

get_tags() {
  # git tag --points-at HEAD
  git describe --tags HEAD
}

tag_exists() {
  grep -q "${1}" <<< "${2}"
}

latest_ubuntu_kernel() {
  docker run --rm ubuntu:"${1}" /bin/bash -c\
    "apt update &> /dev/null && apt-cache show linux-headers-${2} 2>> /dev/null \
      | sed -nE 's/^Version:\\s+(([0-9]+\\.){2}[0-9]+)[-.]([0-9]+).*/\\1-\\3/p' \
      | head -n 1"
}

latest_rhel_kernel() {
  if [[ "${1}" -eq 7 ]]; then
    docker run --rm centos:"${1}" /bin/bash -c\
      "yum install -y yum-utils &> /dev/null && repoquery kernel-headers \
        | cut -d ':' -f 2 \
        | tail -n 1"
  elif [[ "${1}" -eq 8 || "${1}" -eq 9 ]]; then
    docker run --rm centos:"${1}" /bin/bash -c\
      "dnf repoquery -q --latest-limit 1 kernel-headers \
        | cut -d ':' -f 2 | head -n 1"
  else
    exit 1
  fi
}

docker_ssh() {
  docker -H "ssh://nvidia@${public_ip}" "${@}"
}

build() {
  local -r platform="${1}" long_version="${2}" short_version="${3}" kernel_version="${4}"
  log "Building image: $*"

  public_ip=${public_ip_ubuntu16_04}

  docker_ssh build -t "${REGISTRY}:${long_version}" \
                   --build-arg KERNEL_VERSION="${kernel_version}" \
                   --build-arg DRIVER_VERSION="${DRIVER_VERSION}" \
                   "${CI_REPOSITORY_URL}#${CI_COMMIT_REF_NAME}:${platform}"

  docker_ssh save "${REGISTRY}:${long_version}" -o "${long_version}.tar"

  docker load -i "${long_version}.tar"
  docker tag "${REGISTRY}:${long_version}" "${REGISTRY}:${short_version}"

  docker push "${REGISTRY}:${long_version}"
  docker push "${REGISTRY}:${short_version}"

  docker_ssh container prune
  docker_ssh image prune -a

  docker container prune
  docker image prune -a

  rm -f "${long_version}.tar"
}

cleanup() {
  log 'Cleanup'
  terraform destroy -force -input=false
}

trap cleanup EXIT

log "DRIVER VERSION: ${DRIVER_VERSION}"
log "CONTAINER VERSION: ${CONTAINER_VERSION}"
log "REGISTRY: ${REGISTRY}"
log "FORCE: ${FORCE}"
log "CI_PIPELINE_ID: ${CI_PIPELINE_ID}"

cat << EOF > terraform.tfvars
ssh_key_pub = "${SSH_KEY}.pub"
project_name = "driver"
ci_pipeline_id = "${CI_PIPELINE_ID}"
EOF

log 'Creating AWS resources'
terraform apply -auto-approve
public_ip_ubuntu16_04=$(terraform output public_ip_ubuntu16_04)
public_ip_flatcar=$(terraform output public_ip_flatcar)

log 'Add instance to known hosts'
# shellcheck disable=SC2086
ssh-keyscan -H "${public_ip_ubuntu16_04}" >> "${HOME}/.ssh/known_hosts"
ssh-keyscan -H "${public_ip_flatcar}" >> "${HOME}/.ssh/known_hosts"

log 'Get tags'
tags=$(get_tags)


# Resolving Ubuntu versions
for version in ${UBUNTU_VERSIONS}; do
  log "Generating tags for Ubuntu ${version}"

  generic_kernel=$(latest_ubuntu_kernel "${version}" generic)
  generic_tag_long="$(mk_long_version "${generic_kernel}" "ubuntu${version}")"

  if [[ -n ${FORCE} ]] || ! tag_exists "${generic_tag_long}" "${tags}"; then
    generic_tag_short="$(mk_short_version "ubuntu${version}")"
    build "ubuntu${version}" "${generic_tag_long}" "${generic_tag_short}" "${generic_kernel}-generic"
  fi

  hwe_kernel=$(latest_ubuntu_kernel "${version}" "generic-hwe-${version}")
  hwe_tag_long="$(mk_long_version "${hwe_kernel}" "ubuntu${version}-hwe")"

  if [[ -n ${FORCE} ]] || ! tag_exists "${hwe_tag_long}" "${tags}"; then
    # HWE kernel seems to have the same kernel headers as the generic one
    # See the package description for reference:
    # https://packages.ubuntu.com/bionic-updates/linux-headers-generic-hwe-18.04
    hwe_tag_short="$(mk_short_version "ubuntu${version}-hwe")"
    build "ubuntu${version}" "${hwe_tag_long}" "${hwe_tag_short}" "${hwe_kernel}-generic"
  fi

  aws_kernel=$(latest_ubuntu_kernel "${version}" aws)
  aws_tag_long="$(mk_long_version "${aws_kernel}" "ubuntu${version}-aws")"

  if [[ -n ${FORCE} ]] || ! tag_exists "${aws_tag_long}" "${tags}"; then
    aws_tag_short="$(mk_short_version "ubuntu${version}-aws")"
    build "ubuntu${version}" "${aws_tag_long}" "${aws_tag_short}" "${aws_kernel}-aws"
  fi
done

build "rhel7" "${CONTAINER_VERSION}-rhel7" "$(mk_short_version rhel7)" ""
build "rhel8" "${CONTAINER_VERSION}-rhel8" "$(mk_short_version rhel8)" ""
build "rhel9" "${CONTAINER_VERSION}-rhel9" "$(mk_short_version rhel9)" ""

# Add rhcos tags
docker pull "${REGISTRY}:${CONTAINER_VERSION}-rhel8"

for tag in "4.1" "4.2" "4.3" "4.4"; do
	docker tag "${REGISTRY}:${CONTAINER_VERSION}-rhel8" "${REGISTRY}:${DRIVER_VERSION}-rhcos${tag}"
	docker push "${REGISTRY}:${DRIVER_VERSION}-rhcos${tag}"
done

docker container prune
docker image prune -a
