#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source ${SCRIPT_DIR}/.definitions.sh
source ${SCRIPT_DIR}/.local.sh

# keep alive 60sec and timeout after 30 tries
ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=30 -i ${private_key} ${instance_hostname} "${@}"
