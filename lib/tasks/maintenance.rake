namespace :cache do
  desc "clear cache"
  task :clear => :environment do
    Rails.cache.clear
  end
end

namespace :api do

	desc "self deploy"
	task :self_deploy => :environment do
		Modules::SelfUpdate.install
	end

	desc "publish cloudwatch metrics"
	task :publish_metrics => :environment do
		Modules::QueueMeter.measure
	end

	desc "update reporting"
	task :update_reporting => :environment do
		Reporting.update_reporting(1.day.ago, 1.day.ago)
  end

  desc "update standard reporting"
  task :update_standard_reporting => :environment do
    Reporting.update_standard_reporting(1.day.ago, 1.day.ago)
		# Reporting.update_abgroup_reporting(1.day.ago, 1.day.ago)
		Reporting.visits_per_user_per_week(Date.today, 'puab')
		Reporting.activity_per_user_per_day(Date.today-1, 'puab')
  end

	desc "process all documents"
	task :process_all => :environment do
		Modules::Barbante.process_product '--all'
	end

  desc "update_product_models"
  task :update_product_models => :environment do
    Modules::Barbante.update_product_models
  end

	desc "consolidate product templates"
	task :consolidate_product_templates => :environment do
		Modules::Barbante.consolidate_product_templates
	end

	desc "install barbante"
	task :install_barbante => :environment do

    begin
      if Modules::Barbante.is_target_version?
        puts "Barbante is up-to-date"
        next
      end
    rescue
      puts "Could not verify barbante version. Will install."
    end

    installer = Modules::Barbante.download_installer

    unless File.exists?(installer)
      puts "Barbante installer was not found at #{installer}"
      next
    end

    # run the installer
    system "sudo python3.4 -m easy_install #{installer}"
    system "sudo supervisorctl restart reel:BarbanteReelServer"
		system "sudo supervisorctl restart reel_async:BarbanteReelServerAsync"

	end

	desc "check barbante cluster version"
	task :check_barbante_cluster, [:version] => :environment do |t, args|
		puts "Environment: #{Rails.env}"
		puts "Version: #{args[:version]}"
		#raise "One or more members of the barbante cluster does not have the correct version installed" unless Modules::Barbante.check_cluster_version(args[:version])
	end

	desc "download_installer"
	task :download_barbante => :environment do
		puts Modules::Barbante.download_installer
	end

	desc "archive activities and impressions"
	task :archive => :environment do
		Modules::Archiver.new(:activities, Date.today-1).archive
		Modules::Archiver.new(:impressions, Date.today-1).archive
	end
end


