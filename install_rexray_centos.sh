curl -sSL https://dl.bintray.com/emccode/rexray/install | sh -s -- stable 0.8.1

cat > /etc/rexray/config.yml << EOF
rexray:
#  loglevel: debug #not needed
libstorage:
  service: rbd
EOF
#copy to libstorage config
cp -f /etc/rexray/config.yml /etc/libstorage/config.yml > /dev/null 2>&1

cat > /etc/systemd/system/rexray << EOF
[Unit]
Description=REX-Ray: A vendor agnostic storage orchestration engine

[Service]
StartLimitInterval=0
Restart=always
RestartSec=15
LimitNOFILE=16384
Environment=REXRAY_HOME=/
ExecStart=/usr/bin/rexray start -f
EOF

systemctl daemon-reload

systemctl start rexray
