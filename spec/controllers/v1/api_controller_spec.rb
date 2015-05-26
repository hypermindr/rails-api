require 'rails_helper'

describe V1::ApiController, type: :controller do
  
	let(:client){ FactoryGirl.create(:client) }
	render_views

	describe "GET #core" do
		it "returns core.js template" do
			get :core, {format: 'js'}
			expect(response).to be_success
			expect(response.body).to start_with("var HMR")
			expect(response.body).to include("HMR.tracker.prototype")
		end
	end

	describe "POST #add_product" do

		it "returns missing external_id parameter" do
			post :add_product, client_id: client.id, apikey: client.apikey
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('required parameter `external_id` not informed')
		end

		it "returns success for new product" do
			post :add_product, client_id: client.id, apikey: client.apikey, external_id: '0001', date: Time.now, url: 'http://google.com', title: 'hello world', short_content: 'hello world', source: 'hypermindR News'
			expect(json['result']['success']).to eq(true)
			expect(json['result']).to have_key('resource_id')
			expect(Product.count).to eq(1)
		end

		it "returns false for old product" do
			post :add_product, client_id: client.id, apikey: client.apikey, external_id: '0001', date: 8.days.ago, url: 'http://google.com', title: 'hello world', short_content: 'hello world', source: 'hypermindR News'
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('product too old')
			expect(Product.count).to eq(0)
		end

		it "does not add another product if it already exists" do
			product = Product.create(external_id: '0001', date: Time.now, url:'http://google.com', title: 'hello world')
			expect(Product.count).to eq(1)

			post :add_product, client_id: client.id, apikey: client.apikey, external_id: '0001', date: Time.now, url: 'http://google.com', title: 'hello world', short_content: 'hello world', source: 'hypermindR News'
			expect(json['result']['success']).to eq(true)
			expect(json['result']['resource_id']['$oid']).to eq(product.id.to_s)
			expect(Product.count).to eq(1)
		end

		it "returns false if cannot save product" do
			post :add_product, client_id: client.id, apikey: client.apikey, date: Time.now, url: "http", title: "hello world", short_content: "lorem ipsum dolor sit amet", source: "hypermindR News"
			expect(Product.count).to eq(0)
			expect(json['result']['success']).to eq(false)
		end

	end

	describe "POST #delete_product" do
		it "returns missing external_id parameter" do
			post :delete_product, client_id: client.id, apikey: client.apikey
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('required parameter `external_id` not informed')
		end

		it "returns product not found" do
			post :delete_product, client_id: client.id, apikey: client.apikey, external_id: '0001'
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('product not found')
		end

		it "marks product as deleted" do
			product = Product.create(external_id: '0001', date: Time.now, url:'http://google.com', title: 'hello world')

			post :delete_product, client_id: client.id, apikey: client.apikey, external_id: '0001'
			expect(json['result']['success']).to eq(true)
			product.reload
			expect(product.deleted_on).to_not eq(nil)
		end
	end

	describe "POST #track_activity" do

		before do
			@user = User.create(external_id: '0001')
		end

		it "fails if no user_id suplied" do
			get :track_activity, client_id: client.id, apikey: client.apikey
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('required parameter `user_id` not informed') 
		end

		it "doesnt cache if no resource id provided" do
			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'browse', user_id: @user.id, external_id: @user.external_id
			expect(json['result']['success']).to eq(true)
			expect(Activity.count).to eq(1)

			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'browse', user_id: @user.id, external_id: @user.external_id
			expect(json['result']['success']).to eq(true)
			expect(Activity.count).to eq(2)
		end

		it "caches if resource id provided" do
			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'read', user_id: @user.id, resource: {id: 12345}
			# puts json['result']
			expect(json['result']['success']).to eq(true)
			expect(Activity.count).to eq(1)

			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'read', user_id: @user.id, resource: {id: 12345}
			expect(json['result']['success']).to eq(true)
			expect(Activity.count).to eq(1)
		end

		it "renders callback parameter" do
			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'read', user_id: @user.id, callback: 'xyz', resource: {id: 12345}
			expect(response).to be_success
			expect(response.body).to eq("xyz({\"result\":{\"success\":true}})")
		end

		it "saves users algorithm setting" do
			@user.set_algorithm
			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'read', user_id: @user.id, resource: {id: 12345}
			expect(Activity.last.algorithm).to eq(@user.algorithm)
		end

	end



	describe "POST #register_user" do

		it "returns client_id not informed" do
			post :register_user
			expect(json).to have_key('result')
			expect(json['result']).to have_key('success')
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('required parameter `client_id` not informed')
		end

		it "returns apikey not informed" do
			post :register_user, client_id: 'abc'
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('required parameter `apikey` not informed')
		end

		it "returns invalid client" do
			post :register_user, client_id: 'abc', apikey: 'def'
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('invalid client')
		end

		it "returns invalid apikey" do
			post :register_user, client_id: client.id, apikey: 'def'
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('invalid api key')
		end

		it "returns missing parameter" do
			post :register_user, client_id: client.id, apikey: client.apikey
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('required parameter `external_id` not informed')
		end

		it "returns success for new user" do
			post :register_user, client_id: client.id, apikey: client.apikey, external_id: '0001'
			expect(json['result']['success']).to eq(true)
			expect(json['result']).to have_key('resource_id')
			expect(User.count).to eq(1)
		end

		it "returns success for existing user" do
			user = User.create(external_id: '0001')
			expect(User.count).to eq(1)
			post :register_user, client_id: client.id, apikey: client.apikey, external_id: '0001'
			expect(json['result']['success']).to eq(true)
			expect(json['result']['resource_id']['$oid']).to eq(user.id.to_s)
			expect(User.count).to eq(1)
		end

	end

end