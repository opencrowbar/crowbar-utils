#!/bin/bash

${IP}=$(ip -4 -o a | grep eth0 | awk '{print $4}' |cut -d'/' -f1)
${HOSTNAME}=$(hostname -f)
${ALIAS}=$(echo ${HOSTNAME} | cut -d'.' -f1)
#${CONTAINER_NUMBER}=$(get the damn container unique string)


sed -i "s/HOSTNAME/${HOSTNAME}/g" < register_container.json > ${ALIAS}.json
sed -i "s/ALIAS/${ALIAS}/g" < register_container.json > ${ALIAS}.json
sed -i "s/IP_ADDRESS/${IP}/g" < register_container.json > ${ALIAS}.json

/usr/bin/curl --digest -u 'developer:Cr0wbar!' --data @/root/${ALIAS}.json -H "Content-Type:application/json" --url http://${ADMIN_SERVER}/api/v2/nodes

