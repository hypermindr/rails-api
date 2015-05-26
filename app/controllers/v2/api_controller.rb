class V2::ApiController < ApplicationController

  before_filter :validate_client, except: [:core, :log_impression]

  before_filter :logging_start, only: [:product, :track_activity, :user, :recommend, :update_activity_user, :delete_old_products]
  after_filter :logging_end, only: [:product, :track_activity, :user, :recommend, :update_activity_user, :delete_old_products]

  logger = Logger.new STDOUT
  def core
    # used to serve core.js file
    content = Rails.cache.fetch("#{request.protocol}v2.core.js", expires_in: 15.minutes) do
      Uglifier.new.compile(render_to_string)
    end
    render js: content
  end

  def product

    unless validate_required_parameters ['status']
      return false
    end

    product = Product.find_by(external_id: params[:id]) rescue nil
    product = Product.new unless product

    if params[:resource]
      begin
        resource = JSON.parse(params[:resource])
      rescue => error
        render_response({success: false, message: 'resource contains invalid json', errors: error.message}) and return
      end
      product.resource = resource
    end

    product.external_id = params[:id]
    product.status = params[:status]

    unless product.changed?
      render_response({success: true, resource_id: product.external_id}) and return
    end

    begin
      if product.save
        ProductWorker.perform_async(product.id.to_s) if Settings[:product][:process_after_save]
        render_response({success: true, resource_id: product.external_id}) and return
      else
        render_response({success: false, message: product.errors.messages}) and return
      end
    rescue => error
      render_response({success: false, message: 'could not save product', errors: error.message}) and return
    end
  end

  def track_activity

    unless validate_required_parameters ['user_id','activity']
      return false
    end

    if params[:user_id]=='0'
      render_response({success: false
                      }) and return
    end

    if params[:resource] and params[:resource][:id]
      cache_name = "#{params[:activity]}-#{params[:user_id]}-#{params[:resource][:id]}"
      @cached = Rails.cache.fetch(cache_name)
      if @cached
        render_response({success: true}) and return
      end
    end

    user = Rails.cache.fetch("user.#{params[:user_id]}",{expires_in: 10.minutes}) do
      User.register_user_if_needed(params[:user_id], request.remote_ip, params[:anonymous])
    end

    activity = Activity.new(
        activity: params[:activity],
        user: user,
        external_user_id: params[:user_id],
        resource: params[:resource],
        ip: request.remote_ip,
        session_id: params[:session_id],
        recommendation_enabled: params[:recommendation_enabled],
        anonymous: params[:anonymous]
    )

    activity.external_product_id = params[:resource][:id] if params[:resource] && params[:resource][:id]
    activity.ab_group = user.ab_group if user

    unless activity.with(write: { w: 0 }).save
      render_response({success: false, message: 'could not save activity', errors: activity.errors}) and return
    end

    Rails.cache.write(cache_name, true, expires_in: 1.minute) if cache_name

    BarbanteActivityFastlaneWorker.perform_async(activity.external_user_id, activity.external_product_id, activity.activity, activity.created_at.utc.strftime("%FT%T.%3NZ"), activity.anonymous) unless activity.activity=='browse'

    if activity.activity=='browse' or activity.anonymous
      # puts 'skip barbante'
    else
      BarbanteActivitySlowlaneWorker.perform_async(activity.external_user_id, activity.external_product_id, activity.activity, activity.created_at.utc.strftime("%FT%T.%3NZ"), activity.anonymous)
    end

    render_response({success: true}) and return
  end

  def user

    user = User.find_by(external_id: params[:id]) rescue nil
    user = User.new unless user
    user.external_id = params[:id]
    user.email = params[:email] if params[:email]
    user.email_md5 = params[:email_md5] if params[:email_md5]
    user.gender = params[:gender] if params[:gender]
    user.ip = params[:ip] if params[:ip]
    user.algorithm = User.pick_algorithm unless user.algorithm

    unless user.changed?
      render_response({success: true, resource_id: user.external_id}) and return
    end

    if user.save
      render_response({success: true, resource_id: user.external_id}) and return
    else
      render_response({success: false, message:'could not save user', errors: user.errors}) and return
    end

  end

  def recommend

    unless validate_required_parameters ['user_id']
      return false
    end

    user = Rails.cache.fetch("user.model.#{params[:user_id]}",{expires_in: 10.minutes}) do
      User.where(external_id: params[:user_id]).first
    end

    unless user
      render_response({success: false, message:'user not found'}) and return
    end
    user.set_algorithm # set algorithm if for any reason it is not set

    algorithm = params[:algorithm] || user.algorithm
    count = params[:count] || 20

    recommendation_cache_name = "rec.#{params[:user_id]}.#{algorithm}.#{count}.#{params[:filter]}"
    Rails.cache.delete(recommendation_cache_name) if params[:nocache]

    recommendations = Rails.cache.fetch(recommendation_cache_name,{expires_in: 30.seconds}) do
      user.get_recommended_products(count: count, algorithm: algorithm, ids_only: true, filter: params[:filter])
    end

    if recommendations[:products]
      render_response({success: true, resources: recommendations[:products]}) and return
    else
      render_response({success: false, resources: [], message: recommendations[:message]}) and return
    end

  end

  def log_recommendation
    unless validate_required_parameters ['user_id','product_id']
      return false
    end

    render_response({success: false, message: 'This endpoint is deprecated.'}) and return

  end

  def log_impression
    unless validate_required_parameters ['user_id', 'product_id']
      return false
    end

    render_response({success: false, message: 'This endpoint is deprecated.'}) and return
  end

  def update_activity_user
    unless validate_required_parameters ['source_id','target_id','session_id']
      return false
    end

    UserActivityWorker.perform_async params[:source_id], params[:target_id], params[:session_id]

    render_response({success: true}) and return
  end

  def delete_old_products

    unless validate_required_parameters ['updated_before_date']
      return false
    end

    unless params[:updated_before_date] =~ /\A\d+\z/
      render_response({success: false, message:'invalid date - must be unix timestamp'}) and return
    end

    updated_at = Time.at(params[:updated_before_date].to_i)
    if updated_at > Time.now
      render_response({success: false, message:'invalid date - must be in the past'}) and return
    end

    delete_time = Time.now

    Product.where(updated_at: {'$lt' => updated_at}, status: 'active').each do |product|
      Modules::Barbante.delete_product product.external_id, delete_time
    end

    Product.where(updated_at: {'$lt' => updated_at}, status: 'active').update_all(deleted_on: delete_time, status: 'inactive')

    render_response({success: true}) and return

  end

  private

  def validate_client
    unless validate_required_parameters ['client_id','apikey']
      return false
    end

    # Rails.cache.clear
    @client = Rails.cache.fetch("client-#{params[:client_id]}", expires_in: 1.hour) do
      Client.find(params[:client_id])
    end

    unless @client
      render_response({success: false, message:'invalid client'})
      return false
    end

    if @client.apikey != params[:apikey]
      render_response({success: false, message:'invalid api key'})
      return false
    end

    true
  end

  def render_response(result)

    if params[:callback]
      render json: {result: result}, callback: params[:callback]
    else
      render json: {:result => result}
    end

  end

  def validate_required_parameters(list)
    list.each do |parameter|
      if params[parameter].nil? || params[parameter].blank?
        render_response({success: false, message: "required parameter `#{parameter}` not informed" , errors: nil}) and return false
      end
    end

    true
  end

  def logging_start
    #cleaning before log starts. Good practice according to community
    Modules::LogTracer.clean_up
    Modules::LogTracer.start_trace self.class.to_s, params[:action]
  end

  def logging_end
    Modules::LogTracer.end_trace self.class.to_s, params[:action]
    Modules::LogTracer.clean_up
  end

end