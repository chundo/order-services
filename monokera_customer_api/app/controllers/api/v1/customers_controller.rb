# frozen_string_literal: true

module Api
  module V1
    class CustomersController < ApplicationController
      before_action :set_customer, only: [ :show ]

      # GET /api/v1/customers/:id
      # Returns customer details for Order Service validation
      #
      # @param id [Integer] The customer ID
      # @return [JSON] Customer details
      #
      def show
        render json: { customer: serialize_customer(@customer) }, status: :ok
      end

      private

      def set_customer
        @customer = Customer.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: I18n.t("api.errors.customer_not_found", id: params[:id]) }, status: :not_found
      end

      def serialize_customer(customer)
        {
          id: customer.id,
          customer_name: customer.customer_name,
          address: customer.address,
          orders_count: customer.orders_count
          #   TODO: Add additional fields as necessary
          #   email: customer.email,
          #   created_at: customer.created_at&.iso8601,
          #   updated_at: customer.updated_at&.iso8601
        }
      end
    end
  end
end
