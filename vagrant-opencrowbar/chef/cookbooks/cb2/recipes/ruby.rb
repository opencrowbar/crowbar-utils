
# ubuntu needs help with ruby 1.9.x and ruby 2.0
case node[:platform]
when "ubuntu"
  # ruby 1.9
  %w{ruby1.9.1 rubygems1.9.1 ruby1.9.1-dev}.each do |pkg|
    package "#{pkg}"
  end

  # add the ruby 2.0 experimental PPA; grab key from keyserver
  apt_repository "ruby-ng-experimental" do
     uri "http://ppa.launchpad.net/brightbox/ruby-ng-experimental/ubuntu"
     distribution node['lsb']['codename']
     components ["main"]
  end

  # another way to add ruby 2.0 - from source
    # ruby 2.0
    #%w{build-essential zlib1g-dev libssl-dev libreadline6-dev libyaml-dev}.each do |p|
    #  package "#{p}"
    #end
    # cd /tmp
    # wget http://cache.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p353.tar.gz
    # tar -xvzf ruby-2.0.0-p353.tar.gz
    # cd ruby-2.0.0-p353/
    # ./configure --prefix=/usr/local
    # make
    # sudo make install

    execute "/usr/sbin/update-alternatives --set ruby --which one" do
      command "/usr/sbin/update-alternatives --set ruby /usr/bin/ruby1.9.1"
    end

    execute "/usr/sbin/update-alternatives --set gem --which one" do
      command "/usr/sbin/update-alternatives --set gem /usr/bin/gem1.9.1"
    end

when "suse"
	%w{postgresql-devel ruby rubygems ruby-devel}.each do |p|
		package "#{p}" do
			action :install
		end
	end
when "centos"
  #flush the cache the first time  
#  yum_package "ruby193" do
#    action :install
#    flush_cache [:before]
#  end
  
  #now get the ruby stuff we need
#  %w{ruby193 ruby193-ruby-devel ruby193-rubygems}.each do |p|
#    package "#{p}" do
#      action :install
#    end
#  end
end
