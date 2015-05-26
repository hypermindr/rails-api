require 'rails_helper'

describe BarbanteActivityFastlaneWorker do

  let(:client) {FactoryGirl.create(:client)}
  let(:user) {User.create(external_id: '1', ip: '8.8.8.8')}

  describe "perform" do

    it "should not raise error" do
      worker = BarbanteActivityFastlaneWorker.new
      expect{worker.perform user.external_id, '123', 'read', Time.new.utc.strftime("%FT%T.%3NZ"), 0}.to_not raise_error
    end

    it "should not raise error on browse activities" do
      worker = BarbanteActivityFastlaneWorker.new
      expect{worker.perform user.external_id, '123', 'browse', Time.new.utc.strftime("%FT%T.%3NZ"), 0}.to_not raise_error
    end

    it "should raise error" do
      worker = BarbanteActivityFastlaneWorker.new
      expect{worker.perform user.external_id, '1234', 'read', 'BAD DATE', 0}.to raise_error
    end

  end
end