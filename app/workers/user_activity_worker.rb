class UserActivityWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :user_activity, :retry => 5, :failures => :exhausted

  def perform(source_id, target_id, session_id)
    Activity.update_user source_id, target_id, session_id
  end
  
end