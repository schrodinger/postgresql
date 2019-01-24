include_recipe 'postgresql::config_version'
include_recipe 'apt'

file "remove deprecated Pitti PPA apt repository" do
  action :delete
  path "/etc/apt/sources.list.d/pitti-postgresql-ppa"
end

Chef::Log.warn 'This cookbook is being re-written to use resources, not recipes and will only be Chef 13.8+ compatible. Please version pin to 6.1.1 to prevent the breaking changes from taking effect. See https://github.com/sous-chefs/postgresql/issues/512 for details'

# frozen_string_literal: true
apt_repository 'apt.postgresql.org' do
  uri 'http://apt.postgresql.org/pub/repos/apt'
  distribution "#{node['postgresql']['pgdg']['release_apt_codename']}-pgdg"
  components ['main', node['postgresql']['version']]
  key 'https://www.postgresql.org/media/keys/ACCC4CF8.asc'
  action :add
end
