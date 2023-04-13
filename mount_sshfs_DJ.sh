#!/bin/bash
set -e #exit on all errors
set -x #print commands as executed

export LOCAL_PATH="/Users/fernando/mnt/DJ_sshfs"
export USERNAME="fersanchez"
export REMOTE_PATH="/mnt/pool01/DJ"
export REMOTE_HOST="fersanchez.ddns.net"
export REMOTE_PORT=6129
mkdir -pv ${LOCAL_PATH}
sshfs -p ${REMOTE_PORT} ${USERNAME}@${REMOTE_HOST}:${REMOTE_PATH} ${LOCAL_PATH}
