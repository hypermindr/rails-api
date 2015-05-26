require 'rails_helper'

describe Product do

	describe 'validations' do
	  	let(:product) { FactoryGirl.create(:product) }

		it 'fails validation with no external_id' do
      product = Product.new()
      product.valid?
      expect(product.errors).to include(:external_id)
		end
	end


	describe 'get_language' do

	  	it 'detects english language by title' do
	  		product = FactoryGirl.create(:product, title: 'Hello, this is a sample text string used to detect english language', full_content: nil, short_content: nil)
	  		expect(product.get_language).to eq(:english)
	  	end

	  	it 'detects portuguese language by title' do
	  		product = FactoryGirl.create(:product, title: 'Olá, este é um texto utilizado para a detecção de idioma', full_content: nil, short_content: nil, language: nil)
	  		expect(product.get_language).to eq(:portuguese)
	  	end
	end

	describe 'get_content' do

	  	it 'returns short_content when full_content not available' do
	  		product = FactoryGirl.create(:product, full_content: nil, short_content: 'hello world my friend')
	  		expect(product.get_content).to eq('hello world my friend')
	  	end

	  	it "returns full_content if available" do
	  		product = FactoryGirl.create(:product, full_content: 'hello world my friend', short_content: nil )
	  		expect(product.get_content).to eq('hello world my friend')
	  	end

	  	it "returns nil if no content available" do
	  		product = FactoryGirl.create(:product, full_content: nil, short_content: nil )
	  		expect(product.get_content).to eq(nil)
	  	end
	end

	describe "self.get_content()" do
		it "returns nil if no url is provided" do
			expect(Product.get_content()).to eq(nil)
			expect(Product.get_content('')).to eq(nil)
		end

		it "returns text content for good url" do

		    body = File.open(File.dirname(__FILE__) + '/../support/fixtures/goodnoows-article.html').read
		    stub_request(:get, "http://goodnoows.com/a/189824201/").
		         with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'goodnoows.com', 'User-Agent'=>'Ruby'}).
		         to_return(:status => 200, :body => body, :headers => {'content-type'=>'text/html'})

			expect(Product.get_content("http://goodnoows.com/a/189824201/")).to eq("\n\n\nLifehacker\n\nQuick Control Panel Adds a Customizable Control Center to Android\n\nAndroid: Control Center is one of the better new additions in iOS 7. If you want something like that on your Android device, Quick Control Panel does it for free and lets you customize it to your liking.\nLike iOS' Control Center, you will need to swipe upwards from the bottom edge of the phone to activate the app. The panel has a space for app shortcuts, music playback controls (along with \"now playing\"), toggles for different...\n\n")
		end

	end

	describe "self.fetch()" do

		before do

			stub_request(:get, "http://goodnoows.com/view/article/189824201/").
		         with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'goodnoows.com', 'User-Agent'=>'Ruby'}).
		         to_return(:status => 302, :headers => {'content-type'=>'text/html', 'Location' => 'http://goodnoows.com/a/189824201/'})

		    @body = File.open(File.dirname(__FILE__) + '/../support/fixtures/goodnoows-article.html').read
		    stub_request(:get, "http://goodnoows.com/a/189824201/").
		         with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'goodnoows.com', 'User-Agent'=>'Ruby'}).
		         to_return(:status => 200, :body => @body, :headers => {'content-type'=>'text/html'})
		end

		it "returns nil if limit is 0" do
			expect(Product.fetch("http://goodnoows.com/a/189824201/", 0)).to eq(nil)
		end

		it "re-fetches if it redirects" do
		    expect(Product.fetch('http://goodnoows.com/view/article/189824201/')).to eq(@body)
		end

		it "returns value if doesnt recognize response code" do
			stub_request(:get, "http://goodnoows.com/view/article/189824202/").
		         with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'goodnoows.com', 'User-Agent'=>'Ruby'}).
		         to_return(:status => 500, :body => 'hello', :headers => {'content-type'=>'text/html'})

		    expect(Product.fetch('http://goodnoows.com/view/article/189824202/')).to eq(nil)
		end
  end

  describe "date" do
    it 'sets date to current date if not informed' do
      Timecop.freeze(Time.now)
      product = FactoryGirl.create(:product, date: nil)
      expect(product.date).to eq(Time.now)
      Timecop.return
    end
	end

	describe "set_deleted" do

		before do
			@time = Time.now
			Timecop.freeze(@time)
		end

		after do
			Timecop.return
		end

		it 'sets deleted_on to current date when mark_deleted' do
			product = FactoryGirl.create(:product, external_id: 'ABC', status: 'active')
			# expect(Modules::Barbante).to receive(:delete_product).with('ABC', @time)
			product.mark_deleted
			product.reload
			expect(product.deleted_on.strftime('%F %T')).to eq(@time.utc.strftime('%F %T'))
			expect(product.status).to eq('inactive')
		end

		it 'sets deleted_on to nil when reactivating an inactive product' do
			product = FactoryGirl.create(:product, external_id: 'ABC', deleted_on: @time, status: 'inactive')
			product.update_attribute(:status, 'active')
			# expect(Modules::Barbante).to receive(:process_product).with(product)
			product.process
			product.reload
			expect(product.deleted_on).to eq(nil)
		end
		it 'sets deleted_on to current date when deactivating a product' do
			product = FactoryGirl.create(:product, external_id: 'ABC')
			# expect(Modules::Barbante).to receive(:delete_product).with('ABC', @time)
			product.update_attribute(:status, 'inactive')
			product.reload
			expect(product.deleted_on.strftime('%F %T')).to eq(@time.utc.strftime('%F %T'))
		end
	end

end