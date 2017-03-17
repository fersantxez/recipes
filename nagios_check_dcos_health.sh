#!/bin/bash

#
# Monitors DC/OS cluster health, using JSON report from a master node.
# In case of error, it returns a list of affected services and master|agent nodes.
#
# Copyright 2017 Juan Jose Amor Iglesias
#
#    Licensed under the Apache License, Version 2.0 (the "License");
#    you may not use this file except in compliance with the License.
#    You may obtain a copy of the License at
#
#        http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS,
#    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#    See the License for the specific language governing permissions and
#    limitations under the License.
#

#
# Output: OK value is XXX|customval=X
# WARNING value is XXX|customval=X
# ERROR value is XXX|customval=X
#

OKRESULT=0
WARNRESULT=1
KORESULT=2
UNKRESULT=3

REPORT=$(mktemp)

die()
{
  echo "CRITICAL: $1"
  rm -f $REPORT
  exit $KORESULT
}

die_ok()
{
  echo "OK: $1"
  rm -f $REPORT
  exit $OKRESULT
}

die_unknown()
{
  echo "UNKNOWN: $1"
  rm -f $REPORT
  exit $UNKRESULT
}

# This script requires jq installed and available
hash jq >/dev/null 2>&1 || die_unknown "jq is required. Aborting."

# Argumens: Host (a master node)
[ A$1 == A ] && die_unknown "Usage: $0 MASTER_NODE_IP"

MASTERNODE=$1
REPORTURI=http://$1:1050/system/health/v1/report

curl -f $REPORTURI > $REPORT 2>>/dev/null
[ $? != 0 ] && die "Cannot download $REPORTURI"

SERVICECOUNT=$(jq '.Units | keys | length' $REPORT 2>/dev/null)
[ $? != 0 ] && die_unknown "$REPORTURI is not a json format"

[[ $SERVICECOUNT =~ ^-?[0-9]+$ ]] || die "Response did not give a list of valid units"

MAXSERVICE=$(($SERVICECOUNT-1))

ERRSTRING="Failed services:"
HEALTHSTATUS=0

for SERVICEINDEX in $(seq 0 $MAXSERVICE)
do
  JSONQUERY=".Units | keys[$SERVICEINDEX]"
  SERVICENAME=$(jq "$JSONQUERY" $REPORT)

  JSONQUERY=".Units[$SERVICENAME].Health"
  HEALTH=$(jq "$JSONQUERY" $REPORT)
  # Detected a fault on a service, analyze it by search the fault in a node
  
  if [ $HEALTH != 0 ]
  then
    JSONQUERY=".Units[$SERVICENAME].Nodes | length"
	NODES=$(jq "$JSONQUERY" $REPORT)
	for NODE in $(seq 0 $(($NODES-1)))
	do
	  JSONQUERY=".Units[$SERVICENAME].Nodes[$NODE].Health"
	  HEALTH=$(jq "$JSONQUERY" $REPORT)

	  if [ $HEALTH != 0 ]
	  then
	  
	    JSONQUERY=".Units[$SERVICENAME].Nodes[$NODE].Host"
		NODENAME=$(jq "$JSONQUERY" $REPORT)
	    HEALTHSTATUS=2
		ERRSTRING="$ERRSTRING ${SERVICENAME} in node ${NODENAME},"
      fi
	done
  fi
  
done

if [ $HEALTHSTATUS != 0 ]
then
  die "$ERRSTRING"
else
  die_ok "No faults detected."
fi
