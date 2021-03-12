# frozen_string_literal: true

module Spree
  module PermissionSets
    class Seller < PermissionSets::Base
      def activate!
        can :manage, Spree::Price, seller_id: user.seller_id
      end
    end
  end
end
