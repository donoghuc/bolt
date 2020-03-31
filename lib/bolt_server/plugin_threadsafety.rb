#! /opt/puppetlabs/bin/puppetserver ruby
# frozen_string_literal: true

require 'fileutils'
require 'puppet'
require 'puppet/configurer'
require 'tempfile'
require 'uri'

puppet_root = Dir.mktmpdir
moduledir = File.join(puppet_root, 'modules')
Dir.mkdir(moduledir)

cli_base = Puppet::Settings::REQUIRED_APP_SETTINGS.flat_map do |setting|
  ["--#{setting}", File.join(puppet_root, setting.to_s.chomp('dir'))]
end

cli_base.concat([
  '--modulepath',
  moduledir,
  '--localcacert',
  '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
  '--hostcert',
  '/etc/puppetlabs/bolt-server/ssl/silly-stitch.delivery.puppetlabs.net.cert.pem',
  '--hostprivkey',
  '/etc/puppetlabs/bolt-server/ssl/silly-stitch.delivery.puppetlabs.net.private_key.pem',
  '--hostcrl',
  '/etc/puppetlabs/puppet/ssl/crl.pem'
  # '--server_list',
  # 'silly-stitch.delivery.puppetlabs.net'
])

Puppet.initialize_settings(cli_base)
Puppet[:server] = 'silly-stitch.delivery.puppetlabs.net'
Puppet::Util::Log.destinations.clear
Puppet::Util::Log.newdestination(:console)
Puppet.settings[:log_level] = 'info'
def sync(env, cache_dir)
  Puppet[:plugindest] = File.join(cache_dir, "#{env}_plugins")
  Puppet[:pluginfactdest] = File.join(cache_dir, "#{env}_pluginfacts")
  remote_env_for_plugins = Puppet::Node::Environment.remote(env)
  downloader = Puppet::Configurer::Downloader.new(
    "plugin",
    Puppet[:plugindest],
    Puppet[:pluginsource],
    Puppet[:pluginsignore],
    remote_env_for_plugins
  )
  downloader.evaluate

  source_permissions = Puppet::Util::Platform.windows? ? :ignore : :use
  plugin_fact_downloader = Puppet::Configurer::Downloader.new(
    "pluginfacts",
    Puppet[:pluginfactdest],
    Puppet[:pluginfactsource],
    Puppet[:pluginsignore],
    remote_env_for_plugins,
    source_permissions
  )
  plugin_fact_downloader.evaluate
end

envs = ['apply', 'production']
if ARGV[0] == 'thread'
  ## Threads dont work
  envs.map {|env| Thread.new{sync(env, '/tmp')}}.each {|thread| thread.join}
elsif ARGV[0] == 'fork'
  ## Fork works
  envs.each do |env|
    fork do
      sync(env, '/tmp')
    end
  end
  envs.each {|_| Process.wait}
else
  envs.each {|env| sync(env, '/tmp')}
end
