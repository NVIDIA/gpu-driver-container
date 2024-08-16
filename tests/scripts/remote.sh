#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/.definitions.sh
source ${SCRIPT_DIR}/.local.sh

# keep alive 60sec and timeout after 30 tries
ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=30 -i ${private_key} ${instance_hostname} "${@}"
SSH_PID=$!
wait $SSH_PID

if [ "${SSH_RETRY}" == "1" ]; then
    echo "Waiting for aws system to come back online..."
    START_TIME=$(date +%s)
    while true; do
        ssh -o ConnectTimeout=5 -i ${private_key} ${instance_hostname} "exit"
        if [ $? -eq 0 ]; then
            echo "Successfully connected to aws system after reboot."
            exit 0
        fi
        ELAPSED_TIME=$(($(date +%s) - START_TIME))
        if [ "$ELAPSED_TIME" -ge "$SYSTEM_ONLINE_CHECK_TIMEOUT" ]; then
            echo "Failed to connect to aws within ${SYSTEM_ONLINE_CHECK_TIMEOUT} minutes after reboot."
            exit 1
        fi
        sleep 60
    done
fi
