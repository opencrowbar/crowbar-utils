case node[:platform]
when "ubuntu"
  package "git"
  package "mkisofs"
  package "rpm"
  package "rpm2cpio"
  package "dh-make"
  package "debootstrap"
  package "createrepo"
  package "debhelper"
  package "cabextract"
  # testing packages
  package "erlang-base" package "erlang-inets"
#  package "ruby-dev" 
#  package "ruby-bundler" 
  package "libsqlite3-dev" 
  package "g++" 
  package "graphviz"
when "suse"
  package "git"
  package "mkisofs"
  package "rpm"
  package "cabextract"
when "centos"
  package "genisoimage"
  #package "debhelper"
  #package "debootstrap"
  package "createrepo"
  package "livecd-tools"
  package "cabextract"
end

# setup .netrc for github access
template "/home/#{node.props.guest_username}/.netrc" do
	source "netrc.erb"
	mode 0400
	owner node.props.guest_username
	group node.props.guest_username
	variables ({ 
		:github_id => node.props.github_id,
		:github_password => node.props.github_password
 	})
end


# setup git usernames
log ("Creating gitconfig")
template "/home/#{node.props.guest_username}/.gitconfig" do
	source "gitconfig.erb"
	mode 0400
	owner node.props.guest_username
	group node.props.guest_username
	variables ({ 
		:username => node.props.git_user_name,
		:user_email => node.props.git_user_email
 	})
end

# add some remotes
node.props.attribute?('github_extra_remotes') &&
node.props[:github_extra_remotes].each do | remote_name, remote_url |
  log "Adding extra git remote repositories"
  execute "set remote #{remote_name} with url #{remote_url}" do
    user node.props.guest_username
    cwd "/home/#{node.props.guest_username}/opencrowbar/core/"
    command "git remote add #{remote_name} #{remote_url}; git fetch #{remote_name}"
    action :run
    not_if "git remote -v #{remote_name}", 
      :user => node.props.guest_username, 
      :cwd => "/home/#{node.props.guest_username}/opencrowbar/core/"
    end
end


# grab the crowbar repo
log ( "Cloning Crowbar repo - takes forever" )
envhash = { "LOGNAME" => "#{node.props.guest_username}", 'HOME' => "/home/#{node.props.guest_username}" }

opencrowbar_dir = ENV['HOME'] + 'opencrowbar'

directory opencrowbar_dir do
  owner node.props.guest_username
  action :create
end

execute "git clone opencrowbar personal" do
	user "#{node[:props][:guest_username]}"
	group "#{node[:props][:guest_username]}"
	cwd opencrowbar_dir
	command "git clone #{node[:props][:github_repo]}"
	creates opencrowbar_dir
	environment envhash
end

execute "git pull opencrowbar master " do
	user "#{node[:props][:guest_username]}"
	group "#{node[:props][:guest_username]}"
	cwd opencrowbar_dir
	command "git pull upstream"
	creates opencrowbar_dir
	environment envhash
end


