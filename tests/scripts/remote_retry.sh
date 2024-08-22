#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/.definitions.sh
INTERVAL=30
SECONDS_ELAPSED=0

set +e
# Function to handle timeout exit
handle_timeout() {
  echo "Failed to connect within the timeout period of $SYSTEM_ONLINE_CHECK_TIMEOUT seconds."
  exit 1
}

# Set trap for timeout
trap handle_timeout EXIT

# sleep before to handle restart of the system
sleep 60;

while [ $SECONDS_ELAPSED -lt $SYSTEM_ONLINE_CHECK_TIMEOUT ]; do
 # Attempt to connect via SSH and ignore errors
 status=0
  (
    ssh -o ConnectTimeout=5 -i ${private_key}  ${instance_hostname} "exit"
  ) >/dev/null 2>&1
  status=$?
  if [ $status -eq 0 ]; then
    echo "Successfully connected to ${instance_hostname}."
    trap - EXIT  # Disable the timeout trap since the connection was successful
    exit 0
  fi
  sleep $INTERVAL
  SECONDS_ELAPSED=$((SECONDS_ELAPSED + INTERVAL))
  echo "ssh retry...elpased time $SECONDS_ELAPSED"
done
