# frozen_string_literal: true

require "rails_helper"

RSpec.describe OrderCreatedWorker, type: :worker do
  let(:worker) { described_class.new }

  describe "#work" do
    context "con mensaje válido" do
      let!(:customer) { create(:customer, orders_count: 0) }
      let(:valid_message) do
        {
          event: "order.created",
          data: {
            order_id: 123,
            customer_id: customer.id,
            total_amount: "100.00",
            status: "pending"
          },
          timestamp: Time.current.iso8601
        }.to_json
      end

      it "incrementa el orders_count del cliente" do
        expect { worker.work(valid_message) }
          .to change { customer.reload.orders_count }.from(0).to(1)
      end

      it "retorna :ack" do
        expect(worker.work(valid_message)).to eq(:ack)
      end

      it "registra un mensaje de éxito en el log" do
        expect(Rails.logger).to receive(:info).with(/Incremented orders_count for customer #{customer.id}/)
        worker.work(valid_message)
      end
    end

    context "con cliente inexistente" do
      let(:message_with_invalid_customer) do
        {
          event: "order.created",
          data: {
            order_id: 123,
            customer_id: 999_999,
            total_amount: "100.00",
            status: "pending"
          },
          timestamp: Time.current.iso8601
        }.to_json
      end

      it "retorna :ack para evitar reintentos infinitos" do
        expect(worker.work(message_with_invalid_customer)).to eq(:ack)
      end

      it "registra una advertencia en el log" do
        expect(Rails.logger).to receive(:warn).with(/Customer not found: 999999/)
        worker.work(message_with_invalid_customer)
      end
    end

    context "con mensaje JSON inválido" do
      let(:invalid_json) { "invalid json {" }

      it "retorna :reject" do
        expect(worker.work(invalid_json)).to eq(:reject)
      end

      it "registra un error de parsing" do
        expect(Rails.logger).to receive(:error).with(/Error parsing message/)
        worker.work(invalid_json)
      end
    end

    context "con payload sin customer_id" do
      let(:message_without_customer_id) do
        {
          event: "order.created",
          data: {
            order_id: 123,
            total_amount: "100.00",
            status: "pending"
          },
          timestamp: Time.current.iso8601
        }.to_json
      end

      it "retorna :reject" do
        expect(worker.work(message_without_customer_id)).to eq(:reject)
      end

      it "registra un error por customer_id faltante" do
        expect(Rails.logger).to receive(:error).with(/Missing customer_id/)
        worker.work(message_without_customer_id)
      end
    end

    context "con error inesperado durante el procesamiento" do
      let!(:customer) { create(:customer) }
      let(:valid_message) do
        {
          event: "order.created",
          data: {
            order_id: 123,
            customer_id: customer.id,
            total_amount: "100.00",
            status: "pending"
          },
          timestamp: Time.current.iso8601
        }.to_json
      end

      before do
        allow(Customer).to receive(:find_by).and_raise(StandardError, "Database error")
      end

      it "retorna :reject" do
        expect(worker.work(valid_message)).to eq(:reject)
      end

      it "registra el error en el log" do
        expect(Rails.logger).to receive(:error).with(/Error processing message: Database error/).ordered
        expect(Rails.logger).to receive(:error).with(/Message:/).ordered
        expect(Rails.logger).to receive(:error).with(/Backtrace:/).ordered
        worker.work(valid_message)
      end
    end

    context "cuando se reciben múltiples órdenes del mismo cliente" do
      let!(:customer) { create(:customer, orders_count: 5) }

      def create_order_message(order_id)
        {
          event: "order.created",
          data: {
            order_id: order_id,
            customer_id: customer.id,
            total_amount: "50.00",
            status: "pending"
          },
          timestamp: Time.current.iso8601
        }.to_json
      end

      it "incrementa el contador por cada orden" do
        worker.work(create_order_message(1))
        worker.work(create_order_message(2))
        worker.work(create_order_message(3))

        expect(customer.reload.orders_count).to eq(8)
      end
    end
  end

  describe "configuración del worker" do
    it "está configurado para la cola correcta" do
      expect(described_class.queue_name).to eq(Settings.rabbitmq.queue)
    end
  end
end
