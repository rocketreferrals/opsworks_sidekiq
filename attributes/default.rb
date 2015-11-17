include_attribute 'deploy'

default[:sidekiq] = {}

case node[:platform_family]
when 'rhel', 'fedora', 'suse'
  default[:monit][:includes_dir] = '/etc/monit.d'
else
  default[:monit][:includes_dir] = '/etc/monit/conf.d'
end

node[:deploy].each do |application, deploy|
  default[:sidekiq][application.intern] = {}
  default[:sidekiq][application.intern][:restart_command] = "sudo monit restart -g sidekiq_#{application}_group"
  default[:sidekiq][application.intern][:path_to_script] = node[:sidekiq][:path_to_script] || 'bin'
  default[:sidekiq][application.intern][:syslog] = false
end
