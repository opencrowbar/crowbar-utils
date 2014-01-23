#!/bin/bash

IP=$(ip -4 -o a | grep eth0 | awk '{print $4}' |cut -d'/' -f1)
HOSTNAME=$(hostname -f)

if [[ ! ${HOSTNAME} =~ \..*\. ]]
then
  HOSTNAME="${HOSTNAME}.requires.fqdn"
fi

ALIAS=$(echo ${HOSTNAME} | cut -d'.' -f1)
# no digits at beginning of alias
if [[ ${HOSTNAME} =~ ^[[:digit:]]+ ]]
then
  ALIAS="aa${ALIAS}"
fi
#${CONTAINER_NUMBER}=$(get the damn container unique string)

sed -i "s/DESCRIPTION/$(date)/g"  /root/register-container.json 
sed -i "s/HOSTNAME/${HOSTNAME}/g"  /root/register-container.json 
sed -i "s/ALIAS/${ALIAS}/g"  /root/register-container.json 
sed -i "s/IPADDRESS/${IP}/g"  /root/register-container.json 

cat /root/register-container.json

CURL="/usr/bin/curl --digest -u ${CROWBAR_INSTALL_KEY} --data @/root/register-container.json -H Content-Type:application/json --url http://${ADMIN_SERVER}/api/v2/nodes"
echo ${CURL}
${CURL}

