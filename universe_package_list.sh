#single column, one per line
#dcos package search | awk -F " " '{print $1}'

#single line separated by commas
dcos package search | awk -F " " '{print $1}' | awk -vORS=, '{ print $1 }' | sed 's/,$/\n/'


#command for universe generation direct
#https://docs.mesosphere.com/1.8/administration/installing/custom/deploying-a-local-dcos-universe/#scrollNav-2
#arangodb3,artifactory,cassandra,chronos,confluent-kafka,dse,gitlab,jenkins,marathon,spark,arangodb,artifactory-lb,avi,bitbucket,calico,concord,confluent-connect,confluent-control-center,confluent-rest-proxy,confluent-schema-registry,crate,datadog,dcos-enterprise-cli,dynatrace,ecr-login,elasticsearch,etcd,exhibitor,gestalt-framework,hdfs,hue,kafka,kafka-manager,kibana,linkerd,linkerd-viz,logstash,marathon-lb,marathon-slack,mariadb,memsql,mr-redis,mysql,mysql-admin,namerd,netsil,netsil-collectors,nginx,omsdocker,openldap,openldap-admin,openvpn,openvpn-admin,postgresql,postgresql-admin,quobyte,resilio,,Resilio,riak,spark-notebook,storm,sysdig-cloud,tunnel-cli,vamp,weavescope,weavescope-probe,Weave,wordpress,zeppelin
#sed -i -e 's/--selected/--include="arangodb3,artifactory,cassandra,chronos,confluent-kafka,dse,gitlab,jenkins,marathon,spark,arangodb,artifactory-lb,avi,bitbucket,calico,concord,confluent-connect,confluent-control-center,confluent-rest-proxy,confluent-schema-registry,crate,datadog,dcos-enterprise-cli,dynatrace,ecr-login,elasticsearch,etcd,exhibitor,gestalt-framework,hdfs,hue,kafka,kafka-manager,kibana,linkerd,linkerd-viz,logstash,marathon-lb,marathon-slack,mariadb,memsql,mr-redis,mysql,mysql-admin,namerd,netsil,netsil-collectors,nginx,omsdocker,openldap,openldap-admin,openvpn,openvpn-admin,postgresql,postgresql-admin,quobyte,riak,spark-notebook,storm,sysdig-cloud,tunnel-cli,vamp,weavescope,weavescope-probe,Weave,wordpress,zeppelin"/' Makefile
