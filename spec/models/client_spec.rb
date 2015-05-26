require 'rails_helper'

describe Client do

    let(:feed_time) {Time.local(2014, 1, 24, 12, 0, 0)}

	describe 'validations' do
	   let(:client) { FactoryGirl.create(:client) }

        it 'fails validation with no name' do
          client = Client.new()
          client.valid?
          expect(client.errors).to include(:name)
          expect(client.errors).to include(:domain_name)
          expect(client.errors).to include(:status)
        end

	end

    describe "prepare to download feed" do

        before do
            @body = File.open(File.dirname(__FILE__) + '/../support/fixtures/goodnoows.json').read

            stub_request(:get, "http://goodnoows.local/api/v1.0/?a=getrecentarticles&aid=176687414").
                 with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'goodnoows.local', 'User-Agent'=>'Ruby'}).
                 to_return(
                  :status => 200, 
                  :body => @body, 
                  :headers => {'content-type'=>'application/json'}
                  )

            stub_request(:get, "http://goodnoows.local/api/v1.0/?a=getrecentarticles&aid=176687414B").
                 with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'goodnoows.local', 'User-Agent'=>'Ruby'}).
                 to_return(:status => 302, :headers => {'content-type'=>'application/json', 'Location' => 'http://goodnoows.local/api/v1.0/?a=getrecentarticles&aid=176687414'})

            stub_request(:get, "http://bad.url.here").
                 with(:headers => {'Accept'=>'*/*', 'Accept-Encoding'=>'gzip;q=1.0,deflate;q=0.6,identity;q=0.3', 'Host'=>'bad.url.here', 'User-Agent'=>'Ruby'}).
                 to_return(:status => 404, :headers => {'content-type'=>'application/json'})
        end

        let(:client) { FactoryGirl.create(:client) }

        it "gets feed" do
            json_str = client.get_feed "http://goodnoows.local/api/v1.0/?a=getrecentarticles&aid=176687414"
            expect(json_str).to eq(@body)
        end

        it "redirects until gets feed correctly" do
            json_str = client.get_feed "http://goodnoows.local/api/v1.0/?a=getrecentarticles&aid=176687414B"
            expect(json_str).to eq(@body)
        end

        it "returns nil for bad url" do
            json_str = client.get_feed "http://bad.url.here"
            expect(json_str).to eq(nil)
        end

        it "parse json" do
            json_str = client.get_feed "http://goodnoows.local/api/v1.0/?a=getrecentarticles&aid=176687414"
            json = client.parse_feed json_str
            expect(json["success"]).to eq true
            expect(json["articles"]).to be_a(Array)
        end

        it "gets last product id imported" do
            FactoryGirl.create(:product, external_id: "1")
            expect(client.last_product).to eq("1")
        end

        it "builds feed url" do
            FactoryGirl.create(:product)
            expect(client.get_feed_url).to eq ("http://goodnoows.local/api/v1.0/?a=getrecentarticles&aid=176687414")
        end

        it "fails to build feed url because it is not configured" do
            fail_client = FactoryGirl.create(:client, feed_url: nil) 
            FactoryGirl.create(:product)
            expect(fail_client.get_feed_url).to eq (nil)
        end

    end

end

