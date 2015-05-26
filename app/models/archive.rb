class Archive
  include Mongoid::Document

  field :table
  field :start_time
  field :finish_time
  field :filename
  field :records

end