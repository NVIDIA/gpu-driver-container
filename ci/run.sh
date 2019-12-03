#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

export TF_IN_AUTOMATION=yes

DRIVER_VERSION=${DRIVER_VERSION:-418.87.01}
FORCE=${FORCE:-}
REGISTRY=${REGISTRY:-nvidia/driver}
SSH_KEY=${SSH_KEY:-${HOME}/.ssh/id_rsa}

UBUNTU_VERSIONS=${UBUNTU_VERSIONS:-"16.04 18.04"}
CENTOS_VERSIONS=${CENTOS_VERSIONS:-"7"}

log() {
  echo -e "\033[1;32m[+] $*\033[0m"
}

get_tags() {
  curl -fsSL "https://registry.hub.docker.com/v1/repositories/${REGISTRY}/tags" \
  | jq -r '.[] | .name'
}

tag_exists() {
  grep -q "${1}" <<< "${2}"
}

latest_ubuntu_kernel() {
  docker run --rm ubuntu:"${1}" /bin/bash -c\
    "apt update &> /dev/null && apt-cache show linux-headers-${2} 2>> /dev/null \
      | sed -nE 's/^Version:\s+(([0-9]+\.){2}[0-9]+)[-.]([0-9]+).*/\1-\3/p' \
      | head -n 1"
}

latest_centos_kernel() {
  docker run --rm centos:"${1}" /bin/bash -c\
    "yum install -y yum-utils &> /dev/null && repoquery kernel-headers \
      | cut -d ':' -f 2"
}

latest_rhel_kernel() {
  if [[ "${1}" -eq 7 ]]; then
    docker run --rm centos:"${1}" /bin/bash -c\
      "yum install -y yum-utils &> /dev/null && repoquery kernel-headers \
        | cut -d ':' -f 2"
  elif [[ "${1}" -eq 8 ]]; then
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
  public_ip=${public_ip_ubuntu16_04}

  docker_ssh build -t "${REGISTRY}:${image_tag_long}" \
                   --build-arg KERNEL_VERSION="${kernel_version}" \
                   --build-arg DRIVER_VERSION="${DRIVER_VERSION}" \
                   "https://gitlab.com/nvidia/container-images/driver.git#master:${1}"

  docker_ssh save "${REGISTRY}:${image_tag_long}" -o "${image_tag_long}.tar"

  docker load -i "${image_tag_long}.tar"
  docker tag "${REGISTRY}:${image_tag_long}" "${REGISTRY}:${image_tag_short}"

  docker push "${REGISTRY}:${image_tag_long}"
  docker push "${REGISTRY}:${image_tag_short}"

  docker_ssh container prune
  docker_ssh image prune -a

  docker container prune
  docker image prune -a
}

cleanup() {
  log 'Cleanup'
  terraform destroy -force -input=false
}

trap cleanup EXIT

cat << EOF > terraform.tfvars
ssh_key_pub = "${SSH_KEY}.pub"
ssh_host_key = "${SSH_HOST_KEY_PATH}"
ssh_host_key_pub = "${SSH_HOST_KEY_PUB_PATH}"
EOF

log 'Creating AWS resources'
terraform apply -auto-approve
public_ip_ubuntu16_04=$(terraform output public_ip_ubuntu16_04)
public_ip_coreos=$(terraform output public_ip_coreos)

log 'Add instance to known hosts'
# shellcheck disable=SC2086
echo "${public_ip_ubuntu16_04} $(cat ${SSH_HOST_KEY_PUB_PATH})" >> "${HOME}/.ssh/known_hosts"
# shellcheck disable=SC2086
echo "${public_ip_coreos} $(cat ${SSH_HOST_KEY_PUB_PATH})" >> "${HOME}/.ssh/known_hosts"

log 'Get tags'
tags=$(get_tags)


# Resolving Ubuntu versions
for version in ${UBUNTU_VERSIONS}; do
  log "Detecting versions for Ubuntu ${version}"
  generic_kernel=$(latest_ubuntu_kernel "${version}" generic)
  hwe_kernel=$(latest_ubuntu_kernel "${version}" "generic-hwe-${version}")
  aws_kernel=$(latest_ubuntu_kernel "${version}" aws)

  log "Generating tags for Ubuntu ${version}"
  generic_tag_long=${DRIVER_VERSION}-${generic_kernel}-ubuntu${version}
  hwe_tag_long=${DRIVER_VERSION}-${hwe_kernel}-ubuntu${version}-hwe
  aws_tag_long=${DRIVER_VERSION}-${aws_kernel}-ubuntu${version}-aws

  if [[ -n ${FORCE} ]] || ! tag_exists "${generic_tag_long}" "${tags}"; then
    log 'Building generic image'

    kernel_version=${generic_kernel}
    image_tag_long=${generic_tag_long}
    image_tag_short=${DRIVER_VERSION}-ubuntu${version}

    build "ubuntu${version}"
  fi

  if [[ -n ${FORCE} ]] || ! tag_exists "${hwe_tag_long}" "${tags}"; then
    log 'Building HWE image'

    kernel_version=${hwe_kernel}
    image_tag_long=${hwe_tag_long}
    image_tag_short=${DRIVER_VERSION}-ubuntu${version}-hwe

    build "ubuntu${version}"
  fi

  if [[ -n ${FORCE} ]] || ! tag_exists "${aws_tag_long}" "${tags}"; then
    log 'Building AWS image'

    kernel_version=${aws_kernel}-aws
    image_tag_long=${aws_tag_long}
    image_tag_short=${DRIVER_VERSION}-ubuntu${version}-aws

    build "ubuntu${version}"
  fi
done

# Resolving Centos versions
for version in ${CENTOS_VERSIONS}; do
  log "Detecting versions for Centos ${version}"
  centos_kernel=$(latest_centos_kernel "${version}")

  log "Generating tags for Centos ${version}"
  centos_tag_long=${DRIVER_VERSION}-${centos_kernel}-centos${version}

  if [[ -n ${FORCE} ]] || ! tag_exists "${centos_tag_long}" "${tags}"; then
    log "Building CentOS image version ${version}"

    kernel_version=${centos_kernel}
    image_tag_long=${centos_tag_long}
    image_tag_short=${DRIVER_VERSION}-centos${version}

    build "centos${version}"
  fi
done

kernel_version=""
image_tag_long=${DRIVER_VERSION}-rhel7
image_tag_short=${DRIVER_VERSION}-rhel7
build "rhel7"

image_tag_long=${DRIVER_VERSION}-rhel8
image_tag_short=${DRIVER_VERSION}-rhel8
build "rhel8"

image_tag_long=${DRIVER_VERSION}-rhcos
image_tag_short=${DRIVER_VERSION}-rhcos
build "rhcos"

# Resolving CoreOS version
coreos_kernel=$(ssh "nvidia@${public_ip_coreos}" uname -r)
coreos_tag_long=${DRIVER_VERSION}-${coreos_kernel}-coreos
if [[ -n ${FORCE} ]] || ! tag_exists "${coreos_tag_long}" "${tags}"; then
    log 'Building CoreOS image'
    # shellcheck disable=SC2029
    ssh "nvidia@${public_ip_coreos}" /home/nvidia/build.sh "${DRIVER_VERSION}" "${REGISTRY}"
    # shellcheck disable=SC2029
    scp "nvidia@${public_ip_coreos}:/home/nvidia/${coreos_tag_long}.tar" .

    docker load -i "${coreos_tag_long}.tar"
    docker push "${REGISTRY}:${coreos_tag_long}"
fi
