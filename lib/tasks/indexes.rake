
namespace :indexes do

  desc 'create and drop application indexes'
  task :update => :environment do
    Modules::Mongo.new(dryrun: false).update_indexes
  end

  desc 'dryrun only: create and drop application indexes'
  task :dryrun => :environment do
    puts '================= Dryrun ====================='
    Modules::Mongo.new(dryrun: true).update_indexes
  end

end