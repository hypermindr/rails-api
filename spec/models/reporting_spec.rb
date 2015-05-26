require 'rails_helper'

describe Reporting do

	describe "sod and eod" do

		let(:date_sod_in) {Time.new(2014, 01, 13,7,01,32)}
		let(:date_sod_out) {Time.utc(2014, 01, 13,0,0,0)}
		let(:date_eod_in) {Time.new(2014, 02, 14,7,01,32)}
		let(:date_eod_out) {Time.utc(2014, 02, 15,00,00,00)}

		it "should set start of day" do
			expect(Reporting.sod(date_sod_in)).to eq(date_sod_out)
		end
		it "should set end of day" do
			expect(Reporting.eod(date_eod_in)).to eq(date_eod_out)
		end
	end

	describe "update_reporting" do

		before do
			# Settings[:user][:ab_testing]=true

			new_time = Time.local(2014, 9, 1, 12, 0, 0)
			Timecop.travel(new_time)

			# create users
			user_a = FactoryGirl.create(:user, external_id: '1', ab_group: 'A')
			user_b = FactoryGirl.create(:user, external_id: '2', ab_group: 'B')
			user_c = FactoryGirl.create(:user, external_id: '3', ab_group: 'A')
			user_d = FactoryGirl.create(:user, external_id: '4', ab_group: 'C')

			FactoryGirl.create(:activity, activity: 'browse', external_user_id: user_a.external_id, session_id: 'aaa1')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_a.external_id, external_product_id: '100', session_id: 'aaa1')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_a.external_id, external_product_id: '101', session_id: 'aaa1')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_a.external_id, external_product_id: '102', session_id: 'aaa1')

			FactoryGirl.create(:activity, activity: 'browse', external_user_id: user_b.external_id, session_id: 'bbb1')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_b.external_id, external_product_id: '100', session_id: 'bbb1')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_b.external_id, external_product_id: '104', session_id: 'bbb1')

			FactoryGirl.create(:activity, activity: 'browse', external_user_id: user_c.external_id, session_id: 'ccc1')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_c.external_id, external_product_id: '100', session_id: 'ccc1')

			new_time = Time.local(2014, 9, 2, 12, 0, 0)
			Timecop.travel(new_time)

			FactoryGirl.create(:activity, activity: 'browse', external_user_id: user_a.external_id, session_id: 'aaa2')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_a.external_id, external_product_id: '110', session_id: 'aaa2')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_a.external_id, external_product_id: '111', session_id: 'aaa2')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_a.external_id, external_product_id: '112', session_id: 'aaa2')
			FactoryGirl.create(:activity, activity: 'browse', external_user_id: user_a.external_id, session_id: 'aaa3')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_a.external_id, external_product_id: '113', session_id: 'aaa3')

			FactoryGirl.create(:activity, activity: 'browse', external_user_id: user_b.external_id, session_id: 'bbb2')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_b.external_id, external_product_id: '110', session_id: 'bbb2')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_b.external_id, external_product_id: '114', session_id: 'bbb2')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_b.external_id, external_product_id: '115', session_id: 'bbb2')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_b.external_id, external_product_id: '116', session_id: 'bbb2')
			FactoryGirl.create(:activity, activity: 'browse', external_user_id: user_b.external_id, session_id: 'bbb3')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_b.external_id, external_product_id: '117', session_id: 'bbb3')
			FactoryGirl.create(:activity, activity: 'browse', external_user_id: user_d.external_id, session_id: 'ddd1')
			FactoryGirl.create(:activity, activity: 'read', external_user_id: user_d.external_id, external_product_id: '117', session_id: 'ddd1')

			Activity.each{|a| a.process }

			Timecop.return
		end

		let(:session){Mongoid.default_session}

		it "generates standard reporting" do
			expect(User.count).to eq(4)

			Reporting.update_standard_reporting Time.new(2014,9,1), Time.new(2014,9,2)

			d0 = session[:reporting_std].find({_id: 20140901})
			expect(d0.count).to eq(1)
			d0 = d0.first

			expect(d0['sessions']).to eq(3)
			expect(d0['users']).to eq(3)
			d0['activities'].each do |activity|
				case activity['activity']
					when 'browse'
						expect(activity['count']).to eq(3)
					when 'read'
						expect(activity['count']).to eq(6)
				end
			end

			d1 = session[:reporting_std].find({_id: 20140902})
			expect(d1.count).to eq(1)
			d1 = d1.first

			expect(d1['sessions']).to eq(5)
			expect(d1['users']).to eq(3)
			d1['activities'].each do |activity|
				case activity['activity']
					when 'browse'
						expect(activity['count']).to eq(5)
					when 'read'
						expect(activity['count']).to eq(10)
				end
			end

		end


		it "generates legacy reporting" do
			Reporting.update_reporting Time.new(2014,9,1), Time.new(2014,9,2)

			# Activity.each{|a| puts a.inspect}

			d0 = session[:reporting].find({_id: Time.utc(2014,9,1)})
			expect(d0.count).to eq(1)
			d0 = d0.first['value']
			expect(d0['visits']['total']).to eq(3)
			expect(d0['visits']['all']).to eq(2)					#A
			expect(d0['visits']['control']).to eq(1)			#B
			expect(d0['visits']['control700']).to eq(0)		#C
			expect(d0['reads']['total']).to eq(6)
			expect(d0['reads']['all']).to eq(4)						#A
			expect(d0['reads']['control']).to eq(2)				#B
			expect(d0['reads']['control700']).to eq(0)		#C

			d1 = session[:reporting].find({_id: Time.utc(2014,9,2)})
			expect(d1.count).to eq(1)
			d1 = d1.first['value']
			expect(d1['visits']['total']).to eq(5)
			expect(d1['visits']['all']).to eq(2)					#A
			expect(d1['visits']['control']).to eq(2)			#B
			expect(d1['visits']['control700']).to eq(1)		#C
			expect(d1['reads']['total']).to eq(10)
			expect(d1['reads']['all']).to eq(4)						#A
			expect(d1['reads']['control']).to eq(5)				#B
			expect(d1['reads']['control700']).to eq(1)		#C

		end

	end

	describe "metric reports" do

		before do
			user_day = [
					## D-8 no
					{created_at: Date.today-8, external_user_id: 'AAA', sessions: 2},
					{created_at: Date.today-8, external_user_id: 'BBB', sessions: 1},
					{created_at: Date.today-8, external_user_id: 'CCC', sessions: 1},
					{created_at: Date.today-8, external_user_id: 'DDD', sessions: 1},
					## D-7 yes
					{created_at: Date.today-7, external_user_id: 'AAA', sessions: 1},
					{created_at: Date.today-7, external_user_id: 'BBB', sessions: 3},
					{created_at: Date.today-7, external_user_id: 'CCC', sessions: 0},
					{created_at: Date.today-7, external_user_id: 'DDD', sessions: 2},
					{created_at: Date.today-7, external_user_id: 'KKK', sessions: 2},
					{created_at: Date.today-7, external_user_id: 'JJJ', sessions: 3},
					## D-6 yes
					{created_at: Date.today-6, external_user_id: 'AAA', sessions: 0},
					{created_at: Date.today-6, external_user_id: 'BBB', sessions: 0},
					{created_at: Date.today-6, external_user_id: 'CCC', sessions: 1},
					{created_at: Date.today-6, external_user_id: 'DDD', sessions: 0},
					{created_at: Date.today-6, external_user_id: 'LLL', sessions: 2},
					## D-5 yes
					{created_at: Date.today-5, external_user_id: 'AAA', sessions: 1},
					{created_at: Date.today-5, external_user_id: 'BBB', sessions: 1},
					{created_at: Date.today-5, external_user_id: 'CCC', sessions: 1},
					{created_at: Date.today-5, external_user_id: 'DDD', sessions: 2},
					## D-4 yes
					{created_at: Date.today-4, external_user_id: 'AAA', sessions: 1},
					{created_at: Date.today-4, external_user_id: 'BBB', sessions: 0},
					{created_at: Date.today-4, external_user_id: 'CCC', sessions: 2},
					{created_at: Date.today-4, external_user_id: 'DDD', sessions: 0},
					{created_at: Date.today-4, external_user_id: 'KKK', sessions: 1},
					## D-3 yes
					{created_at: Date.today-3, external_user_id: 'AAA', sessions: 2},
					{created_at: Date.today-3, external_user_id: 'BBB', sessions: 2},
					{created_at: Date.today-3, external_user_id: 'CCC', sessions: 2},
					{created_at: Date.today-3, external_user_id: 'DDD', sessions: 1},
					{created_at: Date.today-3, external_user_id: 'KKK', sessions: 1},
					{created_at: Date.today-3, external_user_id: 'LLL', sessions: 3},
					## D-2 yes
					{created_at: Date.today-2, external_user_id: 'AAA', sessions: 1},
					{created_at: Date.today-2, external_user_id: 'BBB', sessions: 2},
					{created_at: Date.today-2, external_user_id: 'CCC', sessions: 5},
					{created_at: Date.today-2, external_user_id: 'DDD', sessions: 3},
					## D-1 yes
					{created_at: Date.today-1, external_user_id: 'AAA', sessions: 0},
					{created_at: Date.today-1, external_user_id: 'BBB', sessions: 1},
					{created_at: Date.today-1, external_user_id: 'CCC', sessions: 3},
					{created_at: Date.today-1, external_user_id: 'DDD', sessions: 2},
					## D0 - no
					{created_at: Date.today, external_user_id: 'AAA', sessions: 4},
					{created_at: Date.today, external_user_id: 'BBB', sessions: 3},
					{created_at: Date.today, external_user_id: 'CCC', sessions: 2},
					{created_at: Date.today, external_user_id: 'DDD', sessions: 1},
					{created_at: Date.today, external_user_id: 'MMM', sessions: 1},
					{created_at: Date.today, external_user_id: 'KKK', sessions: 1}
			]

			@tags={'AAA'=> 'A', 'BBB'=>'B', 'CCC'=>'', 'DDD'=>'', 'KKK' => 'A', 'LLL' => 'B', 'JJJ' => '', 'MMM' => ''}

			user_day.each do |day|
				day[:sessions].times do |i|

					# generate session id
					session_id = Digest::MD5.hexdigest("#{day[:external_user_id]}.#{day[:created_at].to_s}.#{i}")

					# generate 1 to 6 activities
					(1 + rand(6)).times do
						date = Time.utc(day[:created_at].year, day[:created_at].month, day[:created_at].day) + rand(1439).minutes
						# puts "#{day[:created_at]} => #{date}"
						Activity.create(created_at: date, activity: 'view', ip: '8.8.8.8', resource: {'id' => 'LALA', 'tag' => {'bulb' => @tags[day[:external_user_id]]}}, external_user_id: day[:external_user_id], external_product_id: 'LALA', anonymous: false, session_id: session_id)
					end

					date = Time.utc(day[:created_at].year, day[:created_at].month, day[:created_at].day) + rand(1439).minutes
					Activity.create(created_at: date, activity: 'browse', ip: '8.8.8.8', resource: {'id' => 'LALA'}, external_user_id: day[:external_user_id], anonymous: false, session_id: session_id)

				end

			end
		end

		it "generates visits per user per week report" do

			Reporting.visits_per_user_per_week(Date.today, 'bulb')
			result = Mongoid.default_session[:reporting_visits_user_week].find(_id: Date.today.strftime('%Y%m%d').to_i, tag: 'bulb')
			expect(result.count).to eq(1)
			expect(result.first['data']['N/A']).to eq(9.0)
			expect(result.first['data']['A']).to eq(5.0)
			expect(result.first['data']['B']).to eq(7.0)

		end

		it "generates activity per user per day report" do

			#add purchases
			purchases = [
					{external_user_id: 'AAA', purchases: 2},
					{external_user_id: 'KKK', purchases: 1},

					{external_user_id: 'BBB', purchases: 3},
					{external_user_id: 'LLL', purchases: 1},

					{external_user_id: 'CCC', purchases: 1},
					{external_user_id: 'DDD', purchases: 2}
			]
			purchases.each do |buy|
				buy[:purchases].times do
					date = Date.today
					date = Time.utc(date.year, date.month, date.day) + rand(1439).minutes
					Activity.create(created_at: date, activity: 'purchase', ip: '8.8.8.8', resource: {'id' => 'LALA', 'tag' => {'bulb' => @tags[buy[:external_user_id]]}}, external_user_id: buy[:external_user_id], external_product_id: 'LALA', anonymous: false)
				end
			end

			Reporting.activity_per_user_per_day(Date.today, 'bulb')
			result = Mongoid.default_session[:reporting_activity_tag].find(_id: Date.today.strftime('%Y%m%d').to_i, tag: 'bulb')
			expect(result.count).to eq(1)
			puts result.first.inspect
			expect(result.first['data']['N/A']['users']).to eq(3)
			expect(result.first['data']['A']['users']).to eq(2)
			expect(result.first['data']['B']['users']).to eq(2)

			expect(result.first['data']['N/A']['purchase']).to eq(3)
			expect(result.first['data']['A']['purchase']).to eq(3)
			expect(result.first['data']['B']['purchase']).to eq(4)

		end

	end

end