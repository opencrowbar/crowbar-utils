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
#set -x
ADMIN="192.168.124.10"
NETWORK="192.168.124.1/24"
IMAGE="ubuntu-12.04"
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

dhclient eth1 # get an external IP address, not the admin network
DOCKER_BRIDGE='docker0'

install_docker() {
	log "Trying to install/upgrade Docker"
	sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
	curl -s https://get.docker.io/ubuntu/ | sudo sh
}

if ! dpkg -s lxc-docker > /dev/null # for ubuntu
#if docker version # for anything else if docker is running
then 
	install_docker
else
	# Check for minimum docker version
	DOCKER_VERSION=$(apt-cache show lxc-docker | grep Version: | awk '{print $2}') # ubuntu
	#DOCKER_VERSION=$(docker version | grep "Client" | awk '{print $2}') # get version from the proc
	DOCKER_MINOR_VERSION=$(echo $DOCKER_VERSION | cut -d'.' -f2)
	[[ $DOCKER_VERSION =~ ^0+\. ]] && [[ $DOCKER_MINOR_VERSION < 7 ]] && install_docker
fi

log "Admin: ${ADMIN} Network: ${NETWORK} Image: ${IMAGE}"

# Find interface that can route to admin server
# it will be our route to the admin network
# it'll need its address removed, then that address added to the bridge,
# then have the interface added to the bridge

# one liner (illegible, ignore):
#ip -o -4 a | grep $(tracepath 192.168.124.10 | head -1 | awk '{ print $2 }' ) | awk '{print $2}'

# or, more legibly:
# get IP address of first hop to $ADMIN
ping -c 1 ${ADMIN} > /dev/null || die "Admin server must be accessible."
GATEWAY_ADDRESS=$(tracepath -n ${ADMIN} | head -1 | awk '{ print $2 }' )
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
    log "found good bridge ${BR}"
    GOOD_BRIDGE=${BR}
    break
  fi
done

# setup docker to run its bridge on the right network

if [[ ${DOCKER_BRIDGE} == ${GOOD_BRIDGE} ]]
then
  # all clear, all done
  log "Docker is setup OK."
  exit 0
fi
# should really clean up any bad bridges here

# reconfigure docker
stop docker 2>&1 > /dev/null

# change an existing docker config
# remove yucky custom bridges
if grep -q "^[^#].*\-b=" /etc/default/docker 
then
  perl -pi -e "s/-b=\w+//" /etc/default/docker
fi

# does it have a DOCKER_OPTS?
if ! grep -q "^[^#]DOCKER_OPTS.*" /etc/default/docker
then
  echo "DOCKER_OPTS=\"-bip=${NETWORK}\"" >> /etc/default/docker
else
  if grep -q "^[^#]DOCKER_OPTS.*\-bip=${NETWORK}"
  then
    # we're all good, nothing to change
    log "Docker already configured properly"
  else
    # change to the admin network by appending -bip=${NETWORK}
    sed -i "s/^DOCKER_OPTS=\"\(.*\)\"/DOCKER_OPTS=\"\1 -bip=${NETWORK}\"/" /etc/default/docker
  fi
fi

#elif grep -q ^DOCKER_OPTS /etc/default/docker ## there is a DOCKER_OPTS, hack it to use our admin network

log "Starting reconfigured Docker."
start docker
sleep 5

# Add NIC to Bridge
# remove IP address from the gateway NIC
ip addr del ${ADMIN} dev ${GATEWAY_INTERFACE}
# add IP address to the bridge
ip address add ${GATEWAY_ADDRESS} dev docker0 || die "ip address add error"
# add the Gateway NIC to the bridge
#brctl addif ${GOOD_BRIDGE} ${GATEWAY_INTERFACE}
ip link set ${GATEWAY_INTERFACE} master docker0
#ip link set ${GOOD_BRIDGE} up # docker already flexible

#!/bin/bash

ensure_service_running () {
    service="$1"
    regexp="${2:-running}"
    if service $service status | egrep -q "$regexp"; then
        echo "$service is already running - no need to start."
    else
        service $service start
    fi
}

die() {
    echo "$(date '+%F %T %z'): $@"
    exit 1
}

if [[ -f /etc/redhat-release || -f /etc/centos-release ]] && [[ ! -d /etc/chef-server ]]; then
    OS=redhat
    die "Not supporting RHAT yet"
    #yum install -y chef chef-server
elif [[ -d /etc/apt ]]; then
    OS=ubuntu
    apt-get -y install lxc-docker
elif [[ -f /etc/SuSE-release ]]; then
    die "Not supporting SuSE yet."
    #if grep -q openSUSE /etc/SuSE-release; then
    #    OS=opensuse
    #    zypper install -y -l chef chef-server
    #else
    #    OS=suse
    #fi
else
    die "Staged on to unknown OS media!"
fi

if [[ $OS = ubuntu ]] && [[ ! dpkg -s lxc-docker  ]]; then
    # Set up initial config
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 36A1D7869245C8950F966E92D8576A8BA88D21E9
    curl -s https://get.docker.io/ubuntu/ | sudo sh

    chef-server-ctl reconfigure
    mkdir -p /etc/chef-server
    chef-server-ctl test || {
        echo "Could not bring up valid chef server!"
        exit 1
    }
    mkdir -p /etc/chef
    ln -s /etc/chef-server/chef-webui.pem /etc/chef/webui.pem
    ln -s /etc/chef-server/chef-validator.pem /etc/chef/validation.pem
    cat > /etc/init.d/chef-server <<EOF
#!/bin/bash
### BEGIN INIT INFO
# Provides:          chef-server
# Required-Start:    \$syslog \$network \$named
# Required-Stop:     \$syslog \$network \$named
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start chef-server at boot time
# Description:       Enable chef server
### END INIT INFO

# chkconfig 2345 10 90
# description Chef Server wrapper
exec chef-server-ctl "\$@"
EOF
    chmod 755 /etc/init.d/chef-server
    if [[ $OS = ubuntu ]]; then
        update-rc.d chef-server defaults
        update-rc.d chef-server enable
    else
        chkconfig chef-server on
    fi
elif [[ $OS = suse ]]; then
    # Default password in chef webui to password
    sed -i 's/web_ui_admin_default_password ".*"/web_ui_admin_default_password "password"/' \
        /etc/chef/webui.rb
    chkconfig rabbitmq-server on
    if ! rabbitmqctl status > /dev/null 2>&1; then
	echo "RabbitMQ not running. Starting..."
	chkconfig rabbitmq-server on
	ensure_service_running rabbitmq-server || \
            die "Cannot start rabbitmq-server. Aborting."
        sleep 5
    fi
    rabbitmqctl list_vhosts | grep -q '^/chef' || \
        rabbitmqctl add_vhost /chef || \
        die "Could not create default rabbitmq Chef vhost"
    rabbitmqctl list_users | grep -q chef || {
        rabbitmqctl add_user chef "$rabbit_chef_password"
        # Update "amqp_pass" in  /etc/chef/server.rb and solr.rb
        sed -i 's/amqp_pass ".*"/amqp_pass "'"$rabbit_chef_password"'"/' /etc/chef/{server,solr}.rb
    } || die "Could not create rabbitmq Chef user"
    rabbitmqctl list_permissions |grep -q chef || \
	rabbitmqctl set_permissions -p /chef chef ".*" ".*" ".*" || \
        die "Could not set proper rabbitmq Chef permissions."
    echo "Starting CouchDB..."
    chkconfig couchdb on
    ensure_service_running couchdb

    services='solr expander server server-webui'
    for service in $services; do
        chkconfig chef-${service} on
    done

    for service in $services; do
        ensure_service_running chef-${service}
    done

    # chef-server-webui won't start if /etc/chef/webui.pem doesn't exist, which
    # may be the case (chef-server generates it if not present, and if the webui
    # starts too soon, it won't be there yet).
    for ((x=1; x<6; x++)); do
        sleep 10
        service chef-server-webui status >/dev/null && { chef_webui_running=true; break; }
        service chef-server-webui start
    done
    if [[ ! $chef_webui_running ]]; then
        echo "WARNING: unable to start chef-server-webui"
    fi
    perl -i -pe 's{<maxFieldLength>.*</maxFieldLength>}{<maxFieldLength>200000</maxFieldLength>}' /var/lib/chef/solr/conf/solrconfig.xml

    service chef-solr restart
fi

if [[ ! -e $HOME/.chef/knife.rb ]]; then
    echo "Creating chef client for root on admin node"
    mkdir -p "$HOME/.chef"
    EDITOR=/bin/true knife client create root -a --file "$HOME/.chef/client.pem" -u chef-webui -k /etc/chef-server/chef-webui.pem -s "https://$(hostname --fqdn)"
    cat > "$HOME"/.chef/knife.rb <<EOF
log_level                :info
log_location             STDOUT
node_name                'root'
client_key               '$HOME/.chef/client.pem'
validation_client_name   'chef-validator'
validation_key           '/etc/chef-server/chef-validator.pem'
chef_server_url          'https://$(hostname --fqdn)'
syntax_check_cache_path  '$HOME/.chef/syntax_check_cache'
EOF
fi

# Create a client for the Crowbar user.
if [[ ! -e /home/crowbar/.chef/knife.rb ]]; then
    echo "Creating chef client for Crowbar on admin node"
    mkdir /home/crowbar/.chef
    KEYFILE="/home/crowbar/.chef/crowbar.pem"
    EDITOR=/bin/true knife client create crowbar -a --file $KEYFILE -u chef-webui -k /etc/chef-server/chef-webui.pem
    cat > /home/crowbar/.chef/knife.rb <<EOF
log_level                :info
log_location             STDOUT
node_name                'crowbar'
client_key               '$KEYFILE'
validation_client_name   'chef-validator'
validation_key           '/etc/chef-server/chef-validator.pem'
chef_server_url          'https://$(hostname --fqdn)'
syntax_check_cache_path  '/home/crowbar/.chef/syntax_check_cache'
EOF
    chown -R crowbar:crowbar /home/crowbar/.chef/
fi
