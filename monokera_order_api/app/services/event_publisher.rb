# frozen_string_literal: true

# EventPublisher is responsible for publishing events to RabbitMQ.
# It uses a topic exchange for flexible routing of messages.
#
# @example Publishing an order created event
#   publisher = EventPublisher.new
#   publisher.publish("order.created", { order_id: 1, customer_id: 123 })
#
# @example Publishing with custom options
#   publisher.publish("order.updated", data, persistent: true, priority: 5)
#
class EventPublisher
  class Error < StandardError; end
  class ConnectionError < Error; end
  class PublishError < Error; end

  # Event types constants
  module Events
    ORDER_CREATED = "order.created"
    ORDER_UPDATED = "order.updated"
    ORDER_CANCELLED = "order.cancelled"
    ORDER_COMPLETED = "order.completed"
  end

  def initialize(config: nil)
    @config = config || Settings.rabbitmq
    @connection = nil
    @channel = nil
    @exchange = nil
  end

  # Publishes an event to the message broker
  #
  # @param routing_key [String] The routing key for the message (e.g., "order.created")
  # @param payload [Hash] The message payload
  # @param options [Hash] Additional publishing options
  # @option options [Boolean] :persistent (true) Whether the message should survive broker restart
  # @option options [Integer] :priority (0) Message priority (0-9)
  # @option options [String] :correlation_id Optional correlation ID for tracking
  # @return [Boolean] true if published successfully
  # @raise [ConnectionError] if unable to connect to RabbitMQ
  # @raise [PublishError] if publishing fails
  #
  def publish(routing_key, payload, options = {})
    ensure_connection!

    message = build_message(payload, options)
    publish_options = build_publish_options(options)

    exchange.publish(
      message,
      routing_key: routing_key,
      **publish_options
    )

    Rails.logger.info("[EventPublisher] Published event: #{routing_key}")
    true
  rescue Bunny::Exception => e
    Rails.logger.error("[EventPublisher] Failed to publish: #{e.message}")
    raise PublishError, I18n.t("services.event_publisher.errors.publish_failed", message: e.message)
  end

  # Publishes an order created event
  #
  # @param order [Order] The order that was created
  # @return [Boolean] true if published successfully
  #
  def publish_order_created(order)
    publish(Events::ORDER_CREATED, order_payload(order))
  end

  # Publishes an order updated event
  #
  # @param order [Order] The order that was updated
  # @param changes [Hash] The changes that were made
  # @return [Boolean] true if published successfully
  #
  def publish_order_updated(order, changes = {})
    payload = order_payload(order).merge(changes: changes)
    publish(Events::ORDER_UPDATED, payload)
  end

  # Publishes an order cancelled event
  #
  # @param order [Order] The order that was cancelled
  # @return [Boolean] true if published successfully
  #
  def publish_order_cancelled(order)
    publish(Events::ORDER_CANCELLED, order_payload(order))
  end

  # Publishes an order completed event
  #
  # @param order [Order] The order that was completed
  # @return [Boolean] true if published successfully
  #
  def publish_order_completed(order)
    publish(Events::ORDER_COMPLETED, order_payload(order))
  end

  # Closes the connection to RabbitMQ
  #
  # @return [void]
  #
  def close
    @channel&.close if @channel&.open?
    @connection&.close if @connection&.open?
    @connection = nil
    @channel = nil
    @exchange = nil
  end

  # Checks if the connection is open
  #
  # @return [Boolean] true if connected
  #
  def connected?
    @connection&.open? && @channel&.open?
  end

  private

  attr_reader :config

  def ensure_connection!
    return if connected?

    connect!
  rescue Bunny::TCPConnectionFailed, Bunny::NetworkFailure => e
    Rails.logger.error("[EventPublisher] Connection failed: #{e.message}")
    raise ConnectionError, I18n.t("services.event_publisher.errors.connection_failed", message: e.message)
  rescue Bunny::AuthenticationFailureError => e
    Rails.logger.error("[EventPublisher] Authentication failed: #{e.message}")
    raise ConnectionError, I18n.t("services.event_publisher.errors.authentication_failed", message: e.message)
  end

  def connect!
    @connection = Bunny.new(connection_options)
    @connection.start

    @channel = @connection.create_channel
    @exchange = @channel.send(
      config.exchange_type.to_sym,
      config.exchange,
      durable: true
    )

    Rails.logger.info("[EventPublisher] Connected to RabbitMQ")
  end

  def connection_options
    # Use RABBITMQ_URL env variable if available (Docker), otherwise use config
    rabbitmq_url = ENV["RABBITMQ_URL"]

    if rabbitmq_url.present?
      rabbitmq_url  # Return URL string directly for Bunny.new
    else
      {
        host: config.host,
        port: config.port,
        username: config.username,
        password: config.password,
        vhost: config.vhost,
        connection_timeout: config.connection_timeout,
        heartbeat: config.heartbeat,
        automatically_recover: true,
        network_recovery_interval: 5
      }
    end
  end

  def exchange
    @exchange
  end

  def build_message(payload, _options = {})
    payload.to_json
  end

  def build_publish_options(options)
    {
      persistent: options.fetch(:persistent, true),
      content_type: "application/json",
      timestamp: Time.current.to_i,
      app_id: "monokera_order_api",
      correlation_id: options[:correlation_id] || SecureRandom.uuid,
      priority: options.fetch(:priority, 0)
    }
  end

  def order_payload(order)
    {
      id: order.id,
      customer_id: order.customer_id,
      product_name: order.product_name,
      quantity: order.quantity,
      price: order.price.to_f,
      total_amount: order.total_amount.to_f,
      status: order.status,
      created_at: order.created_at&.iso8601,
      updated_at: order.updated_at&.iso8601
    }
  end
end
