# frozen_string_literal: true

require 'spec_helper'
require 'cancan/matchers'

RSpec.describe Spree::PermissionSets::SellerResources do
  subject(:ability) { Spree::Ability.new(user) }

  let(:line_item) { create(:line_item) }
  let(:order) { line_item.order }

  before do
    line_item.order.update!(completed_at: Time.zone.now)
    line_item.order.update!(state: 'complete')
  end

  context 'when is a seller' do
    let(:seller) { line_item.seller }
    let(:user){ create(:seller_user, seller: seller ) }

    it 'cannot manage other seller\'s line_item' do
      line_item.destroy!
      new_line_item = create(:line_item)
      expect(new_line_item.seller).not_to eq(seller)
      expect(ability).not_to be_able_to([:create, :update, :destroy], new_line_item)
    end

    it 'can manage his line_item' do
      expect(ability).to be_able_to([:create, :update, :destroy], line_item)
    end

    context 'when order is not completed' do
      it 'cannot manage its line_item' do
        line_item.order.update_column(:state, 'cancelled') # rubocop:disable Rails/SkipsModelValidations
        expect(ability).not_to be_able_to([:create, :update, :destroy], line_item)
      end
    end

    context 'when is rejected' do
      it 'cannot manage his line_item' do
        seller.update!(status: :rejected)
        expect(ability).not_to be_able_to([:create, :update, :destroy], line_item)
      end
    end
  end
end
