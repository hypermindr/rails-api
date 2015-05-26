require 'rails_helper'

describe V2::ApiController, type: :controller do
  
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

	describe "POST #product/:id" do

		it "returns missing status parameter" do
			post :product, client_id: client.id, apikey: client.apikey, id: '123'
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('required parameter `status` not informed')
		end

    it "returns invalid status parameter" do
      post :product, client_id: client.id, apikey: client.apikey, id: '123', status: 'hello'
      expect(json['result']['success']).to eq(false)
      expect(json['result']['message']).to have_key('status')
    end

		it "returns success for new product" do
			post :product, client_id: client.id, apikey: client.apikey, id: '0001', status: 'active', resource:'{"hello":"world"}'
			expect(json['result']['success']).to eq(true)
			expect(json['result']).to have_key('resource_id')
			expect(Product.count).to eq(1)
		end

		it "does not add another product if it already exists" do
			Product.create(external_id: '0001', date: Time.now, url:'http://google.com', title: 'hello world', status: 'active')
			expect(Product.count).to eq(1)

			post :product, client_id: client.id, apikey: client.apikey, id: '0001', status: 'active'
			expect(json['result']['success']).to eq(true)
			expect(json['result']['resource_id']).to eq('0001')
			expect(Product.count).to eq(1)
		end

		it "returns false if cannot save product" do
			post :product, client_id: client.id, apikey: client.apikey, id: '1234'
			expect(Product.count).to eq(0)
			expect(json['result']['success']).to eq(false)
    end

    it "updates products if called subsequently" do
      post :product, client_id: client.id, apikey: client.apikey, id: '0001', status: 'active', resource:'{"hello":"world"}'
      expect(Product.first.status).to eq('active')
      expect(Product.first.resource['hello']).to eq('world')
      post :product, client_id: client.id, apikey: client.apikey, id: '0001', status: 'inactive', resource:'{"hello":"brazil"}'
      expect(Product.first.status).to eq('inactive')
      expect(Product.first.resource['hello']).to eq('brazil')
    end

    it "returns invalid json if bad resource posted" do
      post :product, client_id: client.id, apikey: client.apikey, id: '0001', status: 'active', resource:'{"hello":"world}'
      expect(json['result']['success']).to eq(false)
      expect(json['result']['message']).to eq('resource contains invalid json')
    end

	end

	describe "GET #track_activity" do

		before do
			@user = User.create(external_id: '0001')
		end

		it "fails if no user_id suplied" do
			get :track_activity, client_id: client.id, apikey: client.apikey
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('required parameter `user_id` not informed') 
		end

		it "doesnt cache if no resource id provided" do
			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'browse', user_id: @user.external_id
			expect(json['result']['success']).to eq(true)
			expect(Activity.count).to eq(1)

			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'browse', user_id: @user.external_id
			expect(json['result']['success']).to eq(true)
			expect(Activity.count).to eq(2)
		end

		it "caches if product_id provided" do
			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'read', user_id: @user.external_id, resource: {id: '12345'}
			expect(json['result']['success']).to eq(true)
			expect(Activity.count).to eq(1)

			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'read', user_id: @user.external_id, resource: {id: '12345'}
			expect(json['result']['success']).to eq(true)
			expect(Activity.count).to eq(1)
		end

		it "renders callback parameter" do
			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'read', user_id: @user.external_id, callback: 'xyz', resource: {id: '12345'}
			expect(response).to be_success
			expect(response.body).to eq("xyz({\"result\":{\"success\":true}})")
		end

		it "saves users algorithm setting" do
			@user.set_algorithm
			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'browse', user_id: @user.external_id, resource: {hello: 'world'}
			expect(response.body).to eq("{\"result\":{\"success\":true}}")
			Activity.last.process
			expect(Activity.last.algorithm).to eq(@user.algorithm)
		end

		it "creates user if not found in the db" do
			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'browse', user_id: '1234', resource: {hello: 'world'}
			Activity.last.process
			expect(User.count).to eq(2)
		end

		it "does not create user if found in the db" do
			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'browse', user_id: @user.external_id, resource: {hello: 'world'}
			Activity.last.process
			expect(User.count).to eq(1)
			# expect(Rails.cache.read("user.model.#{@user.external_id}")).to eq(@user)
		end

		it "does not create user if found in the db - part 2 (cached)" do
			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'browse', user_id: '1234', resource: {hello: 'world'}
			Activity.last.process
			expect(User.count).to eq(2)

			get :track_activity, client_id: client.id, apikey: client.apikey, activity: 'browse', user_id: '1234', resource: {hello: 'world'}
			Activity.last.process
			expect(User.count).to eq(2)
		end

	end

	describe "POST #user/:id" do

		it "returns client_id not informed" do
			post :user, id:'100'
			expect(json).to have_key('result')
			expect(json['result']).to have_key('success')
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('required parameter `client_id` not informed')
		end

		it "returns apikey not informed" do
			post :user, id: '100', client_id: 'abc'
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('required parameter `apikey` not informed')
		end

		it "returns invalid client" do
			post :user, id: '100', client_id: 'abc', apikey: 'def'
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('invalid client')
		end

		it "returns invalid apikey" do
			post :user, id:'100', client_id: client.id, apikey: 'def'
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('invalid api key')
		end

		it "returns success for new user" do
      post :user, id: '100', client_id: client.id, apikey: client.apikey
			expect(json['result']['success']).to eq(true)
			expect(json['result']).to have_key('resource_id')
			expect(User.count).to eq(1)
		end

		it "returns success for existing user" do
			user = User.create(external_id: '0001')
			expect(User.count).to eq(1)
			post :user, client_id: client.id, apikey: client.apikey, id: '0001'
      puts json
			expect(json['result']['success']).to eq(true)
			expect(json['result']['resource_id']).to eq(user.external_id)
			expect(User.count).to eq(1)
    end

    it "doesn't save product if it hasn't changed" do
      User.create(external_id: '0001', email: 'joe@test.com', algorithm: User.algorithm_options.first)
      post :user, client_id: client.id, apikey: client.apikey, id: '0001', email: 'joe@test.com'
      expect(json['result']['success']).to eq(true)
    end

  end

  describe 'POST #delete_old_products' do

    it 'returns false for time not informed' do
      post :delete_old_products, client_id: client.id, apikey: client.apikey
      expect(json).to have_key('result')
      expect(json['result']).to have_key('success')
      expect(json['result']['success']).to eq(false)
      expect(json['result']['message']).to eq('required parameter `updated_before_date` not informed')
    end

    it 'returns false for future time informed' do
      future = (Time.now + 1.minute).to_i
      post :delete_old_products, client_id: client.id, apikey: client.apikey, updated_before_date: future
      expect(json['result']['success']).to eq(false)
      expect(json['result']['message']).to eq('invalid date - must be in the past')
    end

    it 'returns false for invalid time informed' do
      post :delete_old_products, client_id: client.id, apikey: client.apikey, updated_before_date: '2014-09-10'
      expect(json['result']['success']).to eq(false)
      expect(json['result']['message']).to eq('invalid date - must be unix timestamp')
    end

    it 'returns true for valid format and deletes old products' do
      Product.create(external_id: '0001', updated_at: (Time.now - 10.minutes))
      Product.create(external_id: '0002', updated_at: (Time.now - 10.minutes))
      Product.create(external_id: '0003')

      post :delete_old_products, client_id: client.id, apikey: client.apikey, updated_before_date: (Time.now - 1.minute).to_i

      expect(json['result']['success']).to eq(true)
      expect(Product.active.count).to eq(1)
    end

  end

  describe 'GET #recommend' do

		let(:user){ FactoryGirl.create(:user) }

    it 'fails if user id not provided' do
      get :recommend, client_id: client.id, apikey: client.apikey
      expect(json['result']['success']).to eq(false)
      expect(json['result']['message']).to eq('required parameter `user_id` not informed')
    end

		it 'fails if user not found' do
			get :recommend, client_id: client.id, apikey: client.apikey, user_id: 'hahaha'
			expect(json['result']['success']).to eq(false)
			expect(json['result']['message']).to eq('user not found')
		end

		it 'returns empty recommendations if nothing to recommend' do
			get :recommend, client_id: client.id, apikey: client.apikey, user_id: user.external_id
			expect(json['result']['success']).to eq(true)
			expect(json['result']['resources']).to eq([])
		end

		it 'returns filtered recommendations if filter sent' do
			get :recommend, client_id: client.id, apikey: client.apikey, user_id: user.external_id, filter: '{"language":"english"}'
			expect(json['result']['success']).to eq(true)
			expect(json['result']['resources']).to eq([])
		end

  end

end