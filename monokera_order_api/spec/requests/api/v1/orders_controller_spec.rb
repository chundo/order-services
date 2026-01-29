# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V1::OrdersController, type: :request do
  let(:customer_id) { 123 }
  let(:customer_service_client) { instance_double(CustomerServiceClient) }
  let(:event_publisher) { instance_double(EventPublisher) }

  before do
    allow(CustomerServiceClient).to receive(:new).and_return(customer_service_client)
    allow(EventPublisher).to receive(:new).and_return(event_publisher)
    allow(event_publisher).to receive(:publish_order_created).and_return(true)
  end

  describe "GET /api/v1/orders" do
    let!(:orders) { create_list(:order, 3, customer_id: customer_id) }
    let!(:other_orders) { create_list(:order, 2, customer_id: 456) }

    it "returns all orders" do
      get "/api/v1/orders"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["orders"].length).to eq(5)
    end

    it "returns orders with meta information" do
      get "/api/v1/orders"

      json = JSON.parse(response.body)
      expect(json["meta"]).to include("total", "filters")
    end

    context "when filtering by customer_id" do
      it "returns only orders for that customer" do
        get "/api/v1/orders", params: { customer_id: customer_id }

        json = JSON.parse(response.body)
        expect(json["orders"].length).to eq(3)
        expect(json["orders"].all? { |o| o["customer_id"] == customer_id }).to be true
      end

      it "includes the filter in meta" do
        get "/api/v1/orders", params: { customer_id: customer_id }

        json = JSON.parse(response.body)
        expect(json["meta"]["filters"]["customer_id"]).to eq(customer_id.to_s)
      end
    end

    context "when filtering by status" do
      let!(:processing_orders) { create_list(:order, 2, :processing) }

      it "returns only orders with that status" do
        get "/api/v1/orders", params: { status: "processing" }

        json = JSON.parse(response.body)
        expect(json["orders"].all? { |o| o["status"] == "processing" }).to be true
      end
    end

    context "when limiting results" do
      it "respects the limit parameter" do
        get "/api/v1/orders", params: { limit: 2 }

        json = JSON.parse(response.body)
        expect(json["orders"].length).to eq(2)
      end
    end
  end

  describe "GET /api/v1/orders/:id" do
    let(:order) { create(:order) }

    it "returns the order" do
      get "/api/v1/orders/#{order.id}"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["order"]["id"]).to eq(order.id)
    end

    it "includes all order attributes" do
      get "/api/v1/orders/#{order.id}"

      json = JSON.parse(response.body)["order"]
      expect(json).to include(
        "id", "customer_id", "product_name", "quantity",
        "price", "total_amount", "status", "status_label",
        "created_at", "updated_at"
      )
    end

    it "includes translated status label" do
      get "/api/v1/orders/#{order.id}"

      json = JSON.parse(response.body)["order"]
      expect(json["status_label"]).to eq(I18n.t("orders.statuses.#{order.status}"))
    end

    context "when order does not exist" do
      it "returns not found" do
        get "/api/v1/orders/999999"

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq(I18n.t("api.errors.not_found"))
      end
    end
  end

  describe "POST /api/v1/orders" do
    let(:valid_params) do
      {
        order: {
          customer_id: customer_id,
          product_name: "Test Product",
          quantity: 2,
          price: 29.99
        }
      }
    end

    context "when customer exists" do
      before do
        allow(customer_service_client).to receive(:customer_exists?).and_return(true)
      end

      it "creates an order" do
        expect {
          post "/api/v1/orders", params: valid_params
        }.to change(Order, :count).by(1)
      end

      it "returns created status" do
        post "/api/v1/orders", params: valid_params

        expect(response).to have_http_status(:created)
      end

      it "returns the created order" do
        post "/api/v1/orders", params: valid_params

        json = JSON.parse(response.body)
        expect(json["order"]["product_name"]).to eq("Test Product")
        expect(json["order"]["quantity"]).to eq(2)
        expect(json["order"]["price"]).to eq(29.99)
      end

      it "returns success message" do
        post "/api/v1/orders", params: valid_params

        json = JSON.parse(response.body)
        expect(json["message"]).to eq(I18n.t("api.success.created"))
      end

      it "publishes order created event" do
        expect(event_publisher).to receive(:publish_order_created)

        post "/api/v1/orders", params: valid_params
      end

      it "sets default status as pending" do
        post "/api/v1/orders", params: valid_params

        json = JSON.parse(response.body)
        expect(json["order"]["status"]).to eq("pending")
      end
    end

    context "when customer does not exist" do
      before do
        allow(customer_service_client).to receive(:customer_exists?).and_return(false)
      end

      it "does not create an order" do
        expect {
          post "/api/v1/orders", params: valid_params
        }.not_to change(Order, :count)
      end

      it "returns unprocessable entity" do
        post "/api/v1/orders", params: valid_params

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns customer not found error" do
        post "/api/v1/orders", params: valid_params

        json = JSON.parse(response.body)
        expect(json["error"]).to eq(I18n.t("api.errors.customer_not_found", id: customer_id))
      end
    end

    context "when customer service is unavailable" do
      before do
        allow(customer_service_client).to receive(:customer_exists?)
          .and_raise(CustomerServiceClient::ConnectionError.new("Connection refused"))
      end

      it "does not create an order" do
        expect {
          post "/api/v1/orders", params: valid_params
        }.not_to change(Order, :count)
      end

      it "returns service unavailable" do
        post "/api/v1/orders", params: valid_params

        expect(response).to have_http_status(:service_unavailable)
      end

      it "returns error message" do
        post "/api/v1/orders", params: valid_params

        json = JSON.parse(response.body)
        expect(json["error"]).to eq(I18n.t("api.errors.customer_service_unavailable"))
      end
    end

    context "when order params are invalid" do
      before do
        allow(customer_service_client).to receive(:customer_exists?).and_return(true)
      end

      it "returns unprocessable entity for missing product_name" do
        post "/api/v1/orders", params: { order: { customer_id: customer_id, quantity: 1, price: 10 } }

        expect(response).to have_http_status(:unprocessable_entity)
        json = JSON.parse(response.body)
        expect(json["details"]).to be_present
      end

      it "returns unprocessable entity for invalid quantity" do
        post "/api/v1/orders", params: {
          order: { customer_id: customer_id, product_name: "Test", quantity: 0, price: 10 }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns unprocessable entity for negative price" do
        post "/api/v1/orders", params: {
          order: { customer_id: customer_id, product_name: "Test", quantity: 1, price: -10 }
        }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when event publishing fails" do
      before do
        allow(customer_service_client).to receive(:customer_exists?).and_return(true)
        allow(event_publisher).to receive(:publish_order_created)
          .and_raise(EventPublisher::ConnectionError.new("RabbitMQ unavailable"))
      end

      it "still creates the order" do
        expect {
          post "/api/v1/orders", params: valid_params
        }.to change(Order, :count).by(1)
      end

      it "returns created status" do
        post "/api/v1/orders", params: valid_params

        expect(response).to have_http_status(:created)
      end
    end
  end

  describe "with locale parameter" do
    let(:order) { create(:order) }

    it "respects locale parameter for translations" do
      get "/api/v1/orders/#{order.id}", params: { locale: :en }

      json = JSON.parse(response.body)["order"]
      expect(json["status_label"]).to eq("Pending")
    end

    it "uses Spanish translations by default" do
      get "/api/v1/orders/#{order.id}"

      json = JSON.parse(response.body)["order"]
      expect(json["status_label"]).to eq("Pendiente")
    end
  end
end
