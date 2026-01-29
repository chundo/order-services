# frozen_string_literal: true

module Api
  module V1
    class HomeController < ApplicationController
      def index
        render json: {
          hostname: Settings.hostname,
          say:  I18n.t("hello")
        }, status: :ok
      end
    end
  end
end
