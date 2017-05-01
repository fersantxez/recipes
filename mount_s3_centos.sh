#!/bin/bash
#mount s3 bucket into cloud instances
BUCKET_NAME=fernando-sanchez
MOUNT_POINT=/mnt/s3
ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=

#install requirements
yum remove fuse fuse-s3fs
yum install -y gcc gcc-c++ automake openssl-devel libstdc++-devel curl-devel libxml2-devel mailcap wget git screen \
c
#install fuse backend for S3 instances
yum remove fuse fuse-s3fs
yum install gcc libstdc++-devel gcc-c++ curl-devel libxml2-devel openssl-devel mailcap
cd /usr/src/
wget https://github.com/libfuse/libfuse/releases/download/fuse_2_9_4/fuse-2.9.3.tar.gz
tar xvfz fuse-2.9.3.tar.gz
cd fuse-2.9.3
./configure --prefix=/usr/local
make && make install
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig
export PATH=$PATH:/usr/local/bin:/usr/local/lib
ldconfig
modprobe fuse
lsmod|grep fuse #check it works

#s3fs
cd /usr/src
git clone https://github.com/s3fs-fuse/s3fs-fuse.git
cd s3fs-fuse
./autogen.sh
./configure
make
sudo make install
ln -s /usr/local/bin/s3fs /usr/bin/s3fs


#create config file
#configure s3fs required Access Key and Secret Key of your S3 Amazon account (Change AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY with your actual key values).
#–>  Click on AWS Menu -> Your AWS Account Name -> Security Credentials***

touch /etc/passwd-s3fs && chmod 640 /etc/passwd-s3fs && echo "$ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" > /etc/passwd-s3fs

#create mount point and mount
mkdir -p $MOUNT_POINT
s3fs $BUCKET_NAME $MOUNT_POINT -o passwd_file=/etc/passwd-s3fs

#check it works
grep s3fs /etc/mtab
