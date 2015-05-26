require 'rails_helper'

describe ProductWorker do

	describe "perform" do

		it "downloads product content if not available" do
			product = FactoryGirl.create(:product, full_content: nil, url: 'http://goodnoows.com/a/189824201/', language: nil)
			# original_body = product.full_content
			body = "\n\n\nLifehacker\n\nQuick Control Panel Adds a Customizable Control Center to Android\n\nAndroid: Control Center is one of the better new additions in iOS 7. If you want something like that on your Android device, Quick Control Panel does it for free and lets you customize it to your liking.\nLike iOS' Control Center, you will need to swipe upwards from the bottom edge of the phone to activate the app. The panel has a space for app shortcuts, music playback controls (along with \"now playing\"), toggles for different...\n\n"
			worker = ProductWorker.new
			expect{worker.perform(product.id.to_s)}.to_not raise_error
			product.reload
			expect(product.full_content).to eq(body)
			expect(product.language).to eq("english")
			# expect(result["success"]).to eq(true)
		end

	end
end