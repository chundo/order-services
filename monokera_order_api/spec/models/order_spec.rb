# frozen_string_literal: true

require "rails_helper"

RSpec.describe Order, type: :model do
  describe "factory" do
    it "has a valid factory" do
      expect(build(:order)).to be_valid
    end
  end

  describe "validations" do
    subject { build(:order) }

    # Customer ID validations
    it { should validate_presence_of(:customer_id) }
    it { should validate_numericality_of(:customer_id).only_integer.is_greater_than(0) }

    # Product name validations
    it { should validate_presence_of(:product_name) }
    it { should validate_length_of(:product_name).is_at_least(2).is_at_most(255) }

    # Quantity validations
    it { should validate_presence_of(:quantity) }
    it { should validate_numericality_of(:quantity).only_integer.is_greater_than(0) }

    # Price validations
    it { should validate_presence_of(:price) }
    it { should validate_numericality_of(:price).is_greater_than_or_equal_to(0) }

    # Status validations
    it { should validate_presence_of(:status) }

    it "validates status is a valid enum value" do
      expect { build(:order, status: "invalid_status") }.to raise_error(ArgumentError)
    end
  end

  describe "enum status" do
    it "defines pending status" do
      order = build(:order, status: "pending")
      expect(order.pending?).to be true
    end

    it "defines processing status" do
      order = build(:order, status: "processing")
      expect(order.processing?).to be true
    end

    it "defines completed status" do
      order = build(:order, status: "completed")
      expect(order.completed?).to be true
    end

    it "defines cancelled status" do
      order = build(:order, status: "cancelled")
      expect(order.cancelled?).to be true
    end

    it "stores status as string in database" do
      order = create(:order, status: "pending")
      expect(Order.find(order.id).status).to eq("pending")
    end
  end

  describe "scopes" do
    let!(:customer_1_order) { create(:order, customer_id: 1) }
    let!(:customer_2_order) { create(:order, customer_id: 2) }
    let!(:pending_order) { create(:order, status: "pending") }
    let!(:completed_order) { create(:order, status: "completed") }

    describe ".by_customer" do
      it "returns orders for a specific customer" do
        expect(Order.by_customer(1)).to include(customer_1_order)
        expect(Order.by_customer(1)).not_to include(customer_2_order)
      end
    end

    describe ".by_status" do
      it "returns orders with a specific status" do
        expect(Order.by_status("pending")).to include(pending_order)
        expect(Order.by_status("pending")).not_to include(completed_order)
      end
    end

    describe ".recent" do
      it "returns orders in descending order by created_at" do
        orders = Order.recent
        expect(orders.first.created_at).to be >= orders.last.created_at
      end
    end
  end

  describe "#total_amount" do
    it "calculates the total amount (quantity * price)" do
      order = build(:order, quantity: 3, price: 25.50)
      expect(order.total_amount).to eq(76.50)
    end

    it "returns 0 when quantity is 0" do
      order = build(:order, quantity: 1, price: 0)
      order.quantity = 0 # bypass validation for test
      expect(order.total_amount).to eq(0)
    end
  end

  describe "traits" do
    it "creates a processing order" do
      order = build(:order, :processing)
      expect(order.processing?).to be true
    end

    it "creates a completed order" do
      order = build(:order, :completed)
      expect(order.completed?).to be true
    end

    it "creates a cancelled order" do
      order = build(:order, :cancelled)
      expect(order.cancelled?).to be true
    end
  end
end
