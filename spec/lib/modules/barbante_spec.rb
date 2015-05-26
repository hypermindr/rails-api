require 'rails_helper'

describe Modules do
  describe 'Barbante' do

    it 'consolidates product templates' do
      expect(Modules::Barbante.consolidate_product_templates).to eq(true)
    end

  end

end
