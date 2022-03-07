#!/bin/bash
docker run \
	--detach \
	--env FTP_PASS=123 \
	--env FTP_USER=user \
	--name ftpd \
	--publish 20-21:20-21/tcp \
	--publish 40000-40009:40000-40009/tcp \
	--volume /home/nobody:/home/user \
	garethflowers/ftp-server
