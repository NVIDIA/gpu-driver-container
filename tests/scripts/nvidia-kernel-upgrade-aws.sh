#!/bin/bash

if [[ "${SKIP_INSTALL}" == "true" ]]; then
    echo "Skipping install: SKIP_INSTALL=${SKIP_INSTALL}"
    exit 0
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "${SCRIPT_DIR}"/.definitions.sh

# finding kernel version
${SCRIPT_DIR}/findkernelversion.sh
source "${SCRIPT_DIR}"/kernel_version.txt 

echo "Checking current kernel version..."
CURRENT_KERNEL=$(uname -r)
echo "Current kernel version: $CURRENT_KERNEL"

echo ""
echo ""
echo "--------------Starting the Precompiled kernel version ${KERNEL_VERSION} upgrade--------------"

sudo apt-get update -y
sudo apt-get install linux-image-${KERNEL_VERSION} -y
if [ $? -ne 0 ]; then
  echo "Kernel upgrade failed."
  exit 1
fi

echo "Checking the upgraded kernel version ${KERNEL_VERSION}..."
CURRENT_KERNEL=$(uname -r)
echo "Upgraded kernel version: $CURRENT_KERNEL"

echo "update grub ..."
sudo update-grub
echo "Rebooting ..."
# Run the reboot command with nohup to avoid abrupt SSH closure issues
nohup sudo reboot &

echo "--------------Installation of kernel completed --------------"

# Exit with a success code since the reboot command was issued successfully
exit 0
