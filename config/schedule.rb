# Learn more: http://github.com/javan/whenever

set :output, "cron.log"

job_type :bundle_exec, "/code/api/current/ruby_cron_rvm_bundler.sh \"#{@environment}\" \":task\" >> /code/api/current/log/cron.log"

every 1.minute, :roles => :app_primary do
	bundle_exec "rake api:publish_metrics"
end

every 1.hour, :roles => :app_primary do
	bundle_exec "rake api:consolidate_product_templates"
end

every :day, :at => '5:15am', :roles => :app_primary do
	bundle_exec "rake api:archive"
end

every :day, :at => '3:15am', :roles => :app_primary do
	bundle_exec "rake api:update_standard_reporting"
end