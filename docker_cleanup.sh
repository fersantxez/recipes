#remove exited containers
docker ps --filter status=dead --filter status=exited -aq \
  | xargs docker rm -v

#clean up dangling volumes
docker volume ls -qf dangling=true | xargs -r docker volume rm

#add "-f" flag to below to remove all including running
# Delete all containers
docker rm $(docker ps -a -q)
# Delete all images
docker rmi $(docker images -q)
