
#Chef::log "Putting sledgehammer image in place, so we don\'t have to build it laterz."

directory "#{node.props.crowbar_build_cache}" do
  action :create
  owner "#{node.props.guest_username}"
end


bash "cp init.rd into .crowbar-build-cache" do
  command "cp #{node.props.crowbar_iso_library} #{node.props.crowbar_build_cache}/tftpboot/"
  not_if "file #{node.props.crowbar_build_cache}/tftpboot/initrd0.img"
end

