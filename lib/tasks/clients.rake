namespace :peixe do
  desc "Download latest products"
  task :update_products => :environment do
    Modules::PeixeApiClient.new.update_products
  end
end