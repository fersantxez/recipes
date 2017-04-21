ETCD_IP=etcd1.marathon.l4lb.thisdcos.directory
ETCD_PORT=4001
VOLUME=/dev/xvdb
INTERFACE=eth0
PORTWORX_CONF=portworx-options.conf

cat > $PORTWORX_CONF << EOF
{
  "service": {
    "name": "portworx"
  },
  "portworx": {
    "framework-name": "portworx",
    "cpus": 1,
    "mem": 2048,
    "instances": 3,
    "cmdargs": "-k etcd://$ETCD_IP:$ETCD_PORT -c px1234 -s $VOLUME -m $INTERFACE -d $INTERFACE",
    "headers_dir": "/lib/modules",
    "api_port": 9001
  }
}
EOF

dcos auth login &&\
dcos package install --yes --options $PORTWORX_CONF portworx
