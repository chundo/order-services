# frozen_string_literal: true

require "rails_helper"

RSpec.describe EventPublisher do
  let(:config) do
    double(
      "RabbitMQConfig",
      host: "localhost",
      port: 5672,
      username: "guest",
      password: "guest",
      vhost: "/",
      exchange: "monokera_events_test",
      exchange_type: "topic",
      connection_timeout: 5,
      heartbeat: 30
    )
  end

  let(:publisher) { described_class.new(config: config) }
  let(:order) { create(:order) }

  let(:mock_connection) { instance_double(Bunny::Session) }
  let(:mock_channel) { instance_double(Bunny::Channel) }
  let(:mock_exchange) { instance_double(Bunny::Exchange) }

  before do
    allow(Bunny).to receive(:new).and_return(mock_connection)
    allow(mock_connection).to receive(:start)
    allow(mock_connection).to receive(:open?).and_return(true)
    allow(mock_connection).to receive(:close)
    allow(mock_connection).to receive(:create_channel).and_return(mock_channel)
    allow(mock_channel).to receive(:open?).and_return(true)
    allow(mock_channel).to receive(:close)
    allow(mock_channel).to receive(:topic).and_return(mock_exchange)
    allow(mock_exchange).to receive(:publish)
  end

  describe "#publish" do
    let(:routing_key) { "order.created" }
    let(:payload) { { order_id: 1, customer_id: 123 } }

    it "publishes message to the exchange" do
      expect(mock_exchange).to receive(:publish).with(
        payload.to_json,
        hash_including(routing_key: routing_key, persistent: true)
      )

      publisher.publish(routing_key, payload)
    end

    it "returns true on success" do
      result = publisher.publish(routing_key, payload)
      expect(result).to be true
    end

    it "includes correlation_id in publish options" do
      expect(mock_exchange).to receive(:publish).with(
        anything,
        hash_including(:correlation_id)
      )

      publisher.publish(routing_key, payload)
    end

    it "allows custom correlation_id" do
      custom_id = "custom-123"

      expect(mock_exchange).to receive(:publish).with(
        anything,
        hash_including(correlation_id: custom_id)
      )

      publisher.publish(routing_key, payload, correlation_id: custom_id)
    end

    it "sets content_type as application/json" do
      expect(mock_exchange).to receive(:publish).with(
        anything,
        hash_including(content_type: "application/json")
      )

      publisher.publish(routing_key, payload)
    end

    context "when connection fails" do
      before do
        allow(mock_connection).to receive(:open?).and_return(false)
        allow(Bunny).to receive(:new).and_raise(Bunny::TCPConnectionFailed.new("Connection refused"))
      end

      it "raises ConnectionError" do
        expect { publisher.publish(routing_key, payload) }
          .to raise_error(EventPublisher::ConnectionError, /conexión/)
      end
    end

    context "when authentication fails" do
      before do
        allow(mock_connection).to receive(:open?).and_return(false)
        allow(Bunny).to receive(:new).and_raise(Bunny::AuthenticationFailureError.new("", "", ""))
      end

      it "raises ConnectionError" do
        expect { publisher.publish(routing_key, payload) }
          .to raise_error(EventPublisher::ConnectionError, /autenticación/)
      end
    end

    context "when publishing fails" do
      before do
        allow(mock_exchange).to receive(:publish).and_raise(Bunny::Exception.new("Channel closed"))
      end

      it "raises PublishError" do
        expect { publisher.publish(routing_key, payload) }
          .to raise_error(EventPublisher::PublishError, /publicar/)
      end
    end
  end

  describe "#publish_order_created" do
    it "publishes with order.created routing key" do
      expect(mock_exchange).to receive(:publish).with(
        anything,
        hash_including(routing_key: "order.created")
      )

      publisher.publish_order_created(order)
    end

    it "includes order data in payload" do
      expect(mock_exchange).to receive(:publish) do |message, _options|
        payload = JSON.parse(message, symbolize_names: true)
        expect(payload[:id]).to eq(order.id)
        expect(payload[:customer_id]).to eq(order.customer_id)
        expect(payload[:product_name]).to eq(order.product_name)
        expect(payload[:status]).to eq(order.status)
      end

      publisher.publish_order_created(order)
    end
  end

  describe "#publish_order_updated" do
    let(:changes) { { status: %w[pending processing] } }

    it "publishes with order.updated routing key" do
      expect(mock_exchange).to receive(:publish).with(
        anything,
        hash_including(routing_key: "order.updated")
      )

      publisher.publish_order_updated(order, changes)
    end

    it "includes changes in payload" do
      expect(mock_exchange).to receive(:publish) do |message, _options|
        payload = JSON.parse(message, symbolize_names: true)
        expect(payload[:changes]).to eq(status: %w[pending processing])
      end

      publisher.publish_order_updated(order, changes)
    end
  end

  describe "#publish_order_cancelled" do
    it "publishes with order.cancelled routing key" do
      expect(mock_exchange).to receive(:publish).with(
        anything,
        hash_including(routing_key: "order.cancelled")
      )

      publisher.publish_order_cancelled(order)
    end
  end

  describe "#publish_order_completed" do
    it "publishes with order.completed routing key" do
      expect(mock_exchange).to receive(:publish).with(
        anything,
        hash_including(routing_key: "order.completed")
      )

      publisher.publish_order_completed(order)
    end
  end

  describe "#close" do
    before do
      publisher.publish("test", {}) # Force connection
    end

    it "closes the channel and connection" do
      expect(mock_channel).to receive(:close)
      expect(mock_connection).to receive(:close)

      publisher.close
    end
  end

  describe "#connected?" do
    context "when not connected" do
      it "returns false" do
        expect(publisher.connected?).to be_falsey
      end
    end

    context "when connected" do
      before do
        publisher.publish("test", {}) # Force connection
      end

      it "returns true" do
        expect(publisher.connected?).to be true
      end
    end
  end

  describe "Events constants" do
    it "defines ORDER_CREATED" do
      expect(EventPublisher::Events::ORDER_CREATED).to eq("order.created")
    end

    it "defines ORDER_UPDATED" do
      expect(EventPublisher::Events::ORDER_UPDATED).to eq("order.updated")
    end

    it "defines ORDER_CANCELLED" do
      expect(EventPublisher::Events::ORDER_CANCELLED).to eq("order.cancelled")
    end

    it "defines ORDER_COMPLETED" do
      expect(EventPublisher::Events::ORDER_COMPLETED).to eq("order.completed")
    end
  end
end
