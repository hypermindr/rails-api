class UsersController < ApplicationController
  before_filter :authenticate_admin!

	def index
		# @activities = Activity.all.sort(created_at: -1).page params[:page]
		@page = params[:page] || 1
		@page = @page.to_i
		@next = @page+1
		@previous = @page > 1 ? @page-1 : nil
		@users = User.paginate(:page => @page, :limit => 50).desc(:created_at)
		# @count = User.count

	end

	def show
		@user = User.find(params[:id]) unless @user
		@activities = Rails.env=='peixe' ? [] : Activity.where(external_user_id: @user.external_id, activity: {'$ne' => 'browse'}).includes(:product).sort(created_at: -1).limit(20)
		@algorithms = [params[:algorithm]]
		@algorithms = User.algorithm_options_dev unless params[:algorithm]
		@recommendations = {}
		@endpoints={}
		@filter = "{\"resource.expiration_date\":{\"$gte\":\"#{Time.now.strftime("%F")}\"},\"resource.publishing_date\":{\"$lte\":\"#{Time.now.strftime("%F")}\"},\"resource.pages\":{\"$in\":[\"rio-de-janeiro\"]}}" if Rails.env=='peixe'
		count = params[:count]||10
		@algorithms.each do |algorithm|
			@recommendations[algorithm] = Rails.cache.fetch("recommend.#{@user.id}.#{algorithm}.#{count}",{expires_in: 1.minute}) do
				result = @user.get_recommended_products(count: count, algorithm: algorithm, ids_only: false, filter: @filter, timeout: 120)
				result[:success] ? result[:products] : []
			end

			if Settings[:tracking][:api_version]=='v1'
				@endpoints[algorithm] = "/v1/get_recommendations/20/#{algorithm}?user_id=#{@user.external_id}&client_id=530d166469702d4e5f010000&apikey=c09eed87642eaffbd69983e0d442d68064e18cc03c33b1a80b02d2c61b5a9ea2"
			else
				@endpoints[algorithm] = "/v2/recommend?user_id=#{@user.external_id}&client_id=53fe4d8b69702d78b7000000&apikey=f548ea2f5a17d3fd9a3c5be85513c0a0b07bb6791df1f3c10b9099714ccedc64&algorithm=#{algorithm}&filter=#{@filter}"
			end
		end
		@templates = Rails.cache.fetch("templates.#{@user.id}",{expires_in: 10.minutes}) do
			@user.get_templates
		end

	end

	def recommend
		if /@/.match(params[:external_id])
			@user = Rails.cache.fetch("user_by_email.#{params[:external_id]}",{expires_in: 60.minutes}) do
					User.find_by_email(params[:external_id]).first
			end
		else
			@user = Rails.cache.fetch("user_by_external_id.#{params[:external_id]}",{expires_in: 30.days}) do
				User.find_by(external_id: params[:external_id])
			end
		end

		if @user
			self.show
			if params[:layout]=='false'
				render :show, layout: false 
			else
				render :show
			end
		else
			case Rails.env
				when 'peixe'
					# 22873458 Gastao
					# 22745823 Quintella
					# 18746829 Roberto
					# 22747822 Vinicius
					@users = %w{22704339 22745823 18746829 22747822}
				else
					@users= %w{gastaobrun@gmail.com m.quintella@alum.mit.edu daniel.franz@gmail.com lucio@hypermindr.com vinicius@hypermindr.com gabriel.quevedo.leao@gmail.com eduardo.gaspar@gmail.com roberto@hypermindr.com}
			end
		end
	end

	def change_algorithm
		user = User.find(params[:user_id])
		user.update(algorithm: params[:algorithm])
		redirect_to "/recommend/#{user.id}"
	end

end
