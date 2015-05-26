class ProductWorker
  include Sidekiq::Worker
  sidekiq_options :queue => :product, :retry => 1, :failures => :exhausted

  def perform(id)
    product = Product.find(id)
    result = product.process

    result[:message] ||= "Unkown error: #{result.to_json}"
    raise result[:message] unless result[:success]
  end
  
end