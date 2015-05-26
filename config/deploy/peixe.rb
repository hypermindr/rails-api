require 'hipchat/capistrano'

# capistrano-ec2tag
set :ec2_config, 'config/ec2.yml'
set :ec2_filter_by_status_ok?, true
set :ec2_contact_point, :private_ip

set :deploy_to, '/code/api'
set :rvm_custom_path, '/code/api/.rvm'
set :branch, "master"
set :rails_env, 'peixe'

set :sidekiq_env, 'peixe'
set :sidekiq_log, release_path.join('log', 'sidekiq.log')
set :sidekiq_pid, release_path.join('tmp', 'sidekiq.pid')

set :whenever_environment, 'peixe'

set :hipchat_token, "b44295efe6bc4aaace429c09a6a8e2"
set :hipchat_room_name, "635609"
set :hipchat_announce, true # notify users
set :hipchat_color, 'green' #finished deployment message color
set :hipchat_failed_color, 'red' #cancelled deployment message color



[:app, :web, :workers, :app_primary, :db].each do |role|
  ec2_role role,
           user: 'ubuntu',
           ssh_options: {
               user: 'ubuntu', # overrides user setting above
               keys: %w(~/.ssh/chef-ec2.pem),
               forward_agent: true,
               auth_methods: %w(publickey password)
           }
end
