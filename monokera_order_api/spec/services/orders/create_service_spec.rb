# frozen_string_literal: true

require "rails_helper"

RSpec.describe Orders::CreateService do
  let(:customer_id) { 123 }
  let(:valid_params) do
    {
      customer_id: customer_id,
      product_name: "Test Product",
      quantity: 2,
      price: 29.99
    }
  end

  let(:customer_service_client) { instance_double(CustomerServiceClient) }
  let(:event_publisher) { instance_double(EventPublisher) }

  subject(:service) do
    described_class.new(
      **valid_params,
      customer_service_client: customer_service_client,
      event_publisher: event_publisher
    )
  end

  before do
    allow(event_publisher).to receive(:publish_order_created).and_return(true)
  end

  describe ".call" do
    it "creates an instance and calls the service" do
      allow(customer_service_client).to receive(:customer_exists?).and_return(true)

      result = described_class.call(
        **valid_params,
        customer_service_client: customer_service_client,
        event_publisher: event_publisher
      )

      expect(result).to be_success
    end
  end

  describe "#call" do
    context "when customer exists and order is valid" do
      before do
        allow(customer_service_client).to receive(:customer_exists?).and_return(true)
      end

      it "returns a successful result" do
        result = service.call
        expect(result).to be_success
      end

      it "creates an order" do
        expect { service.call }.to change(Order, :count).by(1)
      end

      it "returns the created order" do
        result = service.call
        expect(result.order).to be_a(Order)
        expect(result.order).to be_persisted
      end

      it "sets the correct order attributes" do
        result = service.call
        order = result.order

        expect(order.customer_id).to eq(customer_id)
        expect(order.product_name).to eq("Test Product")
        expect(order.quantity).to eq(2)
        expect(order.price).to eq(29.99)
        expect(order.status).to eq("pending")
      end

      it "publishes order created event" do
        expect(event_publisher).to receive(:publish_order_created)
        service.call
      end

      it "has no errors" do
        result = service.call
        expect(result.errors).to be_empty
      end
    end

    context "when customer does not exist" do
      before do
        allow(customer_service_client).to receive(:customer_exists?).and_return(false)
      end

      it "returns a failure result" do
        result = service.call
        expect(result).to be_failure
      end

      it "does not create an order" do
        expect { service.call }.not_to change(Order, :count)
      end

      it "returns customer_not_found error type" do
        result = service.call
        expect(result.error_type).to eq(Orders::CreateService::Result::CUSTOMER_NOT_FOUND)
      end

      it "includes error message" do
        result = service.call
        expect(result.errors).to include(I18n.t("api.errors.customer_not_found", id: customer_id))
      end

      it "does not publish event" do
        expect(event_publisher).not_to receive(:publish_order_created)
        service.call
      end
    end

    context "when customer_id is blank" do
      let(:valid_params) do
        {
          customer_id: nil,
          product_name: "Test Product",
          quantity: 2,
          price: 29.99
        }
      end

      it "returns a failure result" do
        result = service.call
        expect(result).to be_failure
      end

      it "returns customer_not_found error type" do
        result = service.call
        expect(result.error_type).to eq(Orders::CreateService::Result::CUSTOMER_NOT_FOUND)
      end
    end

    context "when customer service is unavailable" do
      before do
        allow(customer_service_client).to receive(:customer_exists?)
          .and_raise(CustomerServiceClient::ConnectionError.new("Connection refused"))
      end

      it "returns a failure result" do
        result = service.call
        expect(result).to be_failure
      end

      it "does not create an order" do
        expect { service.call }.not_to change(Order, :count)
      end

      it "returns customer_service_unavailable error type" do
        result = service.call
        expect(result.error_type).to eq(Orders::CreateService::Result::CUSTOMER_SERVICE_UNAVAILABLE)
      end

      it "includes service unavailable error message" do
        result = service.call
        expect(result.errors).to include(I18n.t("api.errors.customer_service_unavailable"))
      end
    end

    context "when customer service times out" do
      before do
        allow(customer_service_client).to receive(:customer_exists?)
          .and_raise(CustomerServiceClient::TimeoutError.new("Request timed out"))
      end

      it "returns customer_service_unavailable error type" do
        result = service.call
        expect(result.error_type).to eq(Orders::CreateService::Result::CUSTOMER_SERVICE_UNAVAILABLE)
      end
    end

    context "when order validation fails" do
      before do
        allow(customer_service_client).to receive(:customer_exists?).and_return(true)
      end

      let(:valid_params) do
        {
          customer_id: customer_id,
          product_name: "",  # Invalid: blank
          quantity: 2,
          price: 29.99
        }
      end

      it "returns a failure result" do
        result = service.call
        expect(result).to be_failure
      end

      it "does not create an order" do
        expect { service.call }.not_to change(Order, :count)
      end

      it "returns validation_error error type" do
        result = service.call
        expect(result.error_type).to eq(Orders::CreateService::Result::VALIDATION_ERROR)
      end

      it "includes validation error messages" do
        result = service.call
        expect(result.errors).not_to be_empty
      end

      it "does not publish event" do
        expect(event_publisher).not_to receive(:publish_order_created)
        service.call
      end
    end

    context "when event publishing fails" do
      before do
        allow(customer_service_client).to receive(:customer_exists?).and_return(true)
        allow(event_publisher).to receive(:publish_order_created)
          .and_raise(EventPublisher::ConnectionError.new("RabbitMQ unavailable"))
      end

      it "still returns success" do
        result = service.call
        expect(result).to be_success
      end

      it "creates the order" do
        expect { service.call }.to change(Order, :count).by(1)
      end

      it "logs the error" do
        expect(Rails.logger).to receive(:error).with(/Failed to publish/)
        service.call
      end
    end
  end

  describe "Result" do
    describe "#success?" do
      it "returns true for successful results" do
        result = Orders::CreateService::Result.new(success: true)
        expect(result.success?).to be true
      end

      it "returns false for failed results" do
        result = Orders::CreateService::Result.new(success: false)
        expect(result.success?).to be false
      end
    end

    describe "#failure?" do
      it "returns false for successful results" do
        result = Orders::CreateService::Result.new(success: true)
        expect(result.failure?).to be false
      end

      it "returns true for failed results" do
        result = Orders::CreateService::Result.new(success: false)
        expect(result.failure?).to be true
      end
    end

    describe "error types" do
      it "defines CUSTOMER_NOT_FOUND" do
        expect(Orders::CreateService::Result::CUSTOMER_NOT_FOUND).to eq(:customer_not_found)
      end

      it "defines CUSTOMER_SERVICE_UNAVAILABLE" do
        expect(Orders::CreateService::Result::CUSTOMER_SERVICE_UNAVAILABLE).to eq(:customer_service_unavailable)
      end

      it "defines VALIDATION_ERROR" do
        expect(Orders::CreateService::Result::VALIDATION_ERROR).to eq(:validation_error)
      end
    end
  end
end
