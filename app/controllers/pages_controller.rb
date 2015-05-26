class PagesController < ApplicationController
	before_filter :authenticate_admin!

	def index
		@active = params[:interval] || '30'
		case @active
		when '7' then
			start_date = 7.days.ago
			end_date = Time.now
		when '30' then
			start_date = 30.days.ago
			end_date = Time.now
		when 'year' then
			start_date = Time.new(Time.now.year,1,1)
			end_date = Time.now
    end

    @activities = Reporting.get_standard_chart(start_date, end_date)

		unless Rails.env=='goodnoows'
			@visits_per_user = Reporting.get_metric_chart(start_date, end_date, {collection: :reporting_visits_user_week})

			@users = Reporting.get_metric_chart(start_date, end_date, {collection: :reporting_activity_tag, metric: 'users'})

			@sales = Reporting.get_metric_chart(start_date, end_date, {collection: :reporting_activity_tag, metric: 'buy'})

			@views = Reporting.get_metric_chart(start_date, end_date, {collection: :reporting_activity_tag, metric: 'view'})
		end

		if ['goodnoows', 'development'].include? Rails.env

			@visits_data = Reporting.get_chart_data(start_date, end_date, 'visits')

			@reads_data = Reporting.get_chart_data(start_date, end_date, 'reads')

			@avg_data = Reporting.get_chart_data(start_date, end_date, 'avg')

			@lang_data = Reporting.get_chart_data(start_date, end_date, 'langs',{sort: -1, show_top: 5})

			@recommendation_data = Reporting.get_chart_data(start_date, end_date, 'recommendation')

			@algorithms = Reporting.get_chart_data(start_date, end_date, 'algorithms')

			@recommended = Reporting.get_chart_data(start_date, end_date, 'recommended')

		end

  end

	def environment
    # displays environment settings
	end
end
