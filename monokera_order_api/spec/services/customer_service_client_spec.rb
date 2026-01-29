# frozen_string_literal: true

require "rails_helper"

RSpec.describe CustomerServiceClient do
  let(:base_url) { "http://localhost:3001" }
  let(:client) { described_class.new(base_url: base_url, timeout: 5, open_timeout: 2) }
  let(:customer_id) { 123 }

  let(:customer_data) do
    {
      id: customer_id,
      name: "John Doe",
      email: "john@example.com",
      phone: "+1234567890"
    }
  end

  describe "#find_customer" do
    context "when customer exists" do
      before do
        stub_request(:get, "#{base_url}/api/v1/customers/#{customer_id}")
          .to_return(
            status: 200,
            body: customer_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns success with customer data" do
        result = client.find_customer(customer_id)

        expect(result[:success]).to be true
        expect(result[:customer]).to include(
          id: customer_id,
          name: "John Doe",
          email: "john@example.com"
        )
      end
    end

    context "when customer does not exist" do
      before do
        stub_request(:get, "#{base_url}/api/v1/customers/#{customer_id}")
          .to_return(
            status: 404,
            body: { error: "Customer not found" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns failure with error message" do
        result = client.find_customer(customer_id)

        expect(result[:success]).to be false
        expect(result[:error]).to eq(I18n.t("services.customer_service_client.errors.not_found"))
        expect(result[:status]).to eq(404)
      end
    end

    context "when customer service returns server error" do
      before do
        stub_request(:get, "#{base_url}/api/v1/customers/#{customer_id}")
          .to_return(status: 500, body: "", headers: {})
      end

      it "returns failure with server error message" do
        result = client.find_customer(customer_id)

        expect(result[:success]).to be false
        expect(result[:error]).to eq(I18n.t("services.customer_service_client.errors.server_error"))
        expect(result[:status]).to eq(500)
      end
    end

    context "when connection fails" do
      before do
        stub_request(:get, "#{base_url}/api/v1/customers/#{customer_id}")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "raises ConnectionError" do
        expect { client.find_customer(customer_id) }
          .to raise_error(CustomerServiceClient::ConnectionError, /No se pudo conectar/)
      end
    end

    context "when request times out" do
      before do
        stub_request(:get, "#{base_url}/api/v1/customers/#{customer_id}")
          .to_raise(Faraday::TimeoutError.new("execution expired"))
      end

      it "raises TimeoutError" do
        expect { client.find_customer(customer_id) }
          .to raise_error(CustomerServiceClient::TimeoutError, /expiró/)
      end
    end

    context "when response has client error" do
      before do
        stub_request(:get, "#{base_url}/api/v1/customers/#{customer_id}")
          .to_return(
            status: 400,
            body: { error: "Invalid customer ID" }.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns failure with the error message from response" do
        result = client.find_customer(customer_id)

        expect(result[:success]).to be false
        expect(result[:error]).to eq("Invalid customer ID")
        expect(result[:status]).to eq(400)
      end
    end
  end

  describe "#customer_exists?" do
    context "when customer exists" do
      before do
        stub_request(:get, "#{base_url}/api/v1/customers/#{customer_id}")
          .to_return(
            status: 200,
            body: customer_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns true" do
        expect(client.customer_exists?(customer_id)).to be true
      end
    end

    context "when customer does not exist" do
      before do
        stub_request(:get, "#{base_url}/api/v1/customers/#{customer_id}")
          .to_return(status: 404, body: "", headers: {})
      end

      it "returns false" do
        expect(client.customer_exists?(customer_id)).to be false
      end
    end

    context "when connection fails" do
      before do
        stub_request(:get, "#{base_url}/api/v1/customers/#{customer_id}")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "returns false" do
        expect(client.customer_exists?(customer_id)).to be false
      end
    end

    context "when request times out" do
      before do
        stub_request(:get, "#{base_url}/api/v1/customers/#{customer_id}")
          .to_raise(Faraday::TimeoutError.new("execution expired"))
      end

      it "returns false" do
        expect(client.customer_exists?(customer_id)).to be false
      end
    end
  end

  describe "#validate_customer" do
    context "when customer is valid" do
      before do
        stub_request(:get, "#{base_url}/api/v1/customers/#{customer_id}")
          .to_return(
            status: 200,
            body: customer_data.to_json,
            headers: { "Content-Type" => "application/json" }
          )
      end

      it "returns the customer data" do
        result = client.validate_customer(customer_id)

        expect(result).to include(
          id: customer_id,
          name: "John Doe"
        )
      end
    end

    context "when customer is not found" do
      before do
        stub_request(:get, "#{base_url}/api/v1/customers/#{customer_id}")
          .to_return(status: 404, body: "", headers: {})
      end

      it "returns nil" do
        expect(client.validate_customer(customer_id)).to be_nil
      end
    end

    context "when connection fails" do
      before do
        stub_request(:get, "#{base_url}/api/v1/customers/#{customer_id}")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))
      end

      it "raises ConnectionError" do
        expect { client.validate_customer(customer_id) }
          .to raise_error(CustomerServiceClient::ConnectionError)
      end
    end
  end

  describe "initialization" do
    it "uses default values from Settings when not provided and ENV not set" do
      # Ensure CUSTOMER_SERVICE_URL is not set
      allow(ENV).to receive(:fetch).with("CUSTOMER_SERVICE_URL").and_yield
      allow(Settings.services.customer_service).to receive(:base_url).and_return("http://default:3001")
      allow(Settings.services.customer_service).to receive(:timeout).and_return(10)
      allow(Settings.services.customer_service).to receive(:open_timeout).and_return(3)

      client = described_class.new

      expect(client.instance_variable_get(:@base_url)).to eq("http://default:3001")
      expect(client.instance_variable_get(:@timeout)).to eq(10)
      expect(client.instance_variable_get(:@open_timeout)).to eq(3)
    end

    it "uses CUSTOMER_SERVICE_URL env variable when set" do
      allow(ENV).to receive(:fetch).with("CUSTOMER_SERVICE_URL").and_return("http://docker-service:3001")
      allow(Settings.services.customer_service).to receive(:timeout).and_return(10)
      allow(Settings.services.customer_service).to receive(:open_timeout).and_return(3)

      client = described_class.new

      expect(client.instance_variable_get(:@base_url)).to eq("http://docker-service:3001")
    end

    it "accepts custom values" do
      client = described_class.new(
        base_url: "http://custom:4000",
        timeout: 15,
        open_timeout: 5
      )

      expect(client.instance_variable_get(:@base_url)).to eq("http://custom:4000")
      expect(client.instance_variable_get(:@timeout)).to eq(15)
      expect(client.instance_variable_get(:@open_timeout)).to eq(5)
    end
  end
end
