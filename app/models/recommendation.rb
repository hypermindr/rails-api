class Recommendation
    include Mongoid::Document
    include Mongoid::Timestamps::Created

    field :external_user_id, type: String
    field :external_product_id, type: String
    field :position, type: Integer
    validates_presence_of :external_user_id, :external_product_id
    index({ external_user_id: 1, external_product_id: 1 })
    index({ external_user_id: 1, created_at: 1 })

end