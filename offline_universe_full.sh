#prereqs
yum install -y epel-release
yum install -y git python-pip python34 jq nginx
curl https://bootstrap.pypa.io/get-pip.py | python3.4
pip3 install --upgrade pip jsonschema

#variables
PACKAGE_LIST="arangodb3,artifactory,cassandra,confluent-kafka,elastic,gitlab,jenkins,marathon,spark,arangodb,artifactory-lb,avi,bitbucket,bookkeeper,cadvisor,calico,ceph,ceph-dash,chronos,concord,confluent-connect,confluent-control-center,confluent-replicator,confluent-rest-proxy,confluent-schema-registry,crate,datadog,dcos-enterprise-cli,dynatrace,ecr-login,elasticsearch,etcd,exhibitor,flink,geoserver,gestalt-framework,grafana,hdfs,hello-world,hue,influxdb,instana-agent,kafka,kafka-manager,kibana,koding,kong,linkerd,linkerd-viz,logstash,marathon-lb,marathon-slack,mariadb,memsql,minio,mongodb,mongodb-admin,mongodb-replicaset,mr-redis,msoms,mysql,mysql-admin,namerd,neo4j,neo4j-proxy,neo4j-replica,netsil,netsil-collectors,nexus,nginx,nifi,openldap,openldap-admin,openvpn,openvpn-admin,portworx,postgresql,postgresql-admin,quobyte,redis,registry,riak,scale,spark-history,spark-notebook,spark-shuffle,sqlserver,storm,sysdig-cloud,tunnel-cli,vamp,weavescope,Weave,weavescope-probe,Weave,wordpress,zeppelin"
BASEDIR=~
REPONAME=universe
BRANCH="version-3.x"
SERVERIP=$(ip addr show eth0 | grep -Eo \
 '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1) #this node's eth0
SERVERPORT=8082

#on node where the universe will be generated -- NEEDS INTERNET ACCESS
git clone https://github.com/mesosphere/universe.git --branch $BRANCH
cd universe/docker/local-universe/
sudo make base
#FULL list
sed -i -e "s/--selected/--include=$PACKAGE_LIST/" Makefile
#smaller list
#sed -i -e 's/--selected/--include="artifactory,cassandra,chronos,gitlab,jenkins,marathon,spark,artifactory-lb,datadog,elasticsearch,etcd,exhibitor,hdfs,kafka,kibana,logstash,marathon-lb,mariadb,memsql,mr-redis,mysql,mysql-admin,nginx,openldap,openldap-admin,postgresql,postgresql-admin,sysdig-cloud,wordpress,zeppelin"/' Makefile
sudo make local-universe

#If node where generated is not the same node where loaded (e.g. offline bootstrap node), then
#find the local-universe.tar.gz and sftp to the node where it will be running (e.g. the offline bootstrap node)

#then on the bootstrap node,
#copy and paste the variables section above! those variables are not defined there

sudo docker load < local-universe.tar.gz

sudo curl -O https://raw.githubusercontent.com/mesosphere/universe/version-2.x/local/dcos-local-universe-http.service
sudo cp dcos-local-universe-http.service /etc/systemd/system/dcos-local-universe-http.service
systemctl daemon-reload
systemctl start dcos-local-universe-http

sudo curl -O https://raw.githubusercontent.com/mesosphere/universe/version-2.x/local/dcos-local-universe-registry.service
sudo cp dcos-local-universe-registry.service /etc/systemd/system/dcos-local-universe-registry.service
systemctl daemon-reload
systemctl start dcos-local-universe-registry

dcos package repo add local-universe http://$SERVERIP:$SERVERPORT/repo

#thats it. Then we can optionally
dcos package repo remove Universe

