include_recipe 'dpkg_autostart'
require "base64"

%w{hadoop-hdfs-namenode hadoop-hdfs-zkfc}.each do |pkg|
  dpkg_autostart pkg do
    allow false
  end
  package pkg do
    action :upgrade
  end
end

node[:bcpc][:hadoop][:mounts].each do |i|
  directory "/disk/#{i}/dfs/nn" do
    owner "hdfs"
    group "hdfs"
    mode 0755
    action :create
    recursive true
  end

  directory "/disk/#{i}/dfs/namedir" do
    owner "hdfs"
    group "hdfs"
    mode 0700
    action :create
    recursive true
  end

  execute "fixup nn owner" do
    command "chown -Rf hdfs:hdfs /disk/#{i}/dfs/"
    only_if { Etc.getpwuid(File.stat("/disk/#{i}/dfs/").uid).name != "hdfs" }
  end
end

if get_config("namenode_txn_fmt") then
  file "/tmp/nn_fmt.tgz" do
    user "hdfs"
    group "hdfs"
    user 0644
    content Base64.decode64(get_config("namenode_txn_fmt"))
  end
end

if false
node[:bcpc][:hadoop][:mounts].each do |d|

  directory "/disk/#{d}/dfs/" do
    owner "hdfs"
    group "hdfs"
    mode 0755
    action :create
    recursive true
  end

  bash "unpack nn fmt image" do
    user "hdfs"
    get_config("namenode_txn_fmt")
    code ["pushd /disk/#{d}/dfs/",
          "tar xzvf /tmp/nn_fmt.tgz",
          "popd"].join("\n")
    only_if { not get_config("namenode_txn_fmt").nil? and not Dir.entries("/disk/#{d}/dfs/nn").include?("current") }
  end
end
end

if @node['bcpc']['hadoop']['hdfs']['HA'] == true then
  bash "hdfs namenode -bootstrapStandby -force -nonInteractive" do
    code "hdfs namenode -bootstrapStandby -force -nonInteractive"
    user "hdfs"
    cwd  "/var/lib/hadoop-hdfs"
    action :run
    not_if { node[:bcpc][:hadoop][:mounts].all? { |d| Dir.entries("/disk/#{d}/dfs/nn/").include?("current") } }
  end  

  service "hadoop-hdfs-zkfc" do
    action [:enable, :start]
    subscribes :restart, "template[/etc/hadoop/conf/hdfs-site.xml]", :delayed
    subscribes :restart, "template[/etc/hadoop/conf/hdfs-policy.xml]", :delayed
  end

  service "hadoop-hdfs-namenode" do
    action [:enable, :start]
    subscribes :restart, "template[/etc/hadoop/conf/hdfs-site.xml]", :delayed
    subscribes :restart, "template[/etc/hadoop/conf/hdfs-policy.xml]", :delayed
  end
else
  Chef::Log.info "Not running standby namenode services yet -- HA disabled!"
  service "hadoop-hdfs-zkfc" do
    action [:disable, :stop]
  end
  service "hadoop-hdfs-namenode" do
    action [:disable, :stop]
  end
end
