#!/usr/env bash

function remote() {
    ${SCRIPT_DIR}/remote.sh "cd ${PROJECT} && "$@""
}

function remote_retry() {
    ${SCRIPT_DIR}/remote_retry.sh
}
