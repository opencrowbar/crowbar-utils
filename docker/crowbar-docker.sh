#!/bin/bash

# argv:
# admin server IP, 
# a network/CIDR 
# an IP address

# 1) admin server IP
# 2) network and netmask docker will run
# 3) image name to run
set -x
ADMIN="192.168.124.10"
NETWORK="192.168.124.1/24"
IMAGE="ubuntu-12.04"

die() { log "$@" >&2; res=1; exit 1; }
log() { printf "$(date '+%F %T %z'): %s\n" "$@" >&2; }

brctl show > /dev/null || die "install brctl, fool."

while (($# > 0)); do
  case $1 in
    --admin) shift
      ADMIN={$1-"192.168.124.10"};;
    --network) shift
      NETWORK={$1-"192.168.124.0/24"};;
    --image) shift
      IMAGE={$1-"ubuntu-12.04"};;
    *)
      echo "Unknown option $1"
      exit 1;;
  esac
  shift
done

echo ${ADMIN} ${NETWORK} ${IMAGE}

# is Docker running? get its bridge
DOCKER_BRIDGE=''

if ps -o command= -C docker
then
  # docker running with custom bridge? get bridge
  DOCKER_COMMAND=$(ps -o command= -C docker)
  if [[ "${DOCKER_COMMAND}" == *-b=* ]]
  then
    DOCKER_BRIDGE=$(expr "${DOCKER_COMMAND}" : '.*-b=\(.*\)\>.*')
    echo ${DOCKER_BRIDGE}
  else
  # otherwise set bridge to default
    echo "use default bridge: docker0"
    DOCKER_BRIDGE='docker0'
  fi
fi

# does a bridge have this network?

BRIDGES=($(brctl show | sed -n '2,$ s/^\(\w\+\).*$/\1/p'))
GOOD_BRIDGE=''
for BR in ${BRIDGES[@]}; do
  if ip -o -4 a show dev ${BR} | grep -q "inet ${NETWORK}" 
  #if [ $(ip -o -4 a show dev ${BR} | grep -q "inet ${NETWORK}") ]
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
  brctl addbr ${MY_BRIDGE}
  ip address add ${NETWORK} dev ${MY_BRIDGE} || die "ip address add error"
  ip link set dev ${MY_BRIDGE} up
  GOOD_BRIDGE=${MY_BRIDGE}
fi

# setup docker to use the good bridge
if [[ ${DOCKER_BRIDGE} != ${GOOD_BRIDGE} ]]
then
  stop docker
  # change an existing config
  grep '\-b=' /etc/default/docker && perl -pi -e "s/-b=\w+/-b=${GOOD_BRIDGE}/" /etc/default/docker
  # or add to a file without a config
  grep DOCKER_OPTS /etc/default/docker || echo "DOCKER_OPTS=\"-b=${GOOD_BRIDGE}\"" >> /etc/default/docker
  start docker
fi

exit 1
# are containers running?

echo "You've gotta stop your containers to reconfigure Docker."
exit 1


# check network

# create Container with IP

get_ips_of_bridge() {
  local bridge
}

get_interface_of_IP() {
  echo $(ip -4 -o a | grep $1)
}
