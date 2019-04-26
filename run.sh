#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail
set -o xtrace

export TF_IN_AUTOMATION=yes

DRIVER_VERSION=${DRIVER_VERSION:-418.40.04}
FORCE=${FORCE:-}
REGISTRY=${REGISTRY:-nvidia}
SSH_KEY=${SSH_KEY:-${HOME}/.ssh/id_rsa}

log() {
  echo -e "\033[1;32m[+] $*\033[0m"
}

get_tags() {
  curl -fsSL 'https://registry.hub.docker.com/v1/repositories/nvidia/driver/tags' \
  | jq -r '.[] | .name'
}

tag_exists() {
  grep -q "${1}" <<< "${2}"
}

latest_ubuntu_kernel() {
  apt-get update &> /dev/null

  apt-cache show "linux-headers-${1}" 2>> /dev/null \
    | sed -nE 's/^Version:\s+(([0-9]+\.){2}[0-9]+)[-.]([0-9]+).*/\1-\3/p' \
    | head -n 1
}

latest_centos_kernel() {
  repoquery kernel-headers | cut -d ':' -f 2
}

docker_ssh() {
  docker -H "ssh://nvidia@${public_ip}" "${@}"
}

build() {
  docker_ssh build -t "${REGISTRY}:${image_tag_long}" \
                   --build-arg KERNEL_VERSION="${kernel_version}" \
                   --build-arg DRIVER_VERSION="${DRIVER_VERSION}" \
                   "https://gitlab.com/nvidia/driver.git#${1}"

  docker_ssh save "${REGISTRY}:${image_tag_long}" -o "${image_tag_long}.tar"

  docker load -i "${image_tag_long}.tar"
  docker tag "${REGISTRY}:${image_tag_long}" "${REGISTRY}:${image_tag_short}"

  docker push "${REGISTRY}:${image_tag_long}"
  docker push "${REGISTRY}:${image_tag_short}"
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
public_ip=$(terraform output public_ip)

log 'Add instance to known hosts'
# shellcheck disable=SC2086
echo "${public_ip} $(cat ${SSH_HOST_KEY_PUB_PATH})" >> "${HOME}/.ssh/known_hosts"

log 'Detecting versions'
generic_kernel=$(latest_ubuntu_kernel generic)
hwe_kernel=$(latest_ubuntu_kernel generic-hwe-16.04)
aws_kernel=$(ssh "nvidia@${public_ip}" uname -r)
centos_kernel=$(latest_centos_kernel)

log 'Generating tags'
generic_tag_long=${DRIVER_VERSION}-${generic_kernel}-ubuntu16.04
hwe_tag_long=${DRIVER_VERSION}-${hwe_kernel}-ubuntu16.04
aws_tag_long=${DRIVER_VERSION}-${aws_kernel}-ubuntu16.04
centos_tag_long=${DRIVER_VERSION}-${centos_kernel}-centos7

tags=$(get_tags)

if [[ -n ${FORCE} ]] || ! tag_exists "${generic_tag_long}" "${tags}"; then
  log 'Building generic image'

  kernel_version=${generic_kernel}
  image_tag_long=${generic_tag_long}
  image_tag_short=${DRIVER_VERSION}-ubuntu16.04

  build ubuntu16.04
fi

if [[ -n ${FORCE} ]] || ! tag_exists "${hwe_tag_long}" "${tags}"; then
  log 'Building HWE image'

  kernel_version=${hwe_kernel}
  image_tag_long=${hwe_tag_long}
  image_tag_short=${DRIVER_VERSION}-ubuntu16.04-hwe

  build ubuntu16.04
fi

if [[ -n ${FORCE} ]] || ! tag_exists "${aws_tag_long}" "${tags}"; then
  log 'Building AWS image'

  kernel_version=${aws_kernel}
  image_tag_long=${aws_tag_long}
  image_tag_short=${DRIVER_VERSION}-ubuntu16.04-aws

  build ubuntu16.04
fi

if [[ -n ${FORCE} ]] || ! tag_exists "${centos_tag_long}" "${tags}"; then
  log 'Building CentOS image'

  kernel_version=${centos_kernel}
  image_tag_long=${centos_tag_long}
  image_tag_short=${DRIVER_VERSION}-centos7

  build centos7
fi
