# frozen_string_literal: true

require "sneakers"

# Use RABBITMQ_URL env variable if available, otherwise use Settings
rabbitmq_url = ENV.fetch("RABBITMQ_URL") { Settings.rabbitmq.url }

Sneakers.configure(
  amqp: rabbitmq_url,
  vhost: Settings.rabbitmq.vhost,
  exchange: Settings.rabbitmq.exchange,
  exchange_type: :topic,
  durable: true,
  ack: true,
  prefetch: 10,
  threads: 5,
  share_threads: true,
  timeout_job_after: 60,
  heartbeat: 30,
  log: Rails.logger
)

Sneakers.logger = Rails.logger
Sneakers.logger.level = Logger::INFO
