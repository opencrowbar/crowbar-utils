#!/bin/bash

# admin server address required

ADMIN_SERVER="192.168.124.10:3000"
#CROWBAR_INSTALL_KEY=$(sed 's/:/\\:/' /etc/crowbar.install.key)
CROWBAR_INSTALL_KEY=$(cat /etc/crowbar.install.key)
for x in $(seq 3 3)
do
	echo $x
	#CONTAINER_ID=$(sudo docker run -d ubuntu /bin/sh -c "while true; do echo hello world; sleep 1; done")
	#docker run -d ubuntu /bin/sh -c "while true; do echo hello world; sleep 1; done"
	#docker run -d newgoliath/crowbar-workload -e "ADMIN_SERVER=${ADMIN_SERVER} CROWBAR_INSTALL_KEY=`cat /etc/crowbar.install.key`" -h "container$x.crowbar.org" -dns ${ADMIN_SERVER}
	CMD="docker run -d -e ADMIN_SERVER=${ADMIN_SERVER} -e CROWBAR_INSTALL_KEY=${CROWBAR_INSTALL_KEY} -h container$x.crowbar.org  newgoliath/crowbar-workload /bin/sh -c '/root/register-container.sh; /usr/sbin/sshd -D"
	echo $CMD
	#$($CMD)
done
