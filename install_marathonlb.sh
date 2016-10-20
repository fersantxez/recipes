#!/bin/bash
#
# SCRIPT:   deploy-marathon-lb-with-cert.sh
#
# DESCR:    Using the Enterprise DC/OS CLI to setup Marathon-LB with a Service Account
#       on Enterprise DC/OS
#
# NOTES:     Note: Please upgrade your DC/OS CLI to `0.4.12` for best results
#
 
 
# Check if the DC/OS CLI is in the PATH
CMD_FILE=$(which dcos)
 
if [ "$CMD_FILE" == "" ]
then
    echo
    echo " The DC/OS Command Line Interface binary is not installed or not in your path. Please install it."
    echo " Existing."
    echo
    exit 1
fi
 
 
# Check if the JQ program is in the PATH
 
CMD_FILE=$(which jq)
 
if [ "$CMD_FILE" == "" ]
then
    echo
    echo " The JSON Query (jq) binary is not installed or not in your path. Please install it."
    echo " Existing."
    echo
    exit 1
fi
 
# Check if the DC/OS CLI is 0.4.12
 
CLI_VER=$(dcos --version | grep dcoscli.version | cut -d '=' -f 2)
 
if [ "$CLI_VER" != "0.4.13" ] && [ "$CLI_VER" != "0.4.14" ]
then
    echo
    echo " Your DC/OS CLI version is not correct. Please upgrade your CLI version."
    echo " Existing. "
    exit 1
fi
 
# Check if user is logged into the CLI
 
while true
do
    AUTH_TOKEN=$(dcos config show core.dcos_acs_token 2>&1)
 
    if [[ "$AUTH_TOKEN" = *"doesn't exist"* ]]
    then
        echo
        echo " Not logged into the DC/OS CLI. Running login command now. Or press CTL-C "
        echo
        dcos auth login
    else
        break
    fi
done
 
# Check if the dcos acs token is valid
 
while true
do
    RESULT=$(dcos node 2>&1)
 
    if [[ "$RESULT" = *"Your core.dcos_acs_token is invalid"* ]]
    then
        echo
        echo " Your DC/OS dcos_acs_token is invalid. Running login command now. Or press CTRL-C "
        echo
        dcos auth login
    else
        break
    fi
done
# Install the Security Subcommand into the CLI
echo
 
dcos package install --yes --cli dcos-enterprise-cli
 
# Create/Install the Certificate for Marthon-LB
 
echo
echo " Creating/installing the certificate for Marthon-LB"
echo
echo " Please ignore the message: Failed to execute script dcos-security"
echo
 
dcos security org service-accounts keypair -l 4096 marathon-lb-private-key.pem marathon-lb-public-key.pem
 
dcos security org service-accounts create -p marathon-lb-public-key.pem -d "dcos_marathon_lb service account" dcos_marathon_lb
 
dcos security org service-accounts show dcos_marathon_lb
 
curl -skSL -X PUT -H 'Content-Type: application/json' -d '{"description": "Marathon Services"}' -H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:service:marathon:marathon:services:%252F
 
curl -skSL -X PUT -H 'Content-Type: application/json' -d '{"description": "Marathon Events"}' -H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:service:marathon:marathon:admin:events
 
curl -skSL -X PUT -H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:service:marathon:marathon:services:%252F/users/dcos_marathon_lb/read
 
curl -skSL -X PUT -H "Authorization: token=$(dcos config show core.dcos_acs_token)" $(dcos config show core.dcos_url)/acs/api/v1/acls/dcos:service:marathon:marathon:admin:events/users/dcos_marathon_lb/read
 
dcos security secrets create-sa-secret marathon-lb-private-key.pem dcos_marathon_lb marathon-lb
 
dcos security secrets list /
 
dcos security secrets get /marathon-lb --json | jq -r .value | jq
 
# Launch Marathon-LB using the secret and the cert created above
 
echo
echo " Deploying Marathon-LB using the cert and secret created"
echo
 
tee marathon-lb-secret-options.json <<'EOF'
{
     "marathon-lb": {
         "secret_name": "marathon-lb"
     }
}
EOF
 
dcos package install --options=marathon-lb-secret-options.json --yes marathon-lb
 
echo
echo "Script completed"
echo
 
# end of script
