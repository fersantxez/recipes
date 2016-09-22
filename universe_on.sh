#PREREQUISITES
yum install -y epel-release
yum install -y git python-pip python34 jq nginx
curl https://bootstrap.pypa.io/get-pip.py | python3.4
pip3 install --upgrade pip jsonschema
#
#####################
BASEDIR=~
REPONAME=universe
PACKAGENAME="openldap"
SERVERIP=172.31.21.226
SERVERPORT=8085

########################################
# BOOTSTRAP NODE: create from scratch after code change
########################################
cd $BASEDIR
rm -Rf $REPONAME
git clone http://github.com/fernandosanchezmunoz/$REPONAME
cd $REPONAME

scripts/build.sh

#build image and marathon.json
DOCKER_TAG=$PACKAGENAME docker/server/build.bash

#run the docker image in the bootstrap node
docker run -d --name universe-dev -p $SERVERPORT:80 mesosphere/universe-server:$PACKAGENAME

#add repo from the universe we just started
dcos package repo add --index=0 dev-universe http://$SERVERIP:$SERVERPORT/repo

#check that the universe is running -- FROM THE BOOTSTRAP OR ANY NODE
#curl http://$SERVERIP:8085/repo | grep $PACKAGENAME

dcos package install --yes $PACKAGENAME
dcos package install --yes $PACKAGENAME-admin

echo -e "Copy and paste the following into each node of the cluster to activate this server's certificate on them:"
echo -e "mkdir -p /etc/docker/certs.d/$SERVERIP:5000"
echo -e "curl -o /etc/docker/certs.d/$SERVERIP:5000/ca.crt http://$SERVERIP:$SERVERPORT/certs/domain.crt"
echo -e "systemctl restart docker"
echo -e ""
