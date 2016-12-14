#!/bin/bash
#remove exited containers
docker ps --filter status=dead --filter status=exited -aq \
  | xargs docker rm -v

# remove unused images:
docker images --no-trunc | grep '<none>' | awk '{ print $3 }' | xargs -r docker rmi

#clean up dangling volumes
docker volume ls -qf dangling=true | xargs -r docker volume rm

# remove unused volumes:
find '/var/lib/docker/volumes/' -mindepth 1 -maxdepth 1 -type d | grep -vFf <(
  docker ps -aq | xargs docker inspect | jq -r '.[] | .Mounts | .[] | .Name | select(.)'
) | xargs -r rm -fr

#add "-f" flag to below to remove all including running
# Delete all containers
docker rm $(docker ps -a -q)
# Delete all images
docker rmi $(docker images -q)



    


