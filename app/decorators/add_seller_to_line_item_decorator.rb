# frozen_string_literal: true

module AddSellerToLineItemDecorator
  def self.prepended(base)
    base.belongs_to :seller, class_name: 'Spree::Seller'
    base.validate :validate_seller_price_presence, if: -> { seller.present? && variant.present? }
  end

  def pricing_options
    Spree::Variant::SellersPricingOptions.from_line_item(self)
  end

  def sufficient_stock?
    Spree::Stock::Quantifier.new(variant, seller.stock_location).can_supply? quantity
  end

  private

  def validate_seller_price_presence
    errors.add(:seller, :no_prices) if variant.price_for_seller(seller, pricing_options).nil?
  end

  Spree::LineItem.prepend self
end
