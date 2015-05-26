class ActivityWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :activity, :retry => 1, :failures => :exhausted
  
  def perform(id)
    activity = Activity.find(id)
    activity.process
  end
  
end