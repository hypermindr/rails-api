require 'rails_helper'

describe Activity do

	let(:client) {FactoryGirl.create(:client)}
	let(:user) {User.create(external_id: '1', ip: '8.8.8.8')}

	describe 'validations' do

		it 'fails validation with no client, activity, ip and external_user_id' do
      activity = Activity.new()
      activity.valid?
      expect(activity.errors).to include(:activity)
      expect(activity.errors).to include(:ip)
      expect(activity.errors).to include(:external_user_id)
		end
		
		it 'fails validation for external_product_id not included for read' do
      activity = Activity.new(user: user, activity: 'read', ip: '8.8.8.8', external_user_id: user.external_id)
      activity.valid?
      expect(activity.errors).to include(:external_product_id)
		end

		it 'passes validation with required fields (read)' do
			activity = Activity.create(user: user, activity: 'read', ip: '8.8.8.8', external_user_id: user.external_id, external_product_id: 'ab100')
			expect(activity.save).to eq(true)
			expect(Activity.count).to eq(1)
		end

		it 'passes validation with required fields (browse)' do
			activity = Activity.create(user: user, activity: 'browse', ip: '8.8.8.8', external_user_id: user.external_id)
			expect(activity.save).to eq(true)
			expect(Activity.count).to eq(1)
		end

	end
0
	describe "process" do

		it "registers user if not already registered" do
			activity = Activity.create!(external_user_id: 'abc', activity: 'browse', ip: '8.8.8.8')
			expect(activity.process).to eq(true)
			expect(User.count).to eq(1)
			expect(User.last.external_id).to eq('abc')
		end

		it "returns true if product already associated" do
			product = FactoryGirl.create(:product)
			activity = Activity.create!(activity: 'read', product: product, ip: '8.8.8.8', external_user_id: 'abc', external_product_id: '123', anonymous: false)
			expect(activity.process).to eq(true)
		end

		describe "product creation" do

			it "creates product if doesn't already exist" do
				activity = Activity.create(user: user, activity: 'read', ip: '8.8.8.8', resource: {'id' => "123", 'uri' => "http://goodnoows.com/a/189824201/", 'date' => Time.now, 'title' => "heelo world", 'short_content' => "hello world my friends from hypermindr. enjoy our world of news recommendation."}, external_user_id: user.external_id, external_product_id: '123', anonymous: false)
				expect(activity.process).to eq(true)
				expect(Product.count).to eq(1)
				expect(activity.product).to eq(Product.last)
				expect(activity.language).to eq(Product.last.language)
			end

			it "returns false if fails creating product" do
				activity = Activity.new(user: user, activity: 'read', ip: '8.8.8.8', resource: {}, external_user_id: user.external_id )
				expect(activity.process).to eq(false)
				expect(Product.count).to eq(0)
			end

		end

		it "doesnt create product if already exists" do
			product = FactoryGirl.create(:product, external_id: '123')
			expect(Product.count).to eq(1)
			activity = Activity.create(user: user, activity: 'read', ip: '8.8.8.8', resource: {'id' => "123"}, external_user_id: user.external_id, external_product_id: '123', anonymous: false)
			expect(Activity.count).to eq(1)
			expect(activity.process).to eq(true)
			expect(Product.count).to eq(1)
			expect(activity.product).to eq(Product.last)
			expect(activity.language).to eq(Product.last.language)
		end

		describe "test user ip and cache" do

			before do
		       stub_request(:get, "http://www.telize.com/geoip/8.8.8.9").
		         with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'www.telize.com', 'User-Agent'=>'Ruby'}).
		         to_return(:status => 200, :body => "{\"status\":\"success\",\"country\":\"United States\",\"countryCode\":\"US\",\"region\":\"\",\"regionName\":\"\",\"city\":\"\",\"zip\":\"\",\"lat\":\"38\",\"lon\":\"-97\",\"timezone\":\"\",\"isp\":\"Level 3 Communications\",\"org\":\"Google\",\"as\":\"AS15169 Google Inc.\",\"query\":\"8.8.8.7\"}", :headers => {'content-type'=>'application/json'})
		    end

			it "updates user ip with last ip used" do
				FactoryGirl.create(:product, external_id: '123')
				activity = Activity.create(user: user, activity: 'read', ip: '8.8.8.9', resource: {'id' => "123"}, external_user_id: user.external_id, external_product_id: '123', anonymous: false)
				expect(activity.process).to eq(true)
        user.reload
				expect(user.ip).to eq('8.8.8.9')
			end

		end

	end

	describe "update unlogged users" do

		let(:source_user) {FactoryGirl.create(:user, external_id: 'TEMP_USER')}

		before do
			FactoryGirl.create(:activity, user: source_user, external_user_id: source_user.external_id, external_product_id: 'ABC', resource: { 'id' => 'ABC' }, session_id: 'A', anonymous: 1)
			FactoryGirl.create(:activity, user: source_user, external_user_id: source_user.external_id, external_product_id: 'BBB', resource: { 'id' => 'CCC' }, session_id: 'B', anonymous: 1)
			FactoryGirl.create(:activity, user: source_user, external_user_id: source_user.external_id, external_product_id: 'CCC', resource: { 'id' => 'CCC' }, session_id: 'B', anonymous: 1)
		end

		it "moves all activities from source user to target user for specified session" do
			target_user = FactoryGirl.create(:user, external_id: 'USER_EXISTS')
			Activity.update_user('TEMP_USER', 'USER_EXISTS', 'B')
			expect(Activity.where(external_user_id: 'TEMP_USER').count).to eq(1)
			expect(Activity.where(external_user_id: 'USER_EXISTS').count).to eq(2)
		end

		# it "deletes temporary user after update if target user exists" do
		# 	target_user = FactoryGirl.create(:user, external_id: 'USER_EXISTS')
		# 	Activity.update_user('TEMP_USER', 'USER_EXISTS')
		# 	expect(User.where(external_id: 'TEMP_USER').count).to eq(0)
		# 	expect(User.where(user_id: source_user.id).count).to eq(0)
		# 	expect(User.count).to eq(1)
		# end

		it "updates source user if target doesnt exist" do
			Activity.update_user('TEMP_USER', 'USER_DOESNT_EXIST', 'B')
			# source_user.reload
			# expect(source_user.external_id).to eq('USER_DOESNT_EXIST')
			# expect(User.count).to eq(1)
			expect(Activity.where(external_user_id: 'TEMP_USER').count).to eq(1)
			expect(Activity.where(external_user_id: 'USER_DOESNT_EXIST').count).to eq(2)
		end

	end

end
