# frozen_string_literal: true

require "sneakers"

# Worker that consumes order created events from RabbitMQ
# Increments the orders_count for the corresponding customer
#
# @example Expected message format
#   {
#     "event": "order.created",
#     "data": {
#       "order_id": 123,
#       "customer_id": 1,
#       "total_amount": "100.00",
#       "status": "pending"
#     },
#     "timestamp": "2026-01-29T00:00:00Z"
#   }
#
class OrderCreatedWorker
  include Sneakers::Worker

  from_queue Settings.rabbitmq.queue,
             exchange: Settings.rabbitmq.exchange,
             exchange_type: :topic,
             routing_key: "order.created",
             durable: true,
             ack: true

  # Processes the order created message
  #
  # @param message [String] JSON event message
  # @return [Symbol] :ack if processed successfully, :reject if error occurred
  #
  def work(message)
    payload = parse_message(message)
    return reject! unless payload

    customer_id = extract_customer_id(payload)
    return reject! unless customer_id

    process_order_created(customer_id)
  rescue StandardError => e
    handle_error(e, message)
    reject!
  end

  private

  # Parses the JSON message
  #
  # @param message [String] Message in JSON format
  # @return [Hash, nil] Hash with payload or nil if parsing error
  #
  def parse_message(message)
    JSON.parse(message, symbolize_names: true)
  rescue JSON::ParserError => e
    Rails.logger.error("[OrderCreatedWorker] Error parsing message: #{e.message}")
    nil
  end

  # Extracts customer_id from payload
  #
  # @param payload [Hash] Event payload
  # @return [Integer, nil] Customer ID or nil if not present
  #
  def extract_customer_id(payload)
    # Support both wrapped format { data: { customer_id: ... } } and direct format { customer_id: ... }
    customer_id = payload.dig(:data, :customer_id) || payload[:customer_id]

    unless customer_id
      Rails.logger.error("[OrderCreatedWorker] Missing customer_id in payload: #{payload}")
      return nil
    end

    customer_id
  end

  # Processes the order created event by incrementing the counter
  #
  # @param customer_id [Integer] Customer ID
  # @return [Symbol] :ack if processed successfully
  #
  def process_order_created(customer_id)
    customer = Customer.find_by(id: customer_id)

    unless customer
      Rails.logger.warn("[OrderCreatedWorker] Customer not found: #{customer_id}")
      return ack! # Ack anyway to avoid infinite retry
    end

    customer.increment_orders_count!
    Rails.logger.info("[OrderCreatedWorker] Incremented orders_count for customer #{customer_id}")
    ack!
  end

  # Handles errors during message processing
  #
  # @param error [StandardError] Caught error
  # @param message [String] Original message
  #
  def handle_error(error, message)
    Rails.logger.error("[OrderCreatedWorker] Error processing message: #{error.message}")
    Rails.logger.error("[OrderCreatedWorker] Message: #{message}")
    Rails.logger.error("[OrderCreatedWorker] Backtrace: #{error.backtrace.first(5).join("\n")}")
  end
end
