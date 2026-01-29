# frozen_string_literal: true

# HTTP client for communicating with the Customer Service microservice.
# Handles customer validation requests before creating orders.
#
# @example
#   client = CustomerServiceClient.new
#   result = client.find_customer(123)
#   if result[:success]
#     customer = result[:customer]
#   else
#     error = result[:error]
#   end
#
class CustomerServiceClient
  class Error < StandardError; end
  class ConnectionError < Error; end
  class TimeoutError < Error; end
  class NotFoundError < Error; end
  class ServerError < Error; end

  def initialize(base_url: nil, timeout: nil, open_timeout: nil)
    # Use CUSTOMER_SERVICE_URL env variable if available (Docker), otherwise use Settings
    @base_url = base_url || ENV.fetch("CUSTOMER_SERVICE_URL") { Settings.services.customer_service.base_url }
    @timeout = timeout || Settings.services.customer_service.timeout
    @open_timeout = open_timeout || Settings.services.customer_service.open_timeout
  end

  # Finds a customer by ID from the Customer Service
  #
  # @param customer_id [Integer] The ID of the customer to find
  # @return [Hash] Result hash with :success, :customer or :error keys
  #
  # @example Success response
  #   { success: true, customer: { id: 1, name: "John Doe", email: "john@example.com" } }
  #
  # @example Error response
  #   { success: false, error: "Customer not found", status: 404 }
  #
  def find_customer(customer_id)
    response = connection.get("/api/v1/customers/#{customer_id}")

    if response.success?
      { success: true, customer: parse_response(response) }
    else
      handle_error_response(response)
    end
  rescue Faraday::ConnectionFailed => e
    raise ConnectionError, I18n.t("services.customer_service_client.errors.connection_failed", message: e.message)
  rescue Faraday::TimeoutError => e
    raise TimeoutError, I18n.t("services.customer_service_client.errors.timeout", message: e.message)
  end

  # Checks if a customer exists in the Customer Service
  #
  # @param customer_id [Integer] The ID of the customer to check
  # @return [Boolean] true if customer exists, false otherwise
  #
  def customer_exists?(customer_id)
    result = find_customer(customer_id)
    result[:success]
  rescue Error
    false
  end

  # Validates a customer and returns the customer data if valid
  #
  # @param customer_id [Integer] The ID of the customer to validate
  # @return [Hash, nil] Customer data if valid, nil otherwise
  # @raise [ConnectionError] if unable to connect to Customer Service
  # @raise [TimeoutError] if request times out
  #
  def validate_customer(customer_id)
    result = find_customer(customer_id)
    return result[:customer] if result[:success]

    nil
  end

  private

  def connection
    @connection ||= Faraday.new(url: @base_url) do |faraday|
      faraday.request :json
      faraday.response :json, content_type: /\bjson$/
      faraday.options.timeout = @timeout
      faraday.options.open_timeout = @open_timeout

      # Retry configuration for transient failures
      faraday.request :retry, {
        max: 2,
        interval: 0.5,
        interval_randomness: 0.5,
        backoff_factor: 2,
        retry_statuses: [ 503, 504 ],
        exceptions: [
          Faraday::ConnectionFailed,
          Faraday::TimeoutError
        ]
      }

      faraday.adapter Faraday.default_adapter
    end
  end

  def parse_response(response)
    body = response.body

    case body
    when Hash
      symbolize_keys(body)
    when String
      JSON.parse(body, symbolize_names: true)
    else
      { raw: body }
    end
  rescue JSON::ParserError
    { raw: body }
  end

  def symbolize_keys(hash)
    hash.transform_keys(&:to_sym).transform_values do |value|
      case value
      when Hash
        symbolize_keys(value)
      when Array
        value.map { |v| v.is_a?(Hash) ? symbolize_keys(v) : v }
      else
        value
      end
    end
  end

  def handle_error_response(response)
    case response.status
    when 404
      { success: false, error: I18n.t("services.customer_service_client.errors.not_found"), status: 404 }
    when 400..499
      body = parse_response(response)
      { success: false, error: body[:error] || I18n.t("services.customer_service_client.errors.client_error"), status: response.status }
    when 500..599
      { success: false, error: I18n.t("services.customer_service_client.errors.server_error"), status: response.status }
    else
      { success: false, error: I18n.t("services.customer_service_client.errors.unexpected_response"), status: response.status }
    end
  end
end
