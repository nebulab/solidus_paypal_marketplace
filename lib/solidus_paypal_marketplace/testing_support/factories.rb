# frozen_string_literal: true

FactoryBot.define do
  factory :base_seller, class: 'Spree::Seller' do
    sequence(:name) { |n| "Seller ##{n}" }
    percentage { 20 }

    factory :pending_seller do
      status { :pending }
    end

    factory :seller do
      status { :accepted }
    end
  end

  factory :paypal_payment_method, class: 'SolidusPaypalMarketplace::PaymentMethod' do
    type { "SolidusPaypalMarketplace::PaymentMethod" }
    name { "PayPal Marketplace Payment Method" }
    preferences {
      {
        client_id: SecureRandom.hex(8),
        client_secret: SecureRandom.hex(10),
        partner_code: SecureRandom.hex(6),
      }
    }
  end

  factory :seller_user, parent: :user do
    transient do
      seller_role { Spree::Role.find_or_create_by!(name: 'seller') }
    end
    spree_roles { [seller_role] }
    seller factory: :seller
  end
end

FactoryBot.modify do
  factory :line_item, class: 'Spree::LineItem' do
    transient do
      seller_price do
        variant.prices.with_seller.first || create(:price, seller: create(:seller),
                                                           variant: variant)
        # TODO: understand why Insufficient stock for destroy but not for create
        #  seller_stock_availability: 10)
      end
    end
    seller do
      seller_price.seller
    end
  end
end
