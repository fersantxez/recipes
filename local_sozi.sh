#!/bin/bash

#vars
NAME=sozi
MOUNT_DIR=/foo #mount current dir as:
#https://hub.docker.com/r/escalope/inkscape-sozi

#functions
print_usage() {
    cat <<EOM
    Usage:
    $(basename $0) inkscape || sozi || sozi-to-video mypresentation.sozi.html
	https://sozi.baierouge.fr/pages/20-install.html#installing-from-a-docker-image
EOM
}

# Prefix output and write to STDERR:
error() {
	echo -e "\n\n${RED}** $(basename $0) error${NC}: $@\n" >&2
	print_usage
	exit 1 #Exit on error
}

# Display a formatted message to shell:
message() {
	echo -e "\n** $@" >&2
}

# Check for command presence in $PATH, errors:
check_command() {
	TESTCOMMAND=$1
	HELPTEXT=$2

	printf '%-50s' " - $TESTCOMMAND..."
	command -v $TESTCOMMAND >/dev/null 2>&1 || {
		message "${RED}[ MISSING ]${NC}"
		error "The '$TESTCOMMAND' command was not found. $HELPTEXT"
	}
	echo "[ OK ]"
}

# Argument validation
# Check at least two positional arguments
if (( "$#" < 1 )); then 
	error "At least 1 argument required, $# provided"
fi

# Check dependencies
check_command docker "Please install Docker from http://docs.docker.com/install"
check_command xhost "Please install xquartz if running on OSX. Other OSs, check the availability of xhost:
ruby -e '$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)' < /dev/null 2> /dev/null ; brew install caskroom/cask/brew-cask 2> /dev/null
brew cask install xquartz
"




docker rm -f $NAME

#ensure accept X connections
xhost +172.17.0.1 #assumes docker networking=nat

#run docker image passing over the arguments
docker run \
	--user $UID \
	-ti \
	--rm \
	-e DISPLAY=:0 \
	-v /tmp/.X11-unix:/tmp/.X11-unix \
	-w $MOUNT_DIR \
	-v "`pwd`":$MOUNT_DIR \
    	escalope/inkscape-sozi:latest \
    	"$@"  #pass container args
