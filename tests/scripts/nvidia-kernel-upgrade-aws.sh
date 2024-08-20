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

KERNEL_VERSION=${TARGET_DRIVER_VERSION}-generic
echo ""
echo ""
echo "--------------Starting the Precompiled kernel version ${KERNEL_VERSION} upgrade--------------"

# sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
# sudo add-apt-repository \
#        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
#        $(lsb_release -cs) \
#        test"

sudo apt-get update -y
sudo apt-cache search linux-image
# SHIVA
# sudo apt-get install linux-image-${KERNEL_VERSION}
sudo apt-get install linux-image-5.15.0-118-generic -y
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
