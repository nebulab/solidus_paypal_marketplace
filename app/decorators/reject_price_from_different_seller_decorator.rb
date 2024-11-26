# frozen_string_literal: true

module RejectPriceFromDifferentSellerDecorator
  def self.prepended(base)
    base.validate :reject_price_from_different_seller, if: -> { order.present? }
  end

  def reject_price_from_different_seller
    return if order.line_items.pluck(:seller_id).all?(seller_id)

    errors.add(:seller, :cannot_add_line_item_from_different_seller)
  end

  Spree::LineItem.prepend self
end
