require 'rails_helper'

describe User do

	describe 'validations' do

		it 'fails validation with no external_id' do
      user = User.new()
      user.valid?
      expect(user.errors).to include(:external_id)
		end

		it "passes validation with required fields" do
			user = User.new(external_id: "123")
			expect(user.save).to eq(true)
			expect(User.count).to eq(1)
		end

	end

	describe "fetch ip data" do 

		before do
	       stub_request(:get, "http://www.telize.com/geoip/8.8.8.9").
	         with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'www.telize.com', 'User-Agent'=>'Ruby'}).
	         to_return(:status => 301, :body => "{}", :headers => {'location'=>'http://www.telize.com/geoip/8.8.8.9/redirected-test'})

	       stub_request(:get, "http://www.telize.com/geoip/8.8.8.9/redirected-test").
	         with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'www.telize.com', 'User-Agent'=>'Ruby'}).
	         to_return(:status => 200, :body => "{\"status\":\"success\",\"country\":\"United States\",\"countryCode\":\"US\",\"region\":\"\",\"regionName\":\"\",\"city\":\"\",\"zip\":\"\",\"lat\":\"38\",\"lon\":\"-97\",\"timezone\":\"\",\"isp\":\"Level 3 Communications\",\"org\":\"Google\",\"as\":\"AS15169 Google Inc.\",\"query\":\"8.8.8.7\"}", :headers => {'content-type'=>'application/json'})
	    end

	    it "returns nil if no ip provided" do
	    	user = User.new(external_id: "123")
	    	expect(user.get_ip_location).to eq(nil)
	    end

	    it "fetches ip location info" do
	    	user = User.new(external_id: "123", ip: '8.8.8.9')
			Rails.cache.clear
			data = user.get_ip_location
			expect(data['status']).to eq('success')
	    end

	end

	describe "pick algorithm" do

		let(:user) {User.new(external_id: "123", ip: '8.8.8.9')}

		it "picks random algorithm for user" do
			expect(user.algorithm).to eq(nil)
			repeat = User.algorithm_options.size * 100
			repeat.times.map{
				algorithm = User.pick_algorithm
				expect(User.algorithm_options).to include(algorithm)
			}
		end

		it "sets algorithm if null" do
			user.set_algorithm
			user_check = User.find_by(external_id: "123")
			expect(User.algorithm_options).to include(user_check.algorithm)
		end

		it "doesn't update algorithm if it is contained in allowed options" do
			user.update(algorithm: User.algorithm_options[0])
			user.set_algorithm
			user_check = User.find_by(external_id: "123")
			expect(user_check.algorithm).to eq(User.algorithm_options[0])
		end

		it "updates algorithm if it isnot contained in allowed options" do
			user.update(algorithm: "LULULULULULUL")
			user.set_algorithm
			user_check = User.find_by(external_id: "123")
			expect(User.algorithm_options).to include(user_check.algorithm)
		end

	end

	describe "find_by_email" do
		it "fetches user by email" do
			user = FactoryGirl.create(:user, email_md5: '7ddf35b6f41179ebdeb97733e1664b4d')
			expect(User.find_by_email('gastaobrun@gmail.com').first).to eq(user)
		end
	end

	describe "recommends product" do

		before do
			user = FactoryGirl.create(:user, external_id: 1)
			@user2 = FactoryGirl.create(:user, external_id: 2)

			activities=[]

			activities << Activity.create(user: user, external_user_id: user.external_id, external_product_id: '123', activity: 'read', ip: '8.8.8.8', resource: {'id' => "123", 'uri' => "http://goodnoows.com/a/189824201/", 'date' => Time.now, 'title' => "welcome to jamaica, enjoy your stay", 'short_content' => "hello world my friends from hypermindr. enjoy our world of news recommendation."}, anonymous: false)


			activities << Activity.create(user: @user2, external_user_id: @user2.external_id, external_product_id: '123', activity: 'read', ip: '8.8.8.8', resource: {'id' => "123"}, anonymous: false)

			activities << Activity.create(user: user, external_user_id: user.external_id, external_product_id: '321', activity: 'read', ip: '8.8.8.8', resource: {'id' => "321", 'uri' => "http://goodnoows.com/a/189824201/", 'date' => Time.now, 'title' => "be nice to your fellow humans", 'short_content' => "hello world my friends from hypermindr. enjoy our world of news recommendation."}, anonymous: false)

			activities << Activity.create(user: user, external_user_id: user.external_id, external_product_id: '322', activity: 'read', ip: '8.8.8.8', resource: {'id' => "322", 'uri' => "http://goodnoows.com/a/189824201/", 'date' => Time.now, 'title' => "Caros usuários, naveguem à vontade em nosso barco", 'short_content' => "Recomendamos que vistam seus salva-vidas ao embarcar."}, anonymous: false)

			activities. each do |activity|
				activity.process
				Modules::Barbante.process_activity_fastlane(activity.external_user_id, activity.external_product_id, activity.activity, activity.created_at.utc.strftime("%FT%T.%3NZ"), activity.anonymous)
				Modules::Barbante.process_activity_slowlane(activity.external_user_id, activity.external_product_id, activity.activity, activity.created_at.utc.strftime("%FT%T.%3NZ"), activity.anonymous)
			end

		end

		it "returns just ids" do
			# expect(Product.count).to eq(3)
			templates = @user2.get_templates
			# puts "templates:"
			# templates.each{|template| puts template.inspect}
			expect(templates.first.external_id).to eq("1")

			# puts 'products'
			# Mongoid::default_session[:products].find().each{|p| puts p.inspect}
			# puts 'product_models'
			# Mongoid::default_session[:product_models].find().each{|p| puts p.inspect}

			recommendation = @user2.get_recommended_products(count: 20, algorithm: 'HRChunks', ids_only: true)
			expect(recommendation[:success]).to eq(true)
			expect(recommendation[:products].count).to eq(2)
			expect(["321","322"]).to include(recommendation[:products][0])
		end

		it "returns all data" do
			recommendation = @user2.get_recommended_products(count: 20, algorithm: 'HRChunks', ids_only: false)
			expect(recommendation[:success]).to eq(true)
			expect(recommendation[:products].count).to eq(2)
			expect(["321","322"]).to include(recommendation[:products][0][:id])
		end

		it "filters recommendation" do
			recommendation = @user2.get_recommended_products(count: 20, algorithm: 'HRChunks', ids_only: true, filter: '{"language":"english"}')
			expect(recommendation[:success]).to eq(true)
			expect(recommendation[:products].count).to eq(1)
			expect(["321"]).to include(recommendation[:products][0])
		end

		it "raises error if filter is not valid json" do
			recommendation = @user2.get_recommended_products(count: 20, algorithm: 'HRChunks', ids_only: true, filter: 'english')
			expect(recommendation[:success]).to eq(false)
		end

  end


  describe "ab test" do
    context "when ab testing is active" do
			after do
				Settings[:user][:ab_testing]=true
			end

      it "picks an ab test group on create if not specified" do
        user = User.create(external_id: "123")
        expect(User.ab_groups).to include(user.ab_group)
      end

      it "does not pick an ab test group on create if specified" do
        user = User.create(external_id: "123", ab_group: 'K')
        expect(user.ab_group).to eq('K')
      end

      it "saves ab_group when not present" do
        Settings[:user][:ab_testing]=false
        user = User.create(external_id: "123")
        user.update_attributes ab_group: nil
        expect(user.ab_group).to eq(nil)

        Settings[:user][:ab_testing]=true
        user.touch
        expect(User.ab_groups).to include(User.first.ab_group)
      end

    end

    context "when ab testing is inactive" do
      before do
        Settings[:user][:ab_testing]=false
      end
			after do
				Settings[:user][:ab_testing]=true
			end
      it "does not pick an ab test group" do
        user = User.create(external_id: "123")
        expect(user.ab_group).to eq(nil)
      end
    end
  end

end