#!/bin/bash

# sets up the network and reconfigures docker, then launches a container.
# creates/updates a bridge to contain the proper network
# adds the NIC to it that will route to the admin server
# reconfigures docker to use that bridge
# runs container

# argv:
# 1) admin server IP
# 2) network and netmask docker will run
# 3) image name to run
set -x
#ADMIN="192.168.124.10"
#NETWORK="192.168.124.1/24"
#IMAGE="ubuntu-12.04"
DEBUG=1

die() { log "$@" >&2; res=1; exit 1; }
log() { if [[ -z "$DEBUG" ]]; then  printf "$(date '+%F %T %z'): %s\n" "$@" >&2 ;fi }

brctl show > /dev/null || die "install brctl, fool."

while (($# > 0)); do
  case $1 in
    --admin) shift
      ADMIN=${1:-"192.168.124.10"};;
    --network) shift
      NETWORK=${1:-"192.168.124.0/24"};;
    --image) shift
      IMAGE=${1:-"ubuntu-12.04"};;
    *)
      echo "Unknown option $1"
      exit 1;;
  esac
  shift
done

# Check for minimum docker version
DOCKER_VERSION=$(docker version | grep "Client" | awk '{print $2}')
[[ $DOCKER_VERSION =~ ^0+\. ]] && die "Need Docker version >0.7.0.  Please upgrade it."
DOCKER_MINOR_VERSION=$(echo $DOCKER_VERSION | cut -d'.' -f2)
[[ $DOCKER_MINOR_VERSION < 7 ]] && die "Need Docker version >0.7.0.  Please upgrade it."
# sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
# curl -s https://get.docker.io/ubuntu/ | sudo sh

log "Admin: ${ADMIN} Network: ${NETWORK} Image: ${IMAGE}"

# is Docker running? get its bridge
DOCKER_BRIDGE=''
if ps -o command= -C docker
then
  # docker running with custom bridge? get bridge
  DOCKER_COMMAND=$(ps -o command= -C docker)
  if [[ "${DOCKER_COMMAND}" == *-b=* ]]
  then
    DOCKER_BRIDGE=$(expr "${DOCKER_COMMAND}" : '.*-b=\(.*\)\>.*')
    log "Found bridge: ${DOCKER_BRIDGE}"
  else
  # otherwise set bridge to default
    log "Docker is using bridge: docker0"
    DOCKER_BRIDGE='docker0'
  fi
fi

# Find interface that can route to admin server
# it will be our route to the admin network
# it'll need its address removed, then that address added to the bridge,
# then have the interface added to the bridge

# one liner (illegible, ignore):
#ip -o -4 a | grep $(tracepath 192.168.124.10 | head -1 | awk '{ print $2 }' ) | awk '{print $2}'

# or, more legibly:
# get IP address of first hop to $ADMIN
ping -c 1 ${ADMIN} || die "Admin server must be accessible."
GATEWAY_ADDRESS=$(tracepath ${ADMIN} | head -1 | awk '{ print $2 }' )
GATEWAY_ADDRESS=$(ip -o -4 a | grep $GATEWAY_ADDRESS | awk '{print $4}')
# get interface from above IP address
GATEWAY_INTERFACE=$(ip -o -4 a | grep $GATEWAY_ADDRESS | awk '{print $2}')
log "Gateway to Admin: ${GATEWAY_INTERFACE}"

# does a bridge have this network?
BRIDGES=($(brctl show | sed -n '2,$ s/^\(\w\+\).*$/\1/p'))
GOOD_BRIDGE=''
for BR in ${BRIDGES[@]}; do
  # TODO: this may be wrong.  It'll find the IP address, but  not the network
  # might be better to search for the route
  if  ip -o -4 a show dev ${BR} | grep -q "inet ${NETWORK}"   ||  ip -o -4 a show dev ${BR} | grep -q "inet ${ADMIN}"
  then
    echo found ${BR}
    GOOD_BRIDGE=${BR}
    break
  fi
done

# create bridge if necessary
if [ -z "${GOOD_BRIDGE}" ]
then
  MY_BRIDGE="br${RANDOM}"
  brctl addbr ${MY_BRIDGE} || die "Cant add bridge: $MY_BRIDGE"
  GOOD_BRIDGE=${MY_BRIDGE}
fi
log "Using bridge ${GOOD_BRIDGE}"

# setup docker to use the good bridge
if [[ ${DOCKER_BRIDGE} != ${GOOD_BRIDGE} ]]
then
  stop docker 2>&1 > /dev/null
  # change an existing docker config
  if grep -q '^[^#].*\-b=' /etc/default/docker 
  then
    perl -pi -e "s/-b=\w+/-b=${GOOD_BRIDGE}/" /etc/default/docker
  # or add to a file without a config
  elif grep -q ^DOCKER_OPTS /etc/default/docker 
  then
    sed -i "s/^DOCKER_OPTS=\"\(.*\)\"/DOCKER_OPTS=\"\1 -b=${GOOD_BRIDGE}\"/" /etc/default/docker
  else
    echo "DOCKER_OPTS=\"-b=${GOOD_BRIDGE}\"" >> /etc/default/docker
  fi
fi

# are containers running?

echo "You've gotta stop your containers to reconfigure Docker."

# Add NIC to Bridge
# remove IP address from the gateway NIC
ip addr del ${ADMIN} dev ${GATEWAY_INTERFACE}
# add IP address to the bridge
ip address add ${GATEWAY_ADDRESS} dev ${GOOD_BRIDGE} || die "ip address add error"
# add the Gateway NIC to the bridge
#brctl addif ${GOOD_BRIDGE} ${GATEWAY_INTERFACE}
ip link set ${GATEWAY_INTERFACE} master ${GOOD_BRIDGE}
ip link set ${GOOD_BRIDGE} up

start docker

# make a container and network out of it.

# run image to create Container

get_ips_of_bridge() {
  local bridge
}

get_interface_of_IP() {
  echo $(ip -4 -o a | grep $1)
}
