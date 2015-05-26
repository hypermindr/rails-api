class Client
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Slug
  require 'net/http'

  field :name, type: String
  slug :name
  field :status, type: String
  field :apikey, type: String
  field :domain_name, type: String
  field :root_url, type: String
  field :crawl_settings, type: String
  field :feed_url, type: String

  validates_presence_of :name, :domain_name, :status, :apikey
  before_validation :set_apikey

  has_many :activities
  has_many :users
  has_many :products

  def set_apikey
    self.apikey ||= OpenSSL::Digest::SHA256.new("#{self.name}:#{DateTime.now.to_s}")
    self.apikey
  end

  def get_feed url, limit=10
    return nil if limit==0
    response = Net::HTTP.get_response(URI(url))
    return nil unless /application\/json/.match(response['content-type'])

    case response
    when Net::HTTPSuccess then
      response.body
    when Net::HTTPRedirection then
      location = response['location']
      get_feed(location, limit - 1)
    else
      nil
    end
  end

  def parse_feed json_string
    JSON.parse json_string
  end

  def last_product
    Product.all.max(:external_id) || 0
  end

  def get_feed_url
    return nil unless feed_url
    url = feed_url.clone
    url['{product_id}'] = last_product.to_s
    url
  end

end
