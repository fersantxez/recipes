#
# SCRIPT: dcos-audit-log-forwarder.py
#
# vim: set expandtab ts=4 sw=4 ai
#
# DESCRIPTION:
#       This script reads the Enterprise DC/OS audit log files and forwards the
#       entries into an elasticsearch instance. Run this program on every 
#       master node. This program processes the following Enterprise DC/OS Audit Events:
#
#           CREATE USER
#           DELETE USER
#           CREATE GROUP
#           DELETE GROUP
#           ADD USER TO GROUP
#           ADD ACL TO GROUP
#           REMOVE ACL FROM GROUP
#           REMOVE USER FROM GROUP
#           LOGIN USER SUCCESSFUL
#           LOGIN USER UNSUCCESSFUL
#           CREATE SAML PROVIDER
#           CREATE LDAP DIRECTORY
#           CREATE OAUTH2 PROVIDER
#           CREATE SECRET
#           DELETE SECRET
#           CREATE APP
#           DESTROY APP
#           RESTART APP
#           SCALE APP (includes Suspending and Resuming apps)
#           SCALE APP GROUP
#           DESTROY APP GROUP
#           
#
# REQUIREMENTS:
#       1. Install the Elasticesearch Python Package
#               sudo /opt/mesosphere/bin/pip install elasticsearch
#
#       2. Install the python DNS package
#               sudo /opt/mesosphere/bin/pip install dnspython
#
# USAGE:
#
#       1. Start the Elasticsearch service using the DC/OS CLI command:
#
#           dcos package install --yes elasticsearch
#
#       2. Run this program on EVERY master node in your DC/OS cluster. First you
#          will have to install two python packages that this program requires.
#          Use the these commands to install the python packages:
#
#           sudo /opt/mesosphere/bin/pip install elasticsearch
#           sudo /opt/mesosphere/bin/pip install dnspython
#
#       3. Optionally, you can use the systemd setup to make sure these programs are 
#           restarted if they stop. You can use something like this to achieve that:
#
#           a. Create a file called /etc/systemd/system/dcos-audit-log-forwarder.service      
#
#           b. Add the following lines to the dcos-audit-log-forwarder.service file. Omit the 
#              leading # characters.
#
# [Unit]
# Description=DCOS Audit Log Forwarder: Forward Audit log entries to an Elasticsearch instance
# 
# [Service]
# Restart=always
# StartLimitInterval=0
# RestartSec=15
# TimeoutStartSec=120
# TimeoutStopSec=15
# ExecStartPre=-/opt/mesosphere/bin/pip install elasticsearch
# ExecStartPre=-/opt/mesosphere/bin/pip install dnspython
# ExecStart=/opt/mesosphere/bin/python3 /usr/local/bin/dcos-audit-log-forwarder.py
# 
# [Install]
# WantedBy=multi-user.target
# 
#           c. Refresh the systemd info with the command
#
#               sudo systemctl daemon-reload
#
#           d. Start the audit log forwarder as a service using the commands:
#
#               systemctl enable dcos-audit-log-forwarder
#               sudo systemctl start dcos-audit-log-forwarder
#               systemctl status dcos-audit-log-forwarder
#
#       4. Geneate some audit events using the DC/OS Dashboard or CLI commands.
#  
#           a. Create a user
#           b. Create a group
#           c. Add the user to the group
#           d. Create an ACL (permission) to the group
#           e. Create a simple application
#           f. Scale the application to more instances
#           g. Destroy the application
#
#       5. Search the Elasticsearch repository and display the fowarded events.
#
#           a. SSH into one of the master or agent nodes in the cluster
#
#           b. Install several required python packages with the commands:
#
#               sudo /opt/mesosphere/bin/pip install elasticsearch
#               sudo /opt/mesosphere/bin/pip install dnspython
#
#           c. Start an interactive python session with the command:
#
#               /opt/mesosphere/bin/python3
#
#           d. Query the repo with the commands (remove the leading # characters):
#
#           
# #
# # Connect to Elasticsearch service
# #
# 
# from elasticsearch import Elasticsearch
# import dns.resolver
# 
# try:
#     esDnsName = '_elasticsearch-executor._tcp.elasticsearch.slave.mesos.' # Old service
#     # esDnsName = '_elastic._tcp.marathon.slave.mesos.'  # New elastic service
#     dnsResults = dns.resolver.query(esDnsName, 'SRV')
#     for dnsEntry in dnsResults:
#         # get first line of results
#         print (str(dnsEntry))
#         # pick out the TCP port number and hostname
#         parts = str(dnsEntry).split(' ')
#         esPortNumber = 1029 # esPortNumber = parts[2]
#         esHostname = parts[3]
#         #print( 'USING Hostname: ' + esHostname + ' AND Port Number: ' + esPortNumber)
#         break
# except Exception as e:
#     print(' ERROR: dns.resolver.query() failed to find elasticsearch service: ' + esDnsName)
# 
# esConn = Elasticsearch(hosts=[{'host': esHostname, 'port': esPortNumber}])
# 
# 
# #
# # Search for DC/OS Audit Log entries
# # 
# try:
#     result = esConn.search(index='dcos_audit_index', q='requesting_user:"bootstrapuser"', sort='log_datetime' )
#     print('')
#     print("Got %d Hits:" % result['hits']['total'])
#     print('%-25s' % ' LOG DATETIME' + '%-20s' % '  REQUESTING_USER' + '%-25s' % '   ACTION' + '%-40s' % '    TARGET OBJECTS')
#     for hit in result['hits']['hits']:
#         print(" %(log_datetime)-25s %(requesting_user)-20s %(action)-25s %(target_objects)-40s" % hit["_source"])
# except Exception as e:
#     print(' ### Search Found Zero Entries')
# 
# 



import sys
import subprocess
import select
import datetime
import time
import re           # regex package
from elasticsearch import Elasticsearch
import dns.resolver


PROGRAM_NAME = 'DCOS AUDIT LOG FORWARDER'
LOG_LEVEL    = 'DEBUG'                   # NONE, INFO, DEBUG

#
# FUNCTION: log_msg
#
def log_msg(msg):
    if LOG_LEVEL == 'INFO' or LOG_LEVEL == 'DEBUG':
        dt = datetime.datetime.now()
        print(PROGRAM_NAME, ' ',dt,' - ', msg)
#
# FUNCTION: log_debug
#
def log_debug(msg):
    if LOG_LEVEL == 'DEBUG':
        dt = datetime.datetime.now()
        print(PROGRAM_NAME, ' ',dt,' - ', msg)

    return

#
# FUNCTION: toList
#
def toList(*args):
    numArgs = len(args)
    cnt = 0
    newList = '['
    for item in args:
        if cnt > 0:
            newList += ','
        newList += '\'' + item + '\''
        cnt += 1
    newList += ']'
    return newList

#
# FUNCTION: get_elasticsearch_conn
#
def get_elasticsearch_conn():

    # Get Elasticsearch worker nodes
    try:
        esDnsName = '_elasticsearch-executor._tcp.elasticsearch.slave.mesos.'

        dnsResults = dns.resolver.query(esDnsName, 'SRV')

        for dnsEntry in dnsResults:

            # get first line of results
            #print (str(dnsEntry))

            # pick out the TCP port number and hostname
            parts = str(dnsEntry).split(' ')
            esPortNumber = 1025 # esPortNumber = parts[2]
            esHostname = parts[3]
            #print( 'USING Hostname: ' + esHostname + ' AND Port Number: ' + esPortNumber)
            break

        es = Elasticsearch(hosts=[{'host': esHostname, 'port': esPortNumber}])

    except Exception as e:
        log_msg(' ERROR: dns.resolver.query() failed to find a running elasticsearch service: ' + esDnsName)
        return
        
    if not es.ping():
        log_msg(' ERROR: Elasticsearch Connection failed using host ' + esHostname + ' and port number ' + str(esPortNumber))
        return

    return es

#
# FUNCTION: get_elastic_conn
#
def get_elastic_conn():

    # Get Elasticsearch worker nodes
    try:
        esDnsName = '_client-port._elasticsearch-executor._tcp.elasticsearch.mesos.'

        dnsResults = dns.resolver.query(esDnsName, 'SRV')

        for dnsEntry in dnsResults:

            # get first line of results
            #print (str(dnsEntry))

            # pick out the TCP port number and hostname
            parts = str(dnsEntry).split(' ')
            esPortNumber = 1025 # esPortNumber = parts[2]
            esHostname = parts[3]
            #print( 'USING Hostname: ' + esHostname + ' AND Port Number: ' + esPortNumber)
            break

        es = Elasticsearch(hosts=[{'host': esHostname, 'port': esPortNumber}])

    except Exception as e:
        log_msg(' ERROR: dns.resolver.query() failed to find a running elasticsearch service: ' + esDnsName)
        return

    if not es.ping():
        log_msg(' ERROR: Elasticsearch Connection failed using host ' + esHostname + ' and port number ' + esPortNumber)
        return

    return es

#
# FUNCTION: create_elasticsearch_entry
#
def create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, auditEvent, targetObjects, details):

    logDatetime = dateStr + 'T' + timeStr   # i.e. 2017/01/10T13:30:15

    # Replace / with -
    logDatetime = logDatetime.replace('/', '-')

    # TODO: Fix the regex to not include the brackets [ ], for CREATE_APP
    if '[' in logDatetime:
        logDatetime = logDatetime.replace('[', '')
    if ']' in logDatetime:
        logDatetime = logDatetime.replace(']', '')

    # Remove milliseconds spec (elasticsearch doesn't like it)
    if ',' in logDatetime:
        logDatetime = logDatetime[:-4]

    try:

        bodyJson={'log_datetime': logDatetime ,'requesting_user': requestingUser, 'action': auditEvent, 'target_objects': targetObjects, 'details': details}

        es.index(index='dcos_audit_index', doc_type='audit_log', body=bodyJson ) 

    except Exception as e:
        log_msg(' ERROR: es.index() - Could not insert log entry into Elasticsearch: ' + str(bodyJson))
        log_msg(' ERROR: es.index() - Error Message: ' + str(e) )

    return

#
# FUNCTION: check_log_file_entry
#
def check_log_file_entry(p, f, line, es):

    ignore=True

    #
    # Match Log file entries using Regex search command
    #
    
    #
    # CREATE USER Event
    #
    # Dec 06 18:00:30 c1mas1 nginx[24163]: 2016/12/06 18:04:13 [notice] 9829#0: *53789 [lua] auth.lua:196: validate_jwt_or_exit(): UID from valid JWT: `admin`, client: 10.0.0.119, server: master.mesos, request: "PUT /acs/api/v1/users/gpalmer7?_timestamp=1481065453618 HTTP/1.1", host: "c1mas1", referrer: "https://c1mas1/"

    result = re.search(r'UID from valid JWT: `(.+)`, client: .+, server: master.mesos, request: \"PUT \/acs\/api\/v.\/users\/(.+)\?_timestamp=', line)
    if result:
        # Get the requesting user and the created user
        requestingUser = result.group(1)
        createdUser = result.group(2)
        # Replace encoded space with a regular space
        createdUser = createdUser.replace('%20', ' ')

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        log_msg(' FORWARDING AUDIT EVENT: CREATE USER : DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' USER: ' + createdUser)
        
        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'CREATE_USER', toList(createdUser), line)

        return

    #
    # DELETE USER Event
    #
    # Dec 16 16:35:25 c1mas1 nginx[4459]: 2016/12/16 16:35:25 [notice] 16118#0: *44004 [lua] auth.lua:196: validate_jwt_or_exit(): UID from valid JWT: `adminuser`, client: 10.0.0.119, server: master.mesos, request: "DELETE /acs/api/v1/users/gpalmer2?_timestamp=1481924125397 HTTP/1.1", host: "c1mas1", referrer: "https://c1mas1/"

    result = re.search(r'UID from valid JWT: `(.+)`, client: .+, server: master.mesos, request: "DELETE \/acs\/api\/v.\/users\/(.[^\/]+)\?_timestamp=', line)
    if result:
        # Get the requesting user and the created user
        requestingUser = result.group(1)
        deletedUser = result.group(2)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        log_msg(' FORWARDING AUDIT EVENT: DELETE USER : DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' USER: ' + deletedUser)
        
        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'DELETE_USER', toList(deletedUser), line)

        return

    #
    # CREATE GROUP Event
    #
    # Dec 05 18:23:30 ip-10-0-6-118.us-west-2.compute.internal nginx[2002]: 2016/12/05 18:23:30 [notice] 26371#0: *175698 [lua] auth.lua:196: validate_jwt_or_exit(): UID from valid JWT: `bootstrapuser`, client: 10.0.4.127, server: master.mesos, request: "PUT /acs/api/v1/groups/group1?_timestamp=1480962209907 HTTP/1.1", host: "gregpalme-elasticl-1dxvqfwd208r-482797201.us-west-2.elb.amazonaws.com", referrer: "https://gregpalme-elasticl-1dxvqfwd208r-482797201.us-west-2.elb.amazonaws.com/"

    result = re.search(r'UID from valid JWT: `(.+)`, client: .+, server: master.mesos, request: "PUT \/acs\/api\/v.\/groups\/(.[^\/]+)\?_timestamp=', line)

    if result:
        # Get the requesting user and the created group
        requestingUser = result.group(1)
        userGroup = result.group(2)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        log_msg(' FORWARDING AUDIT EVENT: CREATE GROUP : DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' GROUP: ' + userGroup)
        
        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'CREATE_GROUP', toList(userGroup), line)

        return

    #
    # DELETE GROUP Event
    #
    # Dec 16 14:52:02 c1mas1 nginx[4459]: 2016/12/16 14:52:02 [notice] 8318#0: *9678 [lua] auth.lua:196: validate_jwt_or_exit(): UID from valid JWT: `adminuser`, client: 10.0.0.119, server: master.mesos, request: "DELETE /acs/api/v1/groups/group3?_timestamp=1481917922360 HTTP/1.1", host: "c1mas1", referrer: "https://c1mas1/"

    result = re.search(r'UID from valid JWT: `(.+)`, client: .+, server: master.mesos, request: "DELETE \/acs\/api\/v.\/groups\/(.[^\/]+)\?_timestamp=',line)

    if result:
        # Get the requesting user and the created group
        requestingUser = result.group(1)
        deletedGroup = result.group(2)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        log_msg(' FORWARDING AUDIT EVENT: DELETE GROUP : DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' GROUP: ' + deletedGroup)

        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'DELETE_GROUP', toList(deletedGroup), line)
        
        return

    #
    # ADD USER TO GROUP Event
    #
    # Dec 05 18:24:37 ip-10-0-6-118.us-west-2.compute.internal nginx[2002]: 2016/12/05 18:24:37 [notice] 26561#0: *176833 [lua] auth.lua:196: validate_jwt_or_exit(): UID from valid JWT: `bootstrapuser`, client: 10.0.4.127, server: master.mesos, request: "PUT /acs/api/v1/groups/group1/users/gpalmer?_timestamp=1480962276489 HTTP/1.1", host: "gregpalme-elasticl-1dxvqfwd208r-482797201.us-west-2.elb.amazonaws.com", referrer: "https://gregpalme-elasticl-1dxvqfwd208r-482797201.us-west-2.elb.amazonaws.com/"

    result = re.search(r'UID from valid JWT: `(.+)`, client: .+, server: master.mesos, request: "PUT \/acs\/api\/v.\/groups\/(.+)\/users\/(.+)\?_timestamp=', line)
    if result:
        # Get the requesting user and the user and group
        requestingUser = result.group(1)
        userGroup = result.group(2)
        addedUser = result.group(3)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        log_msg(' FORWARDING AUDIT EVENT: ADD USER TO GROUP: DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' GROUP: ' + userGroup + ' USER: ' + addedUser)

        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'ADD_USER_TO_GROUP', toList(addedUser, userGroup), line)

        return

    #
    # ADD ACL TO GROUP Event
    #
    # Dec 16 16:52:29 c1mas1 nginx[4459]: 2016/12/16 16:52:29 [notice] 17439#0: *50131 [lua] auth.lua:196: validate_jwt_or_exit(): UID from valid JWT: `adminuser`, client: 10.0.0.119, server: master.mesos, request: "PUT /acs/api/v1/acls/dcos:adminrouter:service:marathon/groups/group1/full?_timestamp=1481925149914 HTTP/1.1", host: "c1mas1", referrer: "https://c1mas1/"

    result = re.search(r'UID from valid JWT: `(.+)`, client: .+, server: master.mesos, request: "PUT \/acs\/api\/v.\/acls\/(.[^\/]+)\/groups\/(.[^\/]+)\/(.[^\?]+)\?_timestamp=', line)
    if result:
        # Get the requesting user and the user and group
        requestingUser = result.group(1)
        acl = result.group(2)
        # Replace "%252F" with "/"
        acl = acl.replace('%252F', '/')
        userGroup = result.group(3)
        aclCrud = result.group(4)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        log_msg(' FORWARDING AUDIT EVENT: ADD ACL TO GROUP: DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' GROUP: ' + userGroup + ' ACL: ' + acl + ' CRUD: ' + aclCrud )

        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'ADD_ACL_TO_GROUP', toList(acl+'='+aclCrud, userGroup), line)

        return

    #
    # REMOVE ACL FROM GROUP Event
    #
    # Dec 30 13:35:53 ip-10-0-6-213.us-west-2.compute.internal nginx[1968]: 2016/12/30 13:35:53 [notice] 7753#0: *17667 [lua] auth.lua:196: validate_jwt_or_exit(): UID from valid JWT: `bootstrapuser`, client: 10.0.7.231, server: master.mesos, request: "DELETE /acs/api/v1/acls/dcos:adminrouter:service:marathon/groups/mobile-apps/full?_timestamp=1483104953519 HTTP/1.1", host: "gregpalme-elasticl-ty0pnk41hsmb-1635574205.us-west-2.elb.amazonaws.com", referrer: "https://gregpalme-elasticl-ty0pnk41hsmb-1635574205.us-west-2.elb.amazonaws.com/"

    result = re.search(r'UID from valid JWT: `(.+)`, client: .+, server: master.mesos, request: "DELETE \/acs\/api\/v.\/acls\/(.[^\/]+)\/groups\/(.[^\/]+)\/(.[^\?]+)\?_timestamp=', line)
    if result:
        # Get the requesting user and the user and group
        requestingUser = result.group(1)
        acl = result.group(2)
        # Replace "%252F" with "/"
        deletedAcl = acl.replace('%252F', '/')
        userGroup = result.group(3)
        aclCrud = result.group(4)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        log_msg(' FORWARDING AUDIT EVENT: REMOVE ACL FROM GROUP: DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' GROUP: ' + userGroup + ' ACL: ' + deletedAcl + ' CRUD: ' + aclCrud )

        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'REMOVE_ACL_FROM_GROUP', toList(deletedAcl+'='+aclCrud, userGroup), line)

        return

    #
    # REMOVE USER FROM GROUP Event
    #
    # Dec 16 16:44:40 c1mas1 nginx[4459]: 2016/12/16 16:44:40 [notice] 16824#0: *47435 [lua] auth.lua:196: validate_jwt_or_exit(): UID from valid JWT: `adminuser`, client: 10.0.0.119, server: master.mesos, request: "DELETE /acs/api/v1/groups/group1/users/gpalmer?_timestamp=1481924680985 HTTP/1.1", host: "c1mas1", referrer: "https://c1mas1/"

    result = re.search(r'UID from valid JWT: `(.+)`, client: .+, server: master.mesos, request: "DELETE \/acs\/api\/v.\/groups\/(.[^\/]+)\/users\/(.[^\/]+)\?_timestamp=', line)
    if result:
        # Get the requesting user and the user and group
        requestingUser = result.group(1)
        userGroup = result.group(2)
        removedUser = result.group(3)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        log_msg(' FORWARDING AUDIT EVENT: REMOVE USER FROM GROUP: DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' GROUP: ' + userGroup + ' USER: ' + removedUser)

        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'REMOVE_USER_FROM_GROUP', toList(removedUser, userGroup), line)

        return

    #
    # LOGIN USER Event
    #
    result = re.search(r'Trigger login procedure for uid `(.+)`', line)
    if result:
        # Get the user that logged in
        user = result.group(1)

        # Ignore DC/OS system users
        if 'dcos_' in user:
            #log_debug('Ignoring system user login: ' + user)
            return
        else:

            # Get the log entry date and time (specified as: Jan 10 16:12:54 )
            result2 = re.search('^(...) (..) (..:..:..)', line)
            monthName = result2.group(1)
            dayOfMonth = result2.group(2)
            month = time.strptime(monthName,'%b').tm_mon
            if month < 10:
                monthStr = '0' + str(month)
            else:
                montStr = str(month)
            currentYear = datetime.datetime.now().year
            dateStr = str(currentYear) + '/' + monthStr + '/' + dayOfMonth

            timeStr = result2.group(3)

            # Get the next lines and check to see if the login was successful or unsuccessful

            count = 0
            while count < 10:
                if p.poll(100):
                    byteLine = f.stdout.readline()
                    line = byteLine.decode("utf-8")

                    # Check for successful login
                    result2 = re.search(r'INFO: User login: UID refers to a known local user.', line)

                    if result2:

                        log_msg(' FORWARDING AUDIT EVENT: LOGIN USER SUCCESSFUL : ' + user)

                        # Insert log entry into Elasticsearch
                        create_elasticsearch_entry(es, dateStr, timeStr, 'NONE', 'LOGIN_USER_SUCCESSFUL', toList(user), line)

                        # Exit the loop
                        break;

                    # Check for unsuccessful login
                    result2 = re.search(r'INFO: User login: UID `(.+)` unknown.', line)

                    if result2:

                        log_msg(' FORWARDING AUDIT EVENT: LOGIN USER UNSUCCESSFUL : ' + user)

                        # Insert log entry into Elasticsearch
                        create_elasticsearch_entry(es, dateStr, timeStr, 'NONE', 'LOGIN_USER_UNSUCCESSFUL', toList(user), line)

                        # Exit the loop

                count += 1

        return

    #
    # CREATE SAML PROVIDER Event
    #
    # Dec 16 17:32:34 c1mas1 nginx[4459]: 2016/12/16 17:32:34 [notice] 20527#0: *63988 [lua] auth.lua:196: validate_jwt_or_exit(): UID from valid JWT: `adminuser`, client: 10.0.0.119, server: master.mesos, request: "PUT /acs/api/v1/auth/saml/providers/gregssaml?_timestamp=1481927554861 HTTP/1.1", host: "c1mas1", referrer: "https://c1mas1/"

    result = re.search(r'UID from valid JWT: `(.+)`, client: .+, server: master.mesos, request: "PUT \/acs\/api\/v.\/auth\/saml\/providers\/(.[^\/]+)\?_timestamp=', line)

    if result:
        # Get the requesting user and the created group
        requestingUser = result.group(1)
        samlProvider = result.group(2)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        log_msg(' FORWARDING AUDIT EVENT: CREATE SAML PROVIDER : DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' SAML PROVIDER: ' + samlProvider)
        
        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'CREATE_SAML_PROVIDER', toList(samlProvider), line)

        return

    #
    # CREATE LDAP DIRECTORY Event
    #
    # Dec 16 17:44:09 c1mas1 nginx[4459]: 2016/12/16 17:44:09 [notice] 21365#0: *67274 [lua] auth.lua:196: validate_jwt_or_exit(): UID from valid JWT: `adminuser`, client: 10.0.0.119, server: master.mesos, request: "PUT /acs/api/v1/ldap/config?_timestamp=1481928249246 HTTP/1.1", host: "c1mas1", referrer: "https://c1mas1/"

    result = re.search(r'UID from valid JWT: `(.+)`, client: .+, server: master.mesos, request: "PUT \/acs\/api\/v.\/ldap\/config\?_timestamp=', line)
    if result:
        # Get the requesting user and the created group
        requestingUser = result.group(1)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        log_msg(' FORWARDING AUDIT EVENT: CREATE LDAP DIRECTORY: DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser )
        
        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'CREATE_LDAP_AD_DIRECTORY', toList('NONE'), line)

        return

    #
    # CREATE OAUTH2 PROVIDER Event
    #
    # Dec 16 17:32:34 c1mas1 nginx[4459]: 2016/12/16 17:32:34 [notice] 20527#0: *63988 [lua] auth.lua:196: validate_jwt_or_exit(): UID from valid JWT: `adminuser`, client: 10.0.0.119, server: master.mesos, request: "PUT /acs/api/v1/auth/saml/providers/gregssaml?_timestamp=1481927554861 HTTP/1.1", host: "c1mas1", referrer: "https://c1mas1/"

    result = re.search(r'UID from valid JWT: `(.+)`, client: .+, server: master.mesos, request: "PUT \/acs\/api\/v.\/auth\/oidc\/providers\/(.[^\/]+)\?_timestamp=', line)
    if result:
        # Get the requesting user and the created group
        requestingUser = result.group(1)
        oauth2Provider = result.group(2)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        log_msg(' FORWARDING AUDIT EVENT: CREATE OAUTH2 PROVIDER : DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' OAUTH2 PROVIDER: ' + oauth2Provider)
        
        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'CREATE_OAUTH2_PROVIDER', toList(oauth2Provider), line)

        return

    #
    # CREATE SECRET Event
    #
    # Dec 16 17:51:42 c1mas1 nginx[4459]: 2016/12/16 17:51:42 [notice] 21980#0: *69627 [lua] auth.lua:196: validate_jwt_or_exit(): UID from valid JWT: `adminuser`, client: 10.0.0.119, server: master.mesos, request: "PUT /secrets/v1/secret/default/gregssecret1?_timestamp=1481928702829 HTTP/1.1", host: "c1mas1", referrer: "https://c1mas1/"
    #
    # Dec 31 14:54:37 ip-10-0-7-80.us-west-2.compute.internal nginx[2126]: 2016/12/31 14:54:37 [notice] 8916#0: *19829 [lua] auth.lua:196: validate_jwt_or_exit(): UID from valid JWT: `bootstrapuser`, client: 10.0.5.20, server: master.mesos, request: "PUT /secrets/v1/secret/default/mysql-pass-secret?_timestamp=1483196077671 HTTP/1.1", host: "gregpalme-elasticl-wuj213rw28um-1301724768.us-west-2.elb.amazonaws.com", referrer: "https://gregpalme-elasticl-wuj213rw28um-1301724768.us-west-2.elb.amazonaws.com/"

    result = re.search(r'UID from valid JWT: `(.+)`, client: .+, server: master.mesos, request: "PUT \/secrets\/v.\/secret\/default\/(.[^\/]+)\?_timestamp=', line)
    if result:
        # Get the requesting user and the created group
        requestingUser = result.group(1)
        secret = result.group(2)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        # Replace HTTP codes with slash (/)
        secret = secret.replace('%2F', '/')

        log_msg(' FORWARDING AUDIT EVENT: CREATE SECRET: DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' SECRET: ' + secret)

        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'CREATE_SECRET', toList(secret), line)
        
        return

    #
    # DELETE SECRET Event
    #
    # 
    # Jan 03 15:05:35 ip-10-0-5-147.us-west-2.compute.internal nginx[2123]: 2017/01/03 15:05:35 [notice] 21216#0: *102874 [lua] auth.lua:196: validate_jwt_or_exit(): UID from valid JWT: `bootstrapuser`, client: 10.0.6.216, server: master.mesos, request: "DELETE /secrets/v1/secret/default/mobile-apps/app1/mysecret?_timestamp=1483455935389 HTTP/1.1", host: "gregpalme-elasticl-1xhcp4kutdrsg-1630258365.us-west-2.elb.amazonaws.com", referrer: "https://gregpalme-elasticl-1xhcp4kutdrsg-1630258365.us-west-2.elb.amazonaws.com/"

    result = re.search(r'UID from valid JWT: `(.+)`, client: .+, server: master.mesos, request: "DELETE \/secrets\/v.\/secret\/default\/(.[^\?]+)\?_timestamp=', line)
    if result:
        # Get the requesting user and the created group
        requestingUser = result.group(1)
        secret = result.group(2)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        # Replace HTTP codes with slash (/)
        secret = secret.replace('%2F', '/')

        log_msg(' FORWARDING AUDIT EVENT: DELETE SECRET: DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' SECRET: ' + secret)

        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'DELETE_SECRET', toList(secret), line)

        return

    #
    # CREATE APPLICATION Event
    #
    # Dec 16 18:19:06 c1mas2 marathon.sh[5635]: [2016-12-16 18:19:06,199] INFO timestamp=2016-12-16T23:19:06.199Z type=audit uid=adminuser srcip=10.0.0.201 srcport=38846 dstip=10.0.0.202 dstport=8443 authorizer=marathon action=CreateRunSpec path=/gregsapp2 result=allow (dcos.marathon.auditlog:qtp706960270-1267)

    result = re.search(r'type=audit uid=(.+) srcip=.+ srcport=.+ dstip=.+ dstport=.+ authorizer=.+ action=CreateRunSpec path=(.[^ ]+) result=allow', line)

    if result:
        # Get the requesting user and the created application
        requestingUser = result.group(1)
        application = result.group(2)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        # Get the next lines to find the cmd or container and requested scale
        count = 0
        createdApplications = ''
        while count < 20:
            if p.poll(100):
                byteLine = f.stdout.readline()
                line = byteLine.decode("utf-8")


                escapedApplication = application.replace('/', '\\/')
                searchPattern = r'Scale\(App\(' + escapedApplication + ', (.+)=(".+").+instances=(.+)'

                #print (' XXX Using search pattern: ' + searchPattern)
                #print (' XXX Checking Line: ' + line)

                result2 = re.search(searchPattern, line)

                if result2:

                    cmdOrImageFlag = result2.group(1)
                    cmdOrImage = result2.group(2)
                    nextComputedScale = result2.group(3)

                    createdApplications += '[ ' + application + ' ' + cmdOrImageFlag + ': ' + cmdOrImage + ' (Instances: ' + nextComputedScale + ' ] '

                    #print(' XXX Got CREATED APP App: ' + application + ', Cmd or Image: ' + cmdOrImage + ', Instances: ' + nextComputedScale)

                else:
                    if 'INFO Deploy plan with force' in line or 'NO STEPS' in line:
                        if 'NO STEPS' in line:
                            createdApplications = ' NO CHANGES OR CREATED APPLICATION GROUP'
                        break; # exit the loop, because we got all the computed scaled apps

            count += 1

        log_msg(' FORWARDING AUDIT EVENT: CREATE APP: DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' APPLICATION: ' + application + ' DETAILS: ' + createdApplications)

        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'CREATE_APPLICATION', createdApplications, line)

        return
        
    #
    # DESTROY APPLICATION Event
    #
    # Dec 16 18:09:23 c1mas2 marathon.sh[5635]: [2016-12-16 18:09:23,605] INFO timestamp=2016-12-16T23:09:23.605Z type=audit uid=adminuser srcip=10.0.0.201 srcport=33518 dstip=10.0.0.202 dstport=8443 authorizer=marathon action=DeleteRunSpec path=/gregsapp1 result=allow (dcos.marathon.auditlog:marathon-akka.actor.default-dispatcher-16) 

    result = re.search(r'type=audit uid=(.+) srcip=.+ srcport=.+ dstip=.+ dstport=.+ authorizer=.+ action=DeleteRunSpec path=(.[^ ]+) result=allow', line)

    if result:
        # Get the requesting user and the destroyed application 
        requestingUser = result.group(1)
        application = result.group(2)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        log_msg(' FORWARDING AUDIT EVENT: DESTROY APP: DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' APPLICATION: ' + application)

        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'DESTROY_APPLICATION', toList(application), line)

        return
        
    #
    # SCALE OR RESTART APPLICATION Event
    #
    #

    scaleInstances = ''
    restartRequest = False

    result = re.search(r'type=audit uid=(.+) srcip=.+ srcport=.+ dstip=.+ dstport=.+ authorizer=.+ action=UpdateRunSpec path=(.[^ ]+) result=allow', line)

    if result:
        # Get the requesting user and the scaled application 
        requestingUser = result.group(1)
        application = result.group(2)

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        # Get the next lines to find the cmd and requested scale
        count = 0
        while count < 10:
            
            if p.poll(100):
                byteLine = f.stdout.readline()
                line = byteLine.decode("utf-8")

                escapedApplication = application.replace('/', '\\/')

                # First see if it is a scale request

                searchPattern = r'Scale\(App\(' + escapedApplication + ', (.+)=(".+").+instances=(.+)'
                result2 = re.search(searchPattern, line)

                if result2:
                    cmdOrImageFlag = result2.group(1)
                    cmdOrImage = result2.group(2)
                    scaleInstances = result2.group(3)

                    break      # Exit the loop

                # If not a scale event, see if it is a restart event

                searchPattern = r'Restart\(App\(' + escapedApplication + ', (.+)=(".+")'
                result2 = re.search(searchPattern, line)

                if result2:
                    restartRequest = True
                    cmdOrImageFlag = result2.group(1)
                    cmdOrImage = result2.group(2)

                    break       # Exit the loop

            count += 1

        if restartRequest == True:

            log_msg(' FORWARDING AUDIT EVENT: RESTART APP: DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' APPLICATION: ' + application + ' DETAILS: ' + cmdOrImageFlag + ': ' + cmdOrImage )
            # Insert log entry into Elasticsearch
            create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'RESTART_APPLICATION', toList(application,cmdOrImageFlag+'='+cmdOrImage), line)

        else:  # restartRequest == True

            log_msg(' FORWARDING AUDIT EVENT: SCALE APP: DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' APPLICATION: ' + application + ' DETAILS: ' + cmdOrImageFlag + ': ' + cmdOrImage + ' Insances: ' + scaleInstances )
            # Insert log entry into Elasticsearch
            create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'SCALE_APPLICATION', toList(application,cmdOrImageFlag+'='+cmdOrImage, scaleInstances), line)

        return

    #
    # SCALE APPLICATION GROUP Event
    #
    #
    result = re.search(r'type=audit uid=(.+) srcip=.+ srcport=.+ dstip=.+ dstport=.+ authorizer=.+ action=UpdateGroup path=(.[^ ]+) result=allow', line)
    
    if result:
        # Get the requesting user and the scaled application group
        requestingUser = result.group(1)
        applicationGroup = result.group(2)

        #print(' XXX Got SCALE APP GROUP: ' + applicationGroup + ' - looking for new instance count')

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        # Get the next lines to find the cmd and requested scale
        count = 0
        scaledApplications = ''
        while count < 20:
            if p.poll(100):
                byteLine = f.stdout.readline()
                line = byteLine.decode("utf-8")


                escapedApplicationGroup = applicationGroup.replace('/', '\\/')
                searchPattern = r'Scale\(App\(' + escapedApplicationGroup + '\/(.+), (.+)=(".+").+instances=(.+)'

                #print (' XXX Using search pattern: ' + searchPattern)
                #print (' XXX Checking Line: ' + line)

                result2 = re.search(searchPattern, line)

                if result2:

                    nextApplication = result2.group(1)
                    cmdOrImageFlag = result2.group(2)
                    cmdOrImage = result2.group(3)
                    nextComputedScale = result2.group(4)

                    scaledApplications += '\' ' + nextApplication + ', ' + cmdOrImageFlag + ': ' + cmdOrImage + ' (Instances: ' + nextComputedScale + ' \' '

                    #print(' Got SCALE APP GROUP App: ' + nextApplication + ' computed scale: ' + nextComputedScale)

                else:
                    if 'INFO Deploy plan with force' in line or 'NO STEPS' in line:
                        if 'NO STEPS' in line:
                            scaledApplications = ' NO CHANGES '
                        break; # exit the loop, because we got all the computed scaled apps

                count += 1

        log_msg(' FORWARDING AUDIT EVENT: SCALE APP GROUP: DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' APPLICATION GROUP: ' + applicationGroup + ' COMPUTED SCALE REQUESTS: ' + scaledApplications )

        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'SCALE_APPLICATION_GROUP', toList(applicationGroup, scaledApplications), line)

        return

    #
    # DESTROY APPLICATION GROUP Event
    #
    #
    result = re.search(r'type=audit uid=(.+) srcip=.+ srcport=.+ dstip=.+ dstport=.+ authorizer=.+ action=DeleteGroup path=(.[^ ]+) result=allow', line)
    
    if result:
        # Get the requesting user and the scaled application group
        requestingUser = result.group(1)
        applicationGroup = result.group(2)

        #print(' XXX Got DESTROY APP GROUP: ' + applicationGroup + ' - looking for new instance count')

        # Get the log entry date and time 
        result2 = re.search('^(?:\S+\s){5}(\S+)', line)
        dateStr = result2.group(1)
        result2 = re.search('^(?:\S+\s){6}(\S+)', line)
        timeStr = result2.group(1)

        # Get the next lines to find the cmd and requested scale
        count = 0
        destroyedApplications = ''
        while count < 20:
            if p.poll(100):
                byteLine = f.stdout.readline()
                line = byteLine.decode("utf-8")


                escapedApplicationGroup = applicationGroup.replace('/', '\\/')
                searchPattern = r'Stop\(App\(' + escapedApplicationGroup + '\/(.+), (.+)=(".+")'

                #print (' XXX Using search pattern: ' + searchPattern)
                #print (' XXX Checking Line: ' + line)

                result2 = re.search(searchPattern, line)

                if result2:

                    nextApplication = result2.group(1)
                    cmdOrImageFlag = result2.group(2)
                    cmdOrImage = result2.group(3)

                    destroyedApplications += ', ' + applicationGroup + '/' + nextApplication + ', ' + cmdOrImageFlag + ': ' + cmdOrImage

                    #print(' XXX Got DESTROY APP GROUP App: ' + nextApplication )

                else:
                    if 'INFO Deploy plan with force' in line or 'NO STEPS' in line:
                        if 'NO STEPS' in line:
                            destroyedApplications = ' NO APPS TO DESTROY '
                        else:
                            destroyedApplications = '\'' + destroyedApplications + '\''

                        break; # exit the loop, because we got all the computed scaled apps

            count += 1

        log_msg(' FORWARDING AUDIT EVENT: DESTROY APP GROUP: DATE: ' + dateStr + ' ' + timeStr + ' REQUESTED BY: ' + requestingUser + ' DETAILS: APPLICATION GROUP: ' + applicationGroup + ' ' + destroyedApplications )

        # Insert log entry into Elasticsearch
        create_elasticsearch_entry(es, dateStr, timeStr, requestingUser, 'DESTROY_APPLICATION_GROUP', toList(applicationGroup, destroyedApplications), line)

        return

    #
    # Print any unprocessed line
    #
    #print(' XXX Unprocess Line: ' + line)

    # End Function    
    return


#
# MAIN
#

def main(argv):

    args = ['journalctl', '--lines', '0', '--follow', 
                    '--unit=dcos-adminrouter.service', 
                    '--unit=dcos-marathon.service', 
                    '--unit=dcos-bouncer.service']

    f = subprocess.Popen(args, stdout=subprocess.PIPE)
    p = select.poll()
    p.register(f.stdout)
    es = None

    log_msg('Program Started')


    # Main Loop
    while True:

        # Connect to the Elasticsearch service running on DC/OS
        while es is None:
            es = get_elasticsearch_conn()
            if es is None:
                log_msg('  Waiting to try to connect to the Elasticsearch service')
                time.sleep(10)

        if p.poll(100):
            byteLine = f.stdout.readline()
            line = byteLine.decode("utf-8")

            check_log_file_entry(p, f, line, es)

if __name__ == "__main__":
    main(sys.argv)

# end of script
