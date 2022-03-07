#!/bin/bash

set -x #DEBUG

export KEYPATH="PATH_TO_MY_JSON_KEY_FILE.json"
export SOURCE_BUCKET="MYBUCKET" #NOT gs://MYBUCKET/
export DEST_DIR="/home/myuser/MYDIR/"
export OPTIONS="rw,nosuid,nodev"

#umount with:
fusermount -u $DEST_DIR

gcsfuse \
--key-file ${KEYPATH} \
--dir-mode 755 \
--file-mode 755 \
--implicit-dirs \
-o ${OPTIONS} \
${SOURCE_BUCKET} \
${DEST_DIR}

#--debug_fuse \
#--debug_gcs \
#--foreground


