class ActivitiesController < ApplicationController
  before_filter :authenticate_admin!

	def index
		@perpage=50
		@page = params[:page] || 1
		@page = @page.to_i
		@next = @page+1
		@previous = @page > 1 ? @page-1 : nil
		where = {}
		where[:external_user_id] = params[:external_user_id] if params[:external_user_id]
		where[:external_product_id] = params[:external_product_id] if params[:external_product_id]
		where[:activity] = params[:activity] if params[:activity]
		@activities = Activity.where(where).paginate(:page => @page, :limit => @perpage).desc(:created_at)
	end

end
