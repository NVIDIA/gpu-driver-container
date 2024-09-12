#!/bin/bash

if [[ "${SKIP_INSTALL}" == "true" ]]; then
    echo "Skipping install: SKIP_INSTALL=${SKIP_INSTALL}"
    exit 0
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}"/.definitions.sh

echo "Checking current kernel version..."
CURRENT_KERNEL=$(uname -r)
echo "Current kernel version: $CURRENT_KERNEL"

if [ "${CURRENT_KERNEL}" != ${KERNEL_VERSION} ]; then
  echo ""
  echo ""
  echo "--------------Upgrading kernel to ${KERNEL_VERSION}--------------"

  # Set non-interactive frontend for apt and disable editor prompts
  # Perform the installation non-interactively
  export DEBIAN_FRONTEND=noninteractive
  export EDITOR=/bin/true
  echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections

  sudo apt-get update -y || true

  # The removal of the currently running kernel (apt remove linux-image-*) sometimes works and sometimes does not.
  # Occasionally, it requires two reboots, or an apt upgrade. However, removing all traces of the old/current
  # kernel from the boot directory works consistently, which is why this approach has been adopted.
  sudo rm -rf /boot/*${CURRENT_KERNEL}* || true
  sudo rm -rf /lib/modules/*${CURRENT_KERNEL}*
  sudo rm -rf /boot/*.old

  #install new kernel
  sudo  apt-get install --allow-downgrades linux-image-${KERNEL_VERSION} linux-headers-${KERNEL_VERSION}  linux-modules-${KERNEL_VERSION} -y || exit 1
  if [ $? -ne 0 ]; then
    echo "Kernel upgrade failed."
    exit 1
  fi
  echo "update grub and initramfs..."
  sudo update-grub || true
  sudo update-initramfs -u -k ${KERNEL_VERSION} || true
  echo "Rebooting ..."
  # Run the reboot command with nohup to avoid abrupt SSH closure issues
  nohup sudo reboot &

  echo "--------------Kernel upgrade completed--------------"
else
  echo "--------------Kernel upgrade not required, current kernel version ${KERNEL_VERSION}--------------"
fi

# Exit with a success code since the reboot command was issued successfully
exit 0
