# add some remotes, if they want it

node.props.attribute?('github_extra_remotes') &&
node.props[:github_extra_remotes].each do | remote_name, remote_url |
  log "Adding extra git remote repositories"
  execute "set remote #{remote_name} with url #{remote_url}" do
    user node.props.guest_username
    cwd "/home/#{node.props.guest_username}/core/"
    command "git remote add #{remote_name} #{remote_url}; git fetch #{remote_name}"
    action :run
    not_if "git remote -v #{remote_name}", 
      :user => node.props.guest_username, 
      :cwd => "/home/#{node.props.guest_username}/core/"
    end
end

