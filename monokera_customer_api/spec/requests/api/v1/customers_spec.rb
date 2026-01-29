# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Customers", type: :request do
  describe "GET /api/v1/customers/:id" do
    context "cuando el cliente existe" do
      let!(:customer) { create(:customer) }

      before { get api_v1_customer_path(customer) }

      it "retorna status 200 OK" do
        expect(response).to have_http_status(:ok)
      end

      it "retorna el cliente en formato JSON" do
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key("customer")
      end

      it "incluye el id del cliente" do
        json_response = JSON.parse(response.body)
        expect(json_response["customer"]["id"]).to eq(customer.id)
      end

      it "incluye el nombre del cliente" do
        json_response = JSON.parse(response.body)
        expect(json_response["customer"]["customer_name"]).to eq(customer.customer_name)
      end

      it "incluye la dirección del cliente" do
        json_response = JSON.parse(response.body)
        expect(json_response["customer"]["address"]).to eq(customer.address)
      end

      it "incluye el contador de órdenes" do
        json_response = JSON.parse(response.body)
        expect(json_response["customer"]["orders_count"]).to eq(customer.orders_count)
      end

      it "retorna exactamente los campos esperados" do
        json_response = JSON.parse(response.body)
        expected_keys = %w[id customer_name address orders_count]
        expect(json_response["customer"].keys).to match_array(expected_keys)
      end
    end

    context "cuando el cliente no existe" do
      let(:non_existent_id) { 999_999 }

      before { get "/api/v1/customers/#{non_existent_id}" }

      it "retorna status 404 Not Found" do
        expect(response).to have_http_status(:not_found)
      end

      it "retorna un mensaje de error" do
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key("error")
      end

      it "el mensaje de error contiene el id buscado" do
        json_response = JSON.parse(response.body)
        expect(json_response["error"]).to include(non_existent_id.to_s)
      end
    end

    context "cuando el cliente tiene órdenes" do
      let!(:customer) { create(:customer, :with_orders, orders_count: 5) }

      before { get api_v1_customer_path(customer) }

      it "retorna el contador de órdenes correcto" do
        json_response = JSON.parse(response.body)
        expect(json_response["customer"]["orders_count"]).to eq(5)
      end
    end
  end
end
