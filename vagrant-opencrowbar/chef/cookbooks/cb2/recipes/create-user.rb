execute "fix vagrant ssh dir perms" do
  command "chmod 0700 /home/vagrant/.ssh/"
  action :run
end

execute "fix vagrant ssh file perms" do
  command "chmod 0600 /home/vagrant/.ssh/*"
  action :run
end

# create a group and user on the OS:
user node["props"]["guest_username"] do
	home "/home/#{node["props"]["guest_username"]}"
	shell "/bin/bash"
	supports :manage_home=>true
	#gid node[:props][:guest_username]
	
end

group node["props"]["guest_username"] do
	action :create
end

# give guest user superpowers
power_group_name="admin"
case node[:platform]
when "ubuntu"
  power_group_name = "admin"
when "suse","centos","rhel"
  power_group_name = "wheel"
end
group "#{power_group_name}" do
  members node.props.guest_username
  append true
end

# this will allow you to use the shared folders
group "vagrant" do
  members node.props.guest_username
  append true
end

bash "add NOPASSWD to /etc/sudoers" do
  code "echo \"%#{power_group_name} ALL=NOPASSWD:ALL\" >> /etc/sudoers"
  not_if "grep \"^%#{power_group_name} ALL_NOPASSWD:ALL\" /etc/sudoers"
end

## give the user ssh public keys
directory "/home/#{node.props.guest_username}/.ssh" do
	owner node.props.guest_username
	mode "0700"
	action :create
end

execute "add_key" do
	command "echo \"#{node.props.user_sshpubkey}\" >> /home/#{node.props.guest_username}/.ssh/authorized_keys; chown #{node.props.guest_username} /home/#{node.props.guest_username}/.ssh/authorized_keys; chmod 500 /home/#{node.props.guest_username}/.ssh/authorized_keys; "
	creates "/home/#{node.props.guest_username}/.ssh/authorized_keys"
	action :run
	not_if "grep \"#{node.props.user_sshpubkey}\" /home/#{node.props.guest_username}/.ssh/authorized_keys "
end	

# add some universal packages
case node[:platform]
when "centos"
  package "screen"
when "ubuntu"
  package "byobu"
end

# setup timezone
execute "timezone setup" do
  case node[:platform]
  when "ubuntu"
    command "echo \"#{node.props.guest_timezone}\" > /etc/timezone; dpkg-reconfigure -f noninteractive tzdata"
  when "suse"
    command "echo \"TZ=#{node.props.guest_timezone}\" >> /home/#{node.props.guest_username}/.profile"
	  not_if "grep \"TZ=#{node.props.guest_timezone}\" /home/#{node.props.guest_username}/.profile"
  when "centos", "rhel"
    command "ln -sf /usr/share/zoneinfo/#{node.props.guest_timezone} /etc/localtime"
    not_if "ls -l /etc/localtime | grep #{node.props.guest_timezone}" 
  end
	action :run
end
