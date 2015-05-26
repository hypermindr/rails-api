class User
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Pagination
  
  # include Elasticsearch::Model
  # after_save    { IndexWorker.perform_async(:index,  self.id.to_s, self.class.name) }
  # after_destroy { IndexWorker.perform_async(:delete, self.id.to_s, self.class.name) }

  field :name, type: String
  field :email, type: String
  field :email_md5, type: String
  
  field :external_id, type: String
  field :session_id, type: String
  field :social_id, type: Hash
  field :gender, type: String
  field :location, type: String
  field :locale, type: String
  field :timezone, type: Integer
  field :friends, type: Hash
  field :ip, type: String
  field :ipdata, type: Hash
  field :algorithm, type: String
  field :recommendation_enabled, type: Integer
  field :rollout, type: Date
  field :language, type: String
  field :ab_group, type: String
  field :anonymous, type: Boolean

  has_many :activities
  has_many :recommendations

  before_create :ab_group

  index({ external_id: 1 }, {unique: true, drop_dups: true})

  validates_presence_of :external_id

  def self.algorithm_options_dev
    ["HR2", "1a", "2a", "3a", "0"]
  end

  def self.algorithm_options
    ["HR2"]
  end

  def self.pick_algorithm
    options = User.algorithm_options
    options[rand(options.size)]
  end

  def self.ab_groups
    Settings[:user][:ab_groups]
  end

  def ab_group
    self[:ab_group] ||= User.ab_groups[rand(User.ab_groups.size)] if Settings[:user][:ab_testing]
  end

  def set_algorithm
    unless User.algorithm_options.include?(self.algorithm)
      self.algorithm = User.pick_algorithm
      self.save
    end
  end

  def get_ip_location
    return nil if ip.blank? or ip.nil?
    # url="http://ip-api.com/json/#{ip}"
    url = "http://www.telize.com/geoip/#{ip}"
    begin
      data = Rails.cache.fetch("ip.#{ip}",{expires_in: 30.days}) do
        fetch url
      end
      return JSON.parse(data) if data
      nil
    rescue
      nil
    end
  end

  def fetch(uri_str, limit = 10)
    return nil if limit==0
    response = Net::HTTP.get_response(URI(uri_str))

    case response
    when Net::HTTPSuccess then
      response.body
    when Net::HTTPRedirection then
      location = response['location']
      # warn "redirected to #{location}"
      fetch(location, limit - 1)
    else
      nil
    end
  end

  def self.find_by_email(email)
    md5 = Digest::MD5.new
    md5 << email
    User.any_of({email_md5: md5.hexdigest}, {external_id: email})
  end

  def get_recommended_products(count: 20, algorithm: nil, ids_only: false, filter: '', timeout: 5)

    # return [] if Settings[:user][:ab_testing] and ab_group=='A'

    if algorithm=='sample'
      return Product.last
    else
      result = self.recommend(count, algorithm, filter, timeout)
    end

    return {success: false, message: 'unknown error retrieving recommendations'} unless result.is_a?(Hash)

    # convert hash keys from string to symbol
    # result = Hash[result.map{ |k, v| [k.to_sym, v] }]

    unless result[:success] and result[:products]
      return result
    end

    external_ids = result[:products].map{ |product| product[1] }

    if ids_only
      return {success: true, products: external_ids}
    else

      product_list = {}
      result[:products].each_with_index do |product, index|
        product_list[product[1].to_s]={score: product[0], rank: index}
      end

      _products = Product.where(:external_id.in => external_ids)
      products = _products.map{|product| {
        _id: product.id.to_s,
        id: product.external_id,
        score: product_list[product.external_id][:score],
        rank: product_list[product.external_id][:rank],

        title: product.map_field('title'),
        short_content: product.map_field('short_content'),
        source: product.map_field('source'),
        date: product.map_field('date').to_i,
        url: product.map_field('url'),
        image: product.map_field('image')
        }
      }

      return {success: true, products: products.sort_by { |hsh| hsh[:rank] } }
    end
  end

  def recommend(count, algorithm=nil, filter='', timeout=5)
    self.set_algorithm
    algorithm ||= self.algorithm
    Modules::Barbante.recommend self.external_id, count, algorithm, filter, timeout
  end

  def get_templates
    templates = Modules::Barbante.get_user_templates self.external_id
    template_list =[]
    templates[:template_users].each{|t| template_list<<t[1]} if templates[:template_users] # barbante >= 1.7.8
    # templates['template_users'].each{|t| template_list<<t[0]} if templates['template_users'] # barbante <= 1.7.6
    User.where(:external_id.in => template_list)
  end

  def self.register_user_if_needed(external_user_id, ip, anonymous, tries=0)

    user = User.find_by(external_id: external_user_id) rescue nil

    unless user
      begin
        user = User.create(
            external_id: external_user_id,
            algorithm: User.pick_algorithm,
            anonymous: anonymous,
            ip: ip
        )
      rescue
        tries+=1
        puts "retrying register_user: #{tries} - external id: #{external_user_id}"
        if tries<=5
          user = User.register_user_if_needed external_user_id, ip, anonymous, tries
        else
          puts "gave up register_user after #{tries} tries"
          user = nil
        end
      end
    end

    user
  end
end
