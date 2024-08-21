#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/.definitions.sh
source ${SCRIPT_DIR}/.local.sh

try_ssh_connection() {
    ssh -o ConnectTimeout=10 -i ${private_key} ${instance_hostname} "exit"
    return $?
}

echo "Waiting for aws system to come back online..."
START_TIME=$(date +%s)
while true; do
    sleep 60 # sleep before as system restarted earlier
    try_ssh_connection
    if [ $? -eq 0 ]; then
        echo "Successfully connected to aws system after reboot."
        break;
    fi
    ELAPSED_TIME=$(($(date +%s) - START_TIME))
    if [ "$ELAPSED_TIME" -ge "$SYSTEM_ONLINE_CHECK_TIMEOUT" ]; then
        echo "Failed to connect to aws within ${SYSTEM_ONLINE_CHECK_TIMEOUT} minutes after reboot."
        exit 1
    fi
    echo "ssh retry again..."
done
