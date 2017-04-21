sudo su
curl -O https://raw.githubusercontent.com/fernandosanchezmunoz/DCOS_installer/master/dcos_install_centos7.sh
sed -i -- 's,DOWNLOAD_URL="https://downloads.dcos.io/dcos/EarlyAccess/dcos_generate_config.sh",DOWNLOAD_URL="https://downloads.mesosphere.com/dcos-enterprise/stable/dcos_generate_config.ee.sh",g' dcos_install*
bash dcos_install*
