APP_NAME=resilio
SHELL=sh
docker exec -it $(docker ps | grep $APP_NAME | sed -n '1p' | cut -d ' ' -f 1) $SHELL
