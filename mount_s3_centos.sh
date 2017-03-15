#!/bin/bash
#Description: mount s3 bucket into cloud instances

BUCKET_NAME=fernando-sanchez
MOUNT_POINT=/mnt/s3
ACCESS_KEY_ID=AKIAJZGXV3RQ43BD3BMA
AWS_SECRET_ACCESS_KEY=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

#install requirements
yum remove fuse fuse-s3fs
yum install -y gcc gcc-c++ automake openssl-devel libstdc++-devel curl-devel libxml2-devel mailcap wget git \
ftp://ftp.pbone.net/mirror/ftp.centos.org/7.3.1611/os/x86_64/Packages/fuse-libs-2.9.2-7.el7.x86_64.rpm

#create working dir and CD
mkdir -p ~/s3
cd ~/s3

#install fuse backend for S3 instances
yum remove fuse fuse-s3fs
yum install gcc libstdc++-devel gcc-c++ curl-devel libxml2-devel openssl-devel mailcap
cd /usr/src/
wget http://downloads.sourceforge.net/project/fuse/fuse-2.X/2.9.3/fuse-2.9.3.tar.gz
wget https://github.com/libfuse/libfuse/releases/download/fuse_2_9_4/fuse-2.9.3.tar.gz
cd fuse-2.9.3
./configure --prefix=/usr/local
make && make install
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
export PATH=$PATH:/usr/local/bin:/usr/local/lib
ldconfig
modprobe fuse
lsmod|grep fuse #check it works

#s3fs
git clone https://github.com/s3fs-fuse/s3fs-fuse.git
cd s3fs-fuse
./autogen.sh
./configure
make
sudo make install

#create config file
#configure s3fs required Access Key and Secret Key of your S3 Amazon account (Change AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY with your actual key values).
#–>  Click on AWS Menu -> Your AWS Account Name -> Security Credentials***

touch /etc/passwd-s3fs && chmod 640 /etc/passwd-s3fs && echo "$ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" > /etc/passwd-s3fs

#create mount point and mount
mkdir -p $MOUNT_POINT
s3fs $BUCKET_NAME $MOUNT_POINT -o passwd_file=/etc/passwd-s3fs
