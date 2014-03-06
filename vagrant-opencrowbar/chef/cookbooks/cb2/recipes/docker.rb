# add deb repo from docker upstream; grab key from keyserver

package "lxc-docker"


template "/etc/default/docker" do
	source "docker.erb"
	mode 0440	
	owner "root"
	group "root"
	variables ({:proxy => node[:props][:http_proxy] })
end

if node[:platform] == "ubuntu" 

  #include_recipe "apt::default"

  #network reconfig for docker bridge
  admin_network = '192.168.124.10/24'
  admin_nic = 'eth0'
  docker_bridge_dev = 'docker0'

  bash "set docker bridge ip" do
    command "ip addr add #{admin_network} dev #{docker_bridge_dev}"
    only_if "ip addr show #{admin_nic} | grep ${admin_network}"
  end

  bash "remove admin IP from #{admin_nic}" do
    command "ip addr flush #{admin_nic}"
    only_if "ip addr show #{admin_nic} | grep ${admin_network}"
  end

  bash "slave admin nic to docker bridge" do
    command "ip dev set #{admin_nic} master #{docker_bridge_dev}"
    not_if "ip addr show ${admin_nic} | grep master #{docker_bridge_dev}"
  end

end

if node[:platform] == "centos"
  ### docs from http://nareshv.blogspot.com/2013/08/installing-dockerio-on-centos-64-64-bit.html
  ## disable SE linux
  #cat /etc/selinux/config 
  ## This file controls the state of SELinux on the system.
  ## SELINUX= can take one of these three values:
  ##       enforcing - SELinux security policy is enforced.
  ##       permissive - SELinux prints warnings instead of enforcing.
  ##       disabled - SELinux is fully disabled.
  #SELINUX=disabled
  ## SELINUXTYPE= type of policy in use. Possible values are:
  ##       targeted - Only targeted network daemons are protected.
  ##       strict - Full SELinux protection.
  #SELINUXTYPE=targeted

  # install EPEL
  #yum_package "epel for docker" do
  #  http://ftp.riken.jp/Linux/fedora/epel/6/i386/epel-release-6-8.noarch.rpm
  #end

  #cd /etc/yum.repos.d
  #sudo wget http://www.hop5.in/yum/el6/hop5.repo

end

service "docker" do
  action :start
end

execute "docker permissions" do
  command "chmod 666 /var/run/docker.sock"
end

group "docker" do
  members node.props.guest_username
  append true
end

execute "preload docker opencrowbar image" do
	user "#{node[:props][:guest_username]}"
	group "#{node[:props][:guest_username]}"
  command "docker pull opencrowbar/centos:6.5-4"
end

