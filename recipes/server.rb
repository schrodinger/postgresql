# frozen_string_literal: true
#
# Cookbook:: postgresql
# Recipe:: server
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

Chef::Log.warn 'This cookbook is being re-written to use resources, not recipes and will only be Chef 13.8+ compatible. Please version pin to 6.1.1 to prevent the breaking changes from taking effect. See https://github.com/sous-chefs/postgresql/issues/512 for details'

::Chef::Recipe.send(:include, OpenSSLCookbook::RandomPassword)

include_recipe 'postgresql::client'

# randomly generate postgres password
node.normal_unless['postgresql']['password']['postgres'] = random_password

# Include the right "family" recipe for installing the server
# since they do things slightly differently.
case node['platform_family']
when "rhel", "fedora"
  node.default['postgresql']['dir'] = "/var/lib/pgsql/#{node['postgresql']['version']}/data"
  node.default['postgresql']['config']['data_directory'] = "/var/lib/pgsql/#{node['postgresql']['version']}/data"
  include_recipe "postgresql::server_redhat"
when "debian"
  node.default['postgresql']['config']['data_directory'] = "/var/lib/postgresql/#{node['postgresql']['version']}/main"
  include_recipe "postgresql::server_debian"
when 'suse'
  node.default['postgresql']['config']['data_directory'] = node['postgresql']['dir']
  include_recipe "postgresql::server_redhat"
end

# Versions prior to 9.2 do not have a config file option to set the SSL
# key and cert path, and instead expect them to be in a specific location.

link ::File.join(node['postgresql']['config']['data_directory'], 'server.crt') do
  to node['postgresql']['config']['ssl_cert_file']
  only_if { node['postgresql']['version'].to_f < 9.2 && node['postgresql']['config'].attribute?('ssl_cert_file') }
end

link ::File.join(node['postgresql']['config']['data_directory'], 'server.key') do
  to node['postgresql']['config']['ssl_key_file']
  only_if { node['postgresql']['version'].to_f < 9.2 && node['postgresql']['config'].attribute?('ssl_key_file') }
end

service "postgresql" do
  if node['postgresql']['server']['init_package'] == 'upstart' && node['platform_family'] == 'debian'
    provider Chef::Provider::Service::Upstart
  end
  service_name node['postgresql']['server']['service_name']
  supports :restart => true, :status => true, :reload => true
  action node['postgresql']['service_action']
end

# NOTE: Consider two facts before modifying "assign-postgres-password":
# (1) Passing the "ALTER ROLE ..." through the psql command only works
#     if passwordless authorization was configured for local connections.
#     For example, if pg_hba.conf has a "local all postgres ident" rule.
# (2) It is probably fruitless to optimize this with a not_if to avoid
#     setting the same password. This chef recipe doesn't have access to
#     the plain text password, and testing the encrypted (md5 digest)
#     version is not straight-forward.
# NOTE 2: The random password being generated is not actually a hash.
# It is simply a random string, and is used as is for the password.
bash "assign-postgres-password" do
  user 'postgres'
  code <<-EOH
  echo "ALTER ROLE postgres ENCRYPTED PASSWORD \'#{node['postgresql']['password']['postgres']}\';" | psql -p #{node['postgresql']['config']['port']}
  EOH
  action node['postgresql']['password_action']
  not_if "ls #{node['postgresql']['config']['data_directory']}/recovery.conf"
  only_if { node['postgresql']['assign_postgres_password'] }
end
