require 'rails_helper'

describe Modules do
  describe 'PeixeApiClient' do
    let(:client){ Modules::PeixeApiClient.new }
    describe 'add_to_products' do
      it 'adds new product to products' do
        client.add_to_products({'deal_id' => 'a1', 'title' => 'test1'}, {'page' => 'category 1'})
        expect(client.products).to have_key('a1')
      end

      it 'doesnt add same product multiple times when coming from different pages' do
        client.add_to_products({'deal_id' => 'a1', 'title' => 'test1'}, {'page' => 'category 1'})
        client.add_to_products({'deal_id' => 'a1', 'title' => 'test1'}, {'page' => 'category 2'})
        expect(client.products).to have_key('a1')
        expect(client.products['a1']['pages'].count).to eq(2)
      end
    end
  end
end