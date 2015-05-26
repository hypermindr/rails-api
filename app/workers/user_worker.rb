class UserWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :user, :failures => :exhausted

  def perform(id)
    user = User.find(id)
    user.ipdata = user.get_ip_location
    user.save
  end
  
end