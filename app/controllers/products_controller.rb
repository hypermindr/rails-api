class ProductsController < ApplicationController
  before_filter :authenticate_admin!

	def index
		# @activities = Activity.all.sort(created_at: -1).page params[:page]
		@page = params[:page] || 1
		@page = @page.to_i
		@next = @page+1
		@previous = @page > 1 ? @page-1 : nil
		@products = Product.paginate(:page => @page, :limit => 50).desc(:created_at)
		# @count = Product.count
	end

	def show
		@product = Product.find(params[:id])
		@activities = Activity.where(product: @product).sort(created_at: -1)
	end
end
