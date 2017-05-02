#!/bin/bash

export PW=<your_password_here>
export MOUNT_STORAGE_ACCT_NAME=ferrexraystorage
export MOUNT_STORAGE_DNS_NAME=$MOUNT_STORAGE_ACCT_NAME.file.core.windows.net
export MOUNT_SHARE_NAME=dcos-shared-cifs-100g
export MOUNT_POINT=/mnt/shared

export OPTIONS="vers=3.0,username="$MOUNT_STORAGE_ACCT_NAME",password="$PW",dir_mode=0777,file_mode=0777"

mkdir -p $MOUNT_POINT
cat >> /etc/fstab << EOF
//$MOUNT_STORAGE_DNS_NAME/$MOUNT_SHARE_NAME $MOUNT_POINT cifs $OPTIONS
EOF

mount $EFS_MOUNT_POINT

sudo mount -t cifs //$MOUNT_STORAGE_DNS_NAME/$MOUNT_SHARE_NAME $MOUNT_POINT -o $OPTIONS
