class Impression
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :external_user_id, type: String
  field :external_product_id, type: String
  field :position, type: Integer
  field :anonymous, type: Boolean

  index({external_user_id: 1, created_at: -1})

  validates_presence_of :external_user_id, :external_product_id

end
