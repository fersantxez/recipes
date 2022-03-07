#!/bin/bash

#remove previous instance

docker rm -f redis

#run a local redis server 

docker run \
	-d \
	--name=redis \
	-p 6379:6379 \
	redis \
	redis-server
