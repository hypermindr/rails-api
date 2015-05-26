class Activity
  include Mongoid::Document
  include Mongoid::Timestamps::Created
  include Mongoid::Pagination

  # include Elasticsearch::Model
  # after_save    { IndexWorker.perform_async(:index,  self.id.to_s, self.class.name) }
  # after_destroy { IndexWorker.perform_async(:delete, self.id.to_s, self.class.name) }

  belongs_to :user
  belongs_to :product

  field :activity, type: String
  field :resource, type: Hash
  field :external_user_id, type: String
  field :external_product_id, type: String
  field :session_id, type: String
  field :ip, type: String
  field :status, type: Integer, default: 0
  field :language, type: String
  field :algorithm, type: String
  field :recommendation_enabled, type: Integer
  field :recommendation_rolledout, type: Integer
  field :ab_group, type: String
  field :anonymous, type: Boolean

  index({ created_at: -1 })
  index({ external_user_id: 1 })
  index({ external_user_id: 1, activity: 1, created_at: -1 })
  index({ 'resource.tag' => 1 })

  validates_presence_of :activity, :ip, :external_user_id
  validates_presence_of :external_product_id, :if => :involves_product?

  def where(expression)
    begin
      super.where(expression)
    rescue Exception => e
      puts e.message
      puts e.backtrace.inspect
      puts expression
    end
  end

  def process

    if Settings[:activity][:process_create_user]
      # if user not present and external_user_id is, then register
      user = Rails.cache.fetch("user.#{external_user_id}",{expires_in: 1.minute}) do
        User.register_user_if_needed external_user_id, ip, anonymous
      end

      unless user
        puts 'User not found'
        return false
      end
      self.user = user

      if self.ip != user.ip || user.ipdata.blank?
        user.ip = self.ip
        user.ipdata = user.get_ip_location
      end

      self.algorithm = user.algorithm
      self.ab_group = user.ab_group

      if Settings[:activity][:process_rollout] # goodnews specific - todo: remove
        if user.rollout
          self.recommendation_rolledout = user.rollout < Time.utc(2014,9,19) ? 1 : 2
        else
          self.recommendation_rolledout=0
        end
      end

      if Settings[:activity][:process_user_language]
        if self.activity=='browse' and self.resource and self.resource['language']
          user.language = self.resource['language'] unless user.language == self.resource['language']
        end
      end

      if Settings[:activity][:process_recommendation_enabled]
        if Settings[:activity][:process_recommendation_enabled_activities].include?(self.activity)
          user.recommendation_enabled = self.recommendation_enabled unless user.recommendation_enabled == self.recommendation_enabled
        end
      end
    end

    if Settings[:activity][:process_create_product] and self.product.blank? and self.external_product_id

      product = Product.where(external_id: self.external_product_id).first
      if product.blank? and self.resource

        product = Product.new
        product.external_id = self.external_product_id
        product.url = self.resource['uri']                    if self.resource.include?('uri')
        product.title = self.resource['title']                if self.resource.include?('title')
        product.short_content = self.resource['description']  if self.resource.include?('description')
        product.source = self.resource['source']              if self.resource.include?('source')
        product.category = self.resource['category']          if self.resource.include?('category')
        product.image = self.resource['image']                if self.resource.include?('image')
        product.date = self.resource['date']                  if self.resource.include?('date')
        product.icon = self.resource['favicon']               if self.resource.include?('favicon')
        product.language = product.get_language               if Settings[:product][:fetch_content_language]

        if Settings[:product][:fetch_url_content]
          product.full_content = Product.get_content(self.resource['uri']) if self.resource.include?('uri')
        end

        if product.save
          # puts 'Barbante.process_product'
          process_product = Modules::Barbante.process_product product
          unless process_product[:success]
            puts "failed process_product: #{process_product}"
            return false
          end
        else
          puts "Failed to save product #{product.errors.messages.inspect}"
          return false
        end
      end
      self.product = product if product
    end

    self.language = self.product.language if Settings[:activity][:process_product_language] and self.product

    if user && user.changed?
      unless user.save
        puts "Failed to save user #{user.errors.messages.inspect}"
        return false
      end
      Rails.cache.write("user.#{user.external_id}", user,{expires_in: 1.minute})
    end

    if self.changed?
      unless self.save
        puts "Failed to save activity #{self.errors.messages.inspect}"
        return false
      end
    end

    # puts 'Barbante.process_activity'
    # if self.activity=='browse' or self.anonymous
    #   return true
    # else
    #   process_activity = Modules::Barbante.process_activity self.external_user_id, self.external_product_id, self.activity, self.created_at.utc.strftime("%FT%T.%3NZ"), self.anonymous
    #   unless process_activity[:success]
    #     process_activity[:id]=self.id
    #     puts "process_activity: #{process_activity}"
    #     return false
    #   end
    # end

    true

  end

  def self.update_user(source_id, target_id, session_id)

    return true if target_id=='0'

    # 2 possibilities
    # A. target user exists: update all activities and delete source user
    # B. target user does not exist: update user external id and activities

    # get first activity date with that session_id to update impressions
    # get all activities to call barbante.process_activity
    activities=[]
    impressions=[]
    first_activity=nil
    Activity.where(external_user_id: source_id, session_id: session_id).each_with_index do |activity, index|
      first_activity = activity.created_at if index==0
      activities<<activity.id
    end

    if first_activity
      Impression.where(external_user_id: source_id, created_at: {"$gte" => first_activity}).each do |impression|
        impressions<<impression.id
      end
    end

    Activity.where(_id: {"$in" => activities}).update_all(external_user_id: target_id, anonymous: 0)
    Impression.where(_id: {"$in" => impressions}).update_all(external_user_id: target_id, anonymous: 0)

    # call barbante process activity
    if Settings[:activity][:process_after_save]

      if Settings[:tracking][:log_impressions]
        Impression.where(_id: {"$in" => impressions}).each do |impression|
          ImpressionWorker.perform_async(impression.external_user_id, impression.external_product_id, impression.created_at.utc.strftime("%FT%T.%3NZ"))
        end
      end

      Activity.where(_id: {"$in" => activities}, activity: {"$ne" => 'browse'}).each do |activity|
        BarbanteActivityFastlaneWorker.perform_async(activity.external_user_id, activity.external_product_id, activity.activity, activity.created_at.utc.strftime("%FT%T.%3NZ"), activity.anonymous) if Settings[:activity][:process_after_save]
        BarbanteActivitySlowlaneWorker.perform_async(activity.external_user_id, activity.external_product_id, activity.activity, activity.created_at.utc.strftime("%FT%T.%3NZ"), activity.anonymous) if Settings[:activity][:process_after_save]
      end
    end

    return true
  end

  def involves_product?
    return true if Settings[:activity][:process_product_required_activities].include? self.activity
    return false
  end



end
