class ImpressionWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :impression, :retry => 1, :failures => :exhausted

  def perform(external_user_id, external_product_id, impression_date)
    result = Modules::Barbante.process_impression external_user_id, external_product_id, impression_date
    # puts result unless result['success']
    # return result['success']

    result[:message] ||= "Unkown error: #{result.to_json}"
    raise result[:message] unless result[:success]

  end
end