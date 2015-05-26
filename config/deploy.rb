# config valid only for Capistrano 3.1
lock '3.3.4'

set :application, 'api'
set :repo_url, 'git@bitbucket.org:hypermindr/api.git'
set :use_sudo, true
set :bundle_path, -> { shared_path.join('bundle') }
set :keep_releases, 10
set :rvm_ruby_version, '2.1.0'      # Defaults to: 'default'
set :whenever_roles, [:app, :app_primary]

set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets')
set :sidekiq_default_hooks, false

namespace :sidekiq do

  desc "replace sidekiq config file"
  task :reconfigure_workers do
    on roles(:workers) do
      target_file = release_path.join('config', 'sidekiq.yml')
      source_file = release_path.join('config', 'sidekiq.workers.yml')
      execute "rm #{target_file}"
      execute "mv #{source_file} #{target_file}"
    end
  end

  after :reconfigure_workers, :restart

  desc "Upload yml file."
  task :upload_yml do
    on roles(:workers) do
      upload! StringIO.new(File.read("config/sidekiq.workers.yml")), release_path.join('config', 'sidekiq.workers.yml')
      upload! StringIO.new(File.read("config/sidekiq.yml")), release_path.join('config', 'sidekiq.yml')
    end
  end

end

namespace :deploy do

  desc "Transfer settings.yml and ec2.yml"
  task :upload_settings do
    on roles(:all) do
      upload! "config/settings.yml", release_path.join('config', 'settings.yml')
      upload! "config/ec2.yml", release_path.join('config', 'ec2.yml')
    end
  end


  desc 'Restart application'
  task :restart do
    on roles(:web) do
      # Your restart mechanism here, for example:
      execute :touch, release_path.join('tmp/restart.txt')
    end
  end

  desc 'Install/update barbante'
  task :install_barbante do
    on roles(:app) do |host|
      within release_path do
        execute :rake, 'api:install_barbante'
      end
    end
  end

  desc "db:migration fakes"
  task :migrate do
    on roles(:db) do
     p 'No. We will not migrate!'
    end
  end

  # desc 'check barbante cluster version'
  # task :check_barbante_cluster do
  #   on roles(:app_primary) do
  #     within release_path do
  #       version = File.open('.barbante-version', &:readline)
  #       execute :rake, "api:check_barbante_cluster[#{version}]", "RAILS_ENV=#{fetch(:stage)}"
  #     end
  #   end
  # end

  # after 'deploy:starting',:check_barbante_cluster

  #override sidekiq default hooks
  after 'deploy:starting', 'sidekiq:quiet'
  after 'deploy:updated', 'sidekiq:stop'
  after 'deploy:reverted', 'sidekiq:stop'

  before :published, :upload_settings
  after 'deploy:published', :install_barbante

  after :install_barbante, :restart
  after :restart, 'sidekiq:start'

  after :restart, :clear_cache do
    on roles(:app) do
      within release_path do
        execute :rake, 'cache:clear'
      end
    end
  end

  after   :clear_cache, :bundle_app
end

namespace :indexes do

  desc 'create and drop application indexes'
  task :update do
    on roles(:app_primary) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'indexes:update'
        end
      end
    end
  end


  desc 'dryrun only: create and drop application indexes'
  task :dryrun do
    on roles(:app_primary) do
      within release_path do
        with rails_env: fetch(:rails_env) do
          execute :rake, 'indexes:dryrun'
        end
      end
    end
  end

end

namespace :products do
  desc 'Import api products'
  task :import do
    on roles(:app_primary) do
      within release_path do
        execute :rake, 'peixe:update_products'
      end
    end
  end
end

namespace :chef do
  desc 'Run chef-client'
  task :client do
    run %{chef-client}
  end
end
