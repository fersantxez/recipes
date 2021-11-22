#!/bin/bash
#https://cloud.google.com/storage/docs/gsutil/commands/rsync

#export FILE_OR_DIR={CWD}"/*"
export FILE_OR_DIR=$1
#export DEST_GCS_PATH="gs://MYBUCKET/"
export DEST_GCS_PATH=$2

echo "*** INFO: Recursively rsyncing "${FILE_OR_DIR}" to "${DEST_GCS_PATH}

gsutil \
-m \
\
rsync \
-r \
-d \
-P \
-U \
${FILE_OR_DIR} \
${DEST_GCS_PATH}
