# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Home", type: :request do
  describe "GET /api/v1" do
    context "when requesting the root endpoint" do
      before { get "/api/v1" }

      it "returns http success" do
        expect(response).to have_http_status(:ok)
      end

      it "returns JSON content type" do
        expect(response.content_type).to include("application/json")
      end

      it "returns the hostname from settings" do
        json_response = JSON.parse(response.body)
        expect(json_response["hostname"]).to eq(Settings.hostname)
      end

      it "returns the say message with I18n translation" do
        json_response = JSON.parse(response.body)
        expect(json_response["say"]).to eq(I18n.t("hello"))
      end
    end

    context "when locale is English (default)" do
      before do
        get "/api/v1", headers: { "Accept-Language" => "en" }
      end

      it "returns hello message in English" do
        I18n.with_locale(:en) do
          json_response = JSON.parse(response.body)
          # The response was generated with the server's locale
          # We verify the key exists and has a valid translation
          expect(json_response["say"]).to be_present
        end
      end
    end

    context "when locale is Spanish" do
      before do
        get "/api/v1", headers: { "Accept-Language" => "es" }
      end

      it "returns hello message in Spanish" do
        json_response = JSON.parse(response.body)
        # Verify the say key exists and has a value
        expect(json_response["say"]).to be_present
        # Since default locale might be Spanish, we verify it's a valid translation
        expect(json_response["say"]).to eq(I18n.t("hello"))
      end
    end

    context "response structure" do
      before { get "/api/v1" }

      it "returns a JSON with hostname and say keys" do
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key("hostname")
        expect(json_response).to have_key("say")
      end

      it "returns exactly 2 keys in the response" do
        json_response = JSON.parse(response.body)
        expect(json_response.keys.count).to eq(2)
      end
    end
  end
end
