# frozen_string_literal: true

module Spree
  module Admin
    module Sellers
      class LineItemsController < Spree::Admin::Sellers::ResourceController
        def update
          @shipment = Spree::Shipment.find_by(number: params[:shipment_id])
          authorize! :manage, @shipment
          @line_item.update(quantity: permitted_resource_params[:quantity])
          redirect_to spree.edit_admin_sellers_shipment_path(@shipment)
        end
      end
    end
  end
end
