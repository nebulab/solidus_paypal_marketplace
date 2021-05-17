require 'spec_helper'

RSpec.describe SolidusPaypalMarketplace::PaymentMethod, type: :model do
  let(:paypal_payment_method) { create(:paypal_payment_method) }
  let(:payment) { create(:payment) }
  let(:completed_payment) { create(:payment, :completed) }
  let(:response) { Struct(status_code: status_code, result: result, headers: headers) }
  let(:status_code) { 201 }
  let(:result) { nil }
  let(:headers) { {} }

  def Struct(data) # rubocop:disable Naming/MethodName
    Struct.new(*data.keys, keyword_init: true).new(data)
  end

  before { allow_any_instance_of(PayPal::PayPalHttpClient).to receive(:execute) { response } } # rubocop:disable RSpec/AnyInstance

  describe "#purchase" do
    let(:result) { Struct(purchase_units: [Struct(payments: payments)]) }
    let(:payments) { Struct(captures: [Struct(id: SecureRandom.hex(4))]) }

    it "sends a purchase request to paypal" do
      paypal_order_id = SecureRandom.hex(8)
      source = paypal_payment_method.payment_source_class.create(paypal_order_id: paypal_order_id)
      expect_request(:OrdersCaptureRequest).to receive(:new).with(paypal_order_id).and_call_original
      paypal_payment_method.purchase(1000, source, {})
    end
  end

  describe "#authorize" do
    let(:result) { Struct(purchase_units: [Struct(payments: payments)]) }
    let(:payments) { Struct(authorizations: [Struct(id: SecureRandom.hex(4))]) }

    it "sends an authorize request to paypal" do
      paypal_order_id = SecureRandom.hex(8)
      source = paypal_payment_method.payment_source_class.create(paypal_order_id: paypal_order_id)
      expect_request(:OrdersAuthorizeRequest).to receive(:new).with(paypal_order_id)
      paypal_payment_method.authorize(1000, source, {})
    end
  end

  describe "#capture" do
    let(:result) { Struct(id: SecureRandom.hex(4), status: 'COMPLETED') }
    let(:seller) { create(:seller) }
    let(:price) { create(:price, seller: seller) }
    let(:line_item_attributes) { { variant: price.variant, seller: price.seller } }
    let(:order) { create(:completed_order_with_pending_payment, line_items_attributes: [line_item_attributes]) }
    let(:payment) { create(:payment, order: order) }

    it "sends a capture request to paypal" do
      authorization_id = SecureRandom.hex(8)
      source = paypal_payment_method.payment_source_class.create(authorization_id: authorization_id)
      payment.source = source
      expect_request(:AuthorizationsCaptureRequest).to receive(:new).with(authorization_id).and_call_original
      paypal_payment_method.capture(1000, {}, originator: payment)
    end

    it "sets source status based on the response" do
      authorization_id = SecureRandom.hex(8)
      source = paypal_payment_method.payment_source_class.create(authorization_id: authorization_id)
      payment.source = source
      expect { paypal_payment_method.capture(1000, {}, originator: payment) }.to(
        change { source.response_status }.from(nil).to('completed')
      )
    end

    context 'with stubbed request' do
      let(:request) { instance_double(PayPalCheckoutSdk::Payments::AuthorizationsCaptureRequest, request_body: {}) }

      it 'adds the payment_information with the fee amount to the payload' do
        authorization_id = SecureRandom.hex(8)
        source = paypal_payment_method.payment_source_class.create(authorization_id: authorization_id)
        payment.source = source
        allow_request(:AuthorizationsCaptureRequest).to receive(:new).with(authorization_id).and_return(request)
        paypal_payment_method.capture(1000, {}, originator: payment)

        expect(request).to have_received(:request_body).with(hash_including(
          payment_instruction: hash_including(
            platform_fees: array_including(hash_including(
              amount: {
                currency_code: order.currency,
                value: (order.total * (seller.percentage / 100.0)).round(2)
              }
            ))
          )
        ))
      end
    end
  end

  describe "#void" do
    it "sends a void request to paypal" do
      authorization_id = SecureRandom.hex(8)
      source = paypal_payment_method.payment_source_class.create(authorization_id: authorization_id)
      payment.source = source
      payment.request_env = {}
      request = SolidusPaypalMarketplace::Gateway::AuthorizationsVoidRequest.new(authorization_id)
      expect_request(:AuthorizationsVoidRequest).to receive(:new).with(authorization_id).and_return(request)
      expect { paypal_payment_method.void(nil, originator: payment) }.to(
        change { request.headers["PayPal-Auth-Assertion"] }.from(nil)
      )
    end
  end

  describe "#credit" do
    let(:result) { Struct(id: SecureRandom.hex(4)) }

    it "sends a refund request to paypal" do
      capture_id = SecureRandom.hex(4)
      source = paypal_payment_method.payment_source_class.create(capture_id: capture_id)
      completed_payment.source = source
      expect_request(:CapturesRefundRequest).to receive(:new).with(capture_id).and_call_original
      paypal_payment_method.credit(1000, {}, originator: completed_payment.refunds.new(amount: 12))
      expect(source.refund_id).not_to be_blank
    end
  end

  describe '.javascript_sdk_url' do
    subject(:url) { URI(paypal_payment_method.javascript_sdk_url(order: order)) }

    context 'when checkout_steps include "confirm"' do
      let(:order) { instance_double(Spree::Order, checkout_steps: { "confirm" => "bar" }) }

      it 'sets autocommit' do
        expect(url.query.split("&")).to include("commit=false")
      end
    end

    context 'when checkout_steps does not include "confirm"' do
      let(:order) { instance_double(Spree::Order, checkout_steps: { "foo" => "bar" }) }

      it 'disables autocommit' do
        expect(url.query.split("&")).to include("commit=true")
      end
    end

    context 'when messaging is turned on' do
      let(:order) { instance_double(Spree::Order, checkout_steps: { "foo" => "bar" }) }

      it 'includes messaging component' do
        paypal_payment_method.preferences.update(display_credit_messaging: true)
        expect(url.query.split("&")).to include("components=buttons%2Cmessages")
      end
    end

    context 'when messaging is turned off' do
      let(:order) { instance_double(Spree::Order, checkout_steps: { "foo" => "bar" }) }

      it 'only includes buttons components' do
        paypal_payment_method.preferences.update(display_credit_messaging: false)
        expect(url.query.split("&")).not_to include("messages")
        expect(url.query.split("&")).to include("components=buttons")
      end
    end
  end

  private

  def allow_request(name)
    allow(SolidusPaypalMarketplace::Gateway.const_get(name))
  end

  def expect_request(name)
    expect(SolidusPaypalMarketplace::Gateway.const_get(name))
  end
end
