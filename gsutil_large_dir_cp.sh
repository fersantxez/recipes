#!/bin/bash
#export FILE_OR_DIR={CWD}"/*"
export FILE_OR_DIR=$1
#export DEST_GCS_PATH="gs://MYBUCKET/"
export DEST_GCS_PATH=$2

echo "*** INFO: Recursively copying "${FILE_OR_DIR}" to "${DEST_GCS_PATH}

gsutil \
-m \
-o GSUtil:parallel_composite_upload_threshold=150M \
-o GSUtil:parallel_thread_count=16 \
-o GSUtil:sliced_object_download_max_components=8 \
\
cp \
-r \
-P \
${FILE_OR_DIR} \
${DEST_GCS_PATH}
