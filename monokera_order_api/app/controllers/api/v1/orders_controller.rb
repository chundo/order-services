# frozen_string_literal: true

module Api
  module V1
    class OrdersController < ApplicationController
      before_action :set_order, only: [ :show ]

      # GET /api/v1/orders
      # Lists all orders with optional filtering
      #
      # @param customer_id [Integer] Optional filter by customer
      # @param status [String] Optional filter by status
      # @return [JSON] Array of orders
      #
      def index
        @orders = Order.all
        @orders = @orders.by_customer(params[:customer_id]) if params[:customer_id].present?
        @orders = @orders.by_status(params[:status]) if params[:status].present?
        @orders = @orders.recent.limit(params[:limit] || 100)

        render json: {
          orders: serialize_orders(@orders),
          meta: {
            total: @orders.count,
            filters: applied_filters
          }
        }, status: :ok
      end

      # GET /api/v1/orders/:id
      # Shows a specific order
      #
      # @param id [Integer] The order ID
      # @return [JSON] Order details
      #
      def show
        render json: { order: serialize_order(@order) }, status: :ok
      end

      # POST /api/v1/orders
      # Creates a new order after validating the customer
      #
      # @param order [Hash] Order attributes
      # @return [JSON] Created order or errors
      #
      # 1. Usuario crea orden
      def create
        result = Orders::CreateService.call(**order_params.to_h.symbolize_keys)

        if result.success?
          render json: {
            message: I18n.t("api.success.created"),
            order: serialize_order(result.order)
          }, status: :created
        else
          render json: {
            error: result.errors.first,
            details: result.errors
          }, status: error_status_for(result.error_type)
        end
      end

      private

      def set_order
        @order = Order.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: I18n.t("api.errors.not_found") }, status: :not_found
      end

      def order_params
        params.require(:order).permit(:customer_id, :product_name, :quantity, :price)
      end

      def applied_filters
        filters = {}
        filters[:customer_id] = params[:customer_id] if params[:customer_id].present?
        filters[:status] = params[:status] if params[:status].present?
        filters
      end

      def error_status_for(error_type)
        case error_type
        when Orders::CreateService::Result::CUSTOMER_SERVICE_UNAVAILABLE
          :service_unavailable
        else
          :unprocessable_entity
        end
      end

      def serialize_order(order)
        {
          id: order.id,
          customer_id: order.customer_id,
          product_name: order.product_name,
          quantity: order.quantity,
          price: order.price.to_f,
          total_amount: order.total_amount.to_f,
          status: order.status,
          status_label: I18n.t("orders.statuses.#{order.status}"),
          created_at: order.created_at&.iso8601,
          updated_at: order.updated_at&.iso8601
        }
      end

      def serialize_orders(orders)
        orders.map { |order| serialize_order(order) }
      end
    end
  end
end
