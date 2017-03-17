#!/bin/bash
# Build Universe

#this is the full list for 1.8 as of 20170317
export PACKAGE_LIST="arangodb3,artifactory,cassandra,confluent-kafka,elastic,gitlab,jenkins,marathon,spark,arangodb,artifactory-lb,avi,bitbucket,bookkeeper,cadvisor,calico,ceph,ceph-dash,chronos,concord,confluent-connect,confluent-control-center,confluent-replicator,confluent-rest-proxy,confluent-schema-registry,crate,datadog,dcos-enterprise-cli,dynatrace,ecr-login,elasticsearch,etcd,exhibitor,flink,geoserver,gestalt-framework,grafana,hdfs,hello-world,hue,influxdb,instana-agent,kafka,kafka-manager,kibana,koding,kong,linkerd,linkerd-viz,logstash,marathon-lb,marathon-slack,mariadb,memsql,minio,mongodb,mongodb-admin,mongodb-replicaset,mr-redis,msoms,mysql,mysql-admin,namerd,neo4j,neo4j-proxy,neo4j-replica,netsil,netsil-collectors,nexus,nginx,nifi,openldap,openldap-admin,openvpn,openvpn-admin,portworx,postgresql,postgresql-admin,quobyte,redis,registry,riak,scale,spark-history,spark-notebook,spark-shuffle,sqlserver,storm,sysdig-cloud,tunnel-cli,vamp,weavescope,Weave,weavescope-probe,Weave,wordpress,zeppelin"
export MY_IP=$(/usr/sbin/ip route get 8.8.8.8 | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | tail -1) # this node's default route interface

#clone the universe
git clone https://github.com/mesosphere/universe.git --branch version-3.x

#build the base image
cd universe/docker/local-universe/
sudo make base

#edit the target image to include ALL packages
cp Makefile _Makefile.bak
sed -i -e 's/--selected/--include=$PACKAGE_LIST/' Makefile

#build the universe - takes a WHILE
sudo make local-universe

#OPTIONALLY, add the universe to your system
#this requires the DCOS CLI to be installed and configured
dcos package repo add local-universe http://$MY_IP:8082/repo
