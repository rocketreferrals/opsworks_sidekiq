# Adapted from unicorn::rails: https://github.com/aws/opsworks-cookbooks/blob/master/unicorn/recipes/rails.rb

include_recipe "opsworks_sidekiq::service"

# setup sidekiq service per app
node[:deploy].each do |application, deploy|

  if deploy[:application_type] != 'rails'
    Chef::Log.debug("Skipping opsworks_sidekiq::setup application #{application} as it is not a Rails app")
    next
  end

  opsworks_deploy_user do
    deploy_data deploy
  end

  opsworks_deploy_dir do
    user deploy[:user]
    group deploy[:group]
    path deploy[:deploy_to]
  end

  # Allow deploy user to restart workers
  template "/etc/sudoers.d/#{deploy[:user]}" do
    mode 0440
    source "sudoer.erb"
    variables :user => deploy[:user]
  end

  if node[:sidekiq][application]

    workers = node[:sidekiq][application].to_hash.reject {|k,v| k.to_s =~ /restart_command|syslog/ }
    config_directory = "#{deploy[:deploy_to]}/shared/config"

    workers.each do |worker, options|

      # Convert attribute classes to plain old ruby objects
      config = options[:config] ? options[:config].to_hash : {}

      (options[:process_count] || 1).times do |n|
        template "#{config_directory}/sidekiq_#{worker}#{n+1}.yml" do
          mode 0644
          source "sidekiq_config.erb"
          variables({:config => config})
        end
      end
    end

    template "#{node[:monit][:conf_dir]}/sidekiq_#{application}.monitrc" do
      mode 0644
      source "sidekiq_monitrc.erb"
      variables({
        :deploy => deploy,
        :application => application,
        :workers => workers,
        :syslog => node[:sidekiq][application][:syslog]
      })
      notifies :reload, resources(:service => "monit"), :immediately
    end

  end
end
