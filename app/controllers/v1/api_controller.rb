class V1::ApiController < ApplicationController

    before_filter :validate_client
    before_filter :logging_start, only: [:add_product, :delete_product, :track_activity, :register_user, :get_recommendations]
    after_filter :logging_end, only: [:add_product, :delete_product, :track_activity, :register_user, :get_recommendations]

    skip_before_filter :validate_client, :only => [:core]


    def core
        # used to serve core.js file    
        content = Rails.cache.fetch("#{request.protocol}v1.core.js", expires_in: 15.minutes) do
            Uglifier.new.compile(render_to_string)
        end
        
        render js: content
    end

    def add_product

        unless validate_required_parameters ['external_id','date','url','title','short_content','source']
            return false
        end

        product = Product.find_by(external_id: params[:external_id]) rescue nil;
        
        if !product.nil?
            render_response({success: true, resource_id: product.id}) and return
        end

        if params['date'].to_date < 7.days.ago
            render_response({success: false, message: 'product too old'}) and return
        end

        begin 
            product = Product.create!(
                external_id: params['external_id'],
                date: params['date'],
                url: params['url'],
                title: params['title'],
                short_content: params['short_content'],
                source: params['source'],
                category: params['category'],
                icon: params['icon'],
                image: params['image']
                )

            ProductWorker.perform_async(product.id.to_s) if Settings[:product][:process_after_save]

            render_response({success: true, resource_id: product.id}) and return
        rescue => error
            render_response({success: false, message: 'could not save product', errors: error.message}) and return
        end
        
    end

    def delete_product

        unless validate_required_parameters ['external_id']
            return false
        end

        product = Product.find_by(external_id: params[:external_id]) rescue nil;
        
        if product.nil?
            render_response({success: false, message: "product not found"}) and return
        end

        product.mark_deleted

        render_response({success: true, resource: product.id.to_s}) and return
        
    end

    def track_activity

        unless validate_required_parameters ['user_id', 'activity']
            return false
        end

        if params[:resource] and params[:resource][:id]
            cache_name = "#{params[:activity]}-#{params[:user_id]}-#{params[:resource][:id]}"
            @cached = Rails.cache.fetch(cache_name)
            if @cached
                render_response({success: true}) and return
            end
        end

        user = Rails.cache.fetch("user.#{params[:user_id]}",{expires_in: 10.minutes}) do
            _user = User.find(params[:user_id])
            _user ? Hash[_user.attributes] : {}
        end

        @activity = Activity.new
        @activity.activity = params[:activity]
        @activity.user_id = params[:user_id]
        @activity.external_user_id = params[:external_id] || user['external_id']
        @activity.external_product_id = params[:resource][:id] if params[:resource] and params[:resource][:id]
        @activity.resource = params[:resource]
        @activity.ip = request.remote_ip
        @activity.session_id = params[:session_id]
        @activity.recommendation_enabled = params[:recommendation_enabled]
        @activity.algorithm = user['algorithm']
        @activity.anonymous = false

        unless @activity.save
            render_response({success: false, message: 'could not save activity', errors: @activity.errors}) and return
        end

        Rails.cache.write(cache_name, true, expires_in: 1.minute) if cache_name

        ActivityWorker.perform_async(@activity.id.to_s) if Settings[:activity][:process_after_save]

        BarbanteActivityFastlaneWorker.perform_async(@activity.external_user_id, @activity.external_product_id, @activity.activity, @activity.created_at.utc.strftime("%FT%T.%3NZ"), @activity.anonymous) unless @activity.activity=='browse'

        if @activity.activity=='browse' or @activity.anonymous
            # puts 'skip barbante'
        else
            BarbanteActivitySlowlaneWorker.perform_async(@activity.external_user_id, @activity.external_product_id, @activity.activity, @activity.created_at.utc.strftime("%FT%T.%3NZ"), @activity.anonymous)
        end

        render_response({success: true}) and return
            
    end

    def register_user

        unless validate_required_parameters ['external_id']
            return false
        end

        @user = User.find_by(external_id: params[:external_id]) rescue nil;

        if !@user.nil?
            @user.set_algorithm
            render_response({success: true, resource_id: @user.id}) and return
        end

        @user = User.new
        @user.external_id = params[:external_id]
        @user.session_id = params[:session_id]
        @user.social_id = params[:social_id]
        @user.location = params[:location]
        @user.locale = params[:locale]
        @user.gender = params[:gender]
        @user.timezone = params[:timezone]
        @user.email_md5 = params[:email_md5]
        @user.friends = params[:friends]
        @user.algorithm = User.pick_algorithm

        if @user.save
            render_response({success: true, resource_id: @user.id}) and return
        else
            render_response({success: false, message:'could not save user', errors: @user.errors}) and return
        end

    end

    def get_recommendations
        unless validate_required_parameters ['user_id']
            return false
        end


        user = Rails.cache.fetch("algorithm.#{params[:user_id]}",{expires_in: 10.minutes}) do
            User.where(external_id: params[:user_id]).first
        end

        unless user
            render_response({success: false, message:'user not found'}) and return
        end
        user.set_algorithm # set algorithm if for any reason it is not set

        algorithm = params[:algorithm] || user.algorithm
        count = params[:count] || 20
        ids_only = params[:ids_only] || true
        ids_only = ids_only=='false' ? false : true

        recommendation_cache_name = "rec.#{params[:user_id]}.#{algorithm}.#{count}"
        Rails.cache.delete(recommendation_cache_name) if params[:nocache]

        recommendations = Rails.cache.fetch(recommendation_cache_name,{expires_in: 30.seconds}) do
            user.get_recommended_products(count: count, algorithm: algorithm, ids_only: ids_only)
        end

        if recommendations[:success]
            render_response({success: true, resources: recommendations[:products]}) and return
        else
            render_response({success: false, resources: [], message: recommendations[:message]}) and return
        end

    end

    def log_recommendation
        unless validate_required_parameters ['user_id','product_id','position']
            return false
        end
        is_anonymous = params['user_id'].match(/^hmrtmp/) ? 1 : 0
        impression_date = Time.now
        if Impression.create(external_user_id: params['user_id'], external_product_id: params['product_id'], position: params['position'], anonymous: is_anonymous, created_at: impression_date)
            ImpressionWorker.perform_async(params['user_id'], params['product_id'], impression_date.utc.strftime("%FT%T.%3NZ")) if is_anonymous==0
            render_response({success: true}) and return
        else
            render_response({success: false}) and return
        end
    end

    private

    def validate_client
        unless validate_required_parameters ['client_id','apikey']
            return false
        end

        # Rails.cache.clear
        @client = Rails.cache.fetch("client-#{params[:client_id]}", expires_in: 5.minutes) do
            Client.find(params[:client_id])
        end

        unless @client
            render_response({success: false, message:'invalid client'})
            return false
        end

        if(@client.apikey != params[:apikey])
            render_response({success: false, message:'invalid api key'})
            return false
        end
        return true
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
        return true
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