#####################
# uninstall completely - from bootstrap node
#####################
BASEDIR=~
REPONAME=universe
PACKAGENAME="openldap"
SERVERPORT=8085

#uninstall openldap package
dcos package uninstall $PACKAGENAME
dcos package uninstall $PACKAGENAME-admin
#

######
#uninstall package repo
dcos package repo remove dev-universe
#

#stop and remove universe container
CONTAINER=$(docker ps -a|grep universe | awk '{print $1}')
docker rm -f $CONTAINER

#remove docker image from serving node
IMAGE=$(docker images|grep mesosphere/universe-server|awk '{print $1}')
TAG=$(docker images|grep mesosphere/universe-server|awk '{print $2}')
docker rmi $IMAGE:$TAG
#
#remove complete repo for safety (make sure we don't reuse anything)
rm -Rf $BASEDIR/$REPONAME
#
#remove temporary directories and volumes
rm -Rf /tmp/*
