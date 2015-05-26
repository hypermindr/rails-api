require 'rake'

module Modules
  class SelfUpdate

    S3_Bucket = 'hypermindrapi'
    CURRENT_PATH = '/code/api/current'
    RELEASE_PATH = '/code/api/releases'
    SHARED_PATH = '/code/api/shared'
    SIDEKIQ_PID = '/code/api/current/tmp/sidekiq.pid'
    BUNDLE_EXEC = '/code/api/.rvm/bin/rvm 2.1.0 do bundle exec '

    def self.install
      puts Time.now

      puts "download repo"
      download_repo

      puts "extract archive"
      extract_archive

      puts "stop sidekiq"
      stop_sidekiq

      puts "change symlink"
      current_symlink

      puts "bundle install"
      bundle_install

      puts "install barbante"
      install_barbante

      puts "start sidekiq"
      start_sidekiq

    end

    def self.download_repo
      AWS.config(access_key_id: Settings[:aws][:access_key_id], secret_access_key: Settings[:aws][:secret_access_key], region: Settings[:aws][:region])
      s3 = AWS::S3.new
      bucket = s3.buckets[S3_Bucket]
      @@filename = "api.#{Rails.env}.tar.gz"
      @@filepath = "/tmp/#{@@filename}"

      raise "Remote file #{@@filename} does not exist" unless bucket.objects[@@filename].exists?

      File.open(@@filepath, 'wb') do |file|
        bucket.objects[@@filename].read do |chunk|
          file.write(chunk)
        end
      end

      return @@filepath
    end


    def self.download_settings_file
      AWS.config(access_key_id: Settings[:aws][:access_key_id], secret_access_key: Settings[:aws][:secret_access_key], region: Settings[:aws][:region])
      s3 = AWS::S3.new
      bucket = s3.buckets[S3_Bucket]
      filename = "settings.yml"
      filepath = "#{CURRENT_PATH}/config/#{filename}"

      raise "Remote file #{filename} does not exist" unless bucket.objects[filename].exists?

      File.open(filepath, 'wb') do |file|
        bucket.objects[filename].read do |chunk|
          file.write(chunk)
        end
      end

      return filepath
    end

    def self.extract_archive
      raise 'repository not found' unless File.exists?(@@filepath)
      @@target_dir = "#{RELEASE_PATH}/#{Time.now.strftime('%Y%m%d%H%M%S')}"
      Dir.mkdir @@target_dir
      system "tar -xf #{@@filepath} -C #{@@target_dir}"
      Dir.mkdir "#{@@target_dir}/tmp"
    end

    def self.current_symlink
      FileUtils.safe_unlink CURRENT_PATH
      File.symlink @@target_dir, CURRENT_PATH
      File.symlink "#{SHARED_PATH}/log", "#{CURRENT_PATH}/log"

      self.download_settings_file
    end

    def self.stop_sidekiq
      sidekiqctl = "#{BUNDLE_EXEC} sidekiqctl"
      cmd = "if [ -d #{CURRENT_PATH} ] && [ -f #{SIDEKIQ_PID} ] && kill -0 `cat #{SIDEKIQ_PID}`> /dev/null 2>&1; then cd #{CURRENT_PATH} && #{sidekiqctl} stop #{SIDEKIQ_PID} ; else echo 'Sidekiq is not running' && if [ -f #{SIDEKIQ_PID} ] ; then rm #{SIDEKIQ_PID} ; fi ; fi"

      system cmd
    end

    def self.start_sidekiq
      cmd = "cd #{CURRENT_PATH} && #{BUNDLE_EXEC} sidekiq --index 0 --pidfile #{SIDEKIQ_PID} --environment #{Rails.env} --logfile #{SHARED_PATH}/log/sidekiq.log --daemon"
      system cmd
    end

    def self.install_barbante
      system "cd #{@@target_dir} && #{BUNDLE_EXEC} rake api:install_barbante"
    end

    def self.bundle_install
      cmd = "cd #{@@target_dir} && /code/api/.rvm/bin/rvm 2.1.0 do bundle install --binstubs /code/api/shared/bin --path /code/api/shared/bundle --without development test --deployment --quiet"
      system cmd
    end

  end
end