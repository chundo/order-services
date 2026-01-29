# frozen_string_literal: true

module Orders
  # Service to create a new Order
  # @example
  #   result = Orders::CreateService.call(
  #     customer_id: 123,
  #     product_name: "Widget",
  #     quantity: 2,
  #     price: 29.99
  #   )
  #
  #   if result.success?
  #     order = result.order
  #   else
  #     errors = result.errors
  #   end
  #
  class CreateService
    class Result
      attr_reader :order, :errors, :error_type

      def initialize(success:, order: nil, errors: [], error_type: nil)
        @success = success
        @order = order
        @errors = errors
        @error_type = error_type
      end

      def success?
        @success
      end

      def failure?
        !@success
      end

      # Error types
      CUSTOMER_NOT_FOUND = :customer_not_found
      CUSTOMER_SERVICE_UNAVAILABLE = :customer_service_unavailable
      VALIDATION_ERROR = :validation_error
    end

    def self.call(**params)
      new(**params).call
    end

    def initialize(customer_id: nil, product_name: nil, quantity: nil, price: nil, customer_service_client: nil, event_publisher: nil)
      @customer_id = customer_id
      @product_name = product_name
      @quantity = quantity
      @price = price
      @customer_service_client = customer_service_client || CustomerServiceClient.new
      @event_publisher = event_publisher || EventPublisher.new
    end

    # 2. Usuario crea orden
    def call
      # Step 1: Validate customer exists
      customer_validation = validate_customer
      return customer_validation if customer_validation.failure?

      # Step 2: Create the order
      order = build_order
      return validation_error(order.errors.full_messages) unless order.save

      # Step 3: Publish event (non-blocking)
      publish_order_created(order)

      # Step 4: Return success
      success(order)
    end

    private

    attr_reader :customer_id, :product_name, :quantity, :price,
                :customer_service_client, :event_publisher

    def validate_customer
      return customer_not_found if customer_id.blank?

      if customer_service_client.customer_exists?(customer_id)
        Result.new(success: true)
      else
        customer_not_found
      end
    rescue CustomerServiceClient::ConnectionError, CustomerServiceClient::TimeoutError => e
      Rails.logger.error("[Orders::CreateService] Customer Service unavailable: #{e.message}")
      customer_service_unavailable
    rescue CustomerServiceClient::Error => e
      Rails.logger.error("[Orders::CreateService] Customer validation failed: #{e.message}")
      customer_not_found
    end

    def build_order
      Order.new(
        customer_id: customer_id,
        product_name: product_name,
        quantity: quantity,
        price: price
      )
    end

    def publish_order_created(order)
      event_publisher.publish_order_created(order)
    rescue EventPublisher::Error => e
      # Log but don't fail - event can be replayed later
      Rails.logger.error("[Orders::CreateService] Failed to publish order.created: #{e.message}")
    end

    # Result builders
    def success(order)
      Result.new(success: true, order: order)
    end

    def customer_not_found
      Result.new(
        success: false,
        errors: [ I18n.t("api.errors.customer_not_found", id: customer_id) ],
        error_type: Result::CUSTOMER_NOT_FOUND
      )
    end

    def customer_service_unavailable
      Result.new(
        success: false,
        errors: [ I18n.t("api.errors.customer_service_unavailable") ],
        error_type: Result::CUSTOMER_SERVICE_UNAVAILABLE
      )
    end

    def validation_error(errors)
      Result.new(
        success: false,
        errors: errors,
        error_type: Result::VALIDATION_ERROR
      )
    end
  end
end
