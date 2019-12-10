#!/bin/bash

#remove previous instance

docker rm -f nginx

#run a local nginx server serving ./www/html

docker run \
	-d \
	--name=nginx \
	-v ./www/html:/usr/share/nginx/html \
	-v ./www/conf/:/etc/nginx:ro \
	-p 80:80 \
	nginx
