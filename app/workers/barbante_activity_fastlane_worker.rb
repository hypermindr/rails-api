class BarbanteActivityFastlaneWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :barbante_activity_fastlane, :retry => 1, :failures => :exhausted

  def perform(external_user_id, external_product_id, activity, created_at, anonymous)
    result = Modules::Barbante.process_activity_fastlane(external_user_id, external_product_id, activity, created_at, anonymous)

    # puts result.inspect

    result[:message] ||= "Unkown error: #{result.to_json}"
    raise result[:message] unless result[:success]

    true
  end
end