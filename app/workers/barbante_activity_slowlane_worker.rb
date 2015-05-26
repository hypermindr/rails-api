class BarbanteActivitySlowlaneWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :barbante_activity_slowlane, :retry => 1, :failures => :exhausted

  def perform(external_user_id, external_product_id, activity, created_at, anonymous)
    result = Modules::Barbante.process_activity_slowlane(external_user_id, external_product_id, activity, created_at, anonymous)

    # unless result['success']
    #   output = {external_user_id: external_user_id, external_product_id: external_product_id, activity: activity, created_at: created_at, anonymous: anonymous, result: result}
    #   puts output
    #   return false
    # end

    result[:message] ||= "Unkown error: #{result.to_json}"
    raise result[:message] unless result[:success]

    true
  end
end