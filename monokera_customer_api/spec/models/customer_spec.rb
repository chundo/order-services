# frozen_string_literal: true

require "rails_helper"

RSpec.describe Customer, type: :model do
  describe "factory" do
    it "has a valid factory" do
      expect(build(:customer)).to be_valid
    end
  end

  describe "validations" do
    subject { build(:customer) }

    it { is_expected.to validate_presence_of(:customer_name) }
    it { is_expected.to validate_length_of(:customer_name).is_at_least(2).is_at_most(100) }

    it { is_expected.to validate_presence_of(:email) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }

    it "validates email format" do
      customer = build(:customer, email: "invalid-email")
      expect(customer).not_to be_valid
      expect(customer.errors[:email]).to be_present
    end

    it "accepts valid email format" do
      customer = build(:customer, email: "valid@example.com")
      expect(customer).to be_valid
    end

    it { is_expected.to validate_length_of(:address).is_at_most(500) }

    it { is_expected.to validate_numericality_of(:orders_count).only_integer.is_greater_than_or_equal_to(0) }
  end

  describe "scopes" do
    describe ".by_name" do
      let!(:john) { create(:customer, customer_name: "John Doe") }
      let!(:jane) { create(:customer, customer_name: "Jane Smith") }

      it "returns customers matching name (case insensitive)" do
        expect(described_class.by_name("john")).to include(john)
        expect(described_class.by_name("john")).not_to include(jane)
      end

      it "returns customers with partial match" do
        expect(described_class.by_name("doe")).to include(john)
      end
    end

    describe ".with_orders" do
      let!(:with_orders) { create(:customer, :with_orders) }
      let!(:without_orders) { create(:customer, orders_count: 0) }

      it "returns only customers with orders" do
        expect(described_class.with_orders).to include(with_orders)
        expect(described_class.with_orders).not_to include(without_orders)
      end
    end

    describe ".recent" do
      let!(:old_customer) { create(:customer, created_at: 1.week.ago) }
      let!(:new_customer) { create(:customer, created_at: 1.day.ago) }

      it "returns customers in descending order by created_at" do
        expect(described_class.recent.first).to eq(new_customer)
        expect(described_class.recent.last).to eq(old_customer)
      end
    end
  end

  describe "#increment_orders_count!" do
    let(:customer) { create(:customer, orders_count: 5) }

    it "increments the orders_count by 1" do
      expect { customer.increment_orders_count! }.to change { customer.reload.orders_count }.from(5).to(6)
    end
  end

  describe "#decrement_orders_count!" do
    context "when orders_count is positive" do
      let(:customer) { create(:customer, orders_count: 5) }

      it "decrements the orders_count by 1" do
        expect { customer.decrement_orders_count! }.to change { customer.reload.orders_count }.from(5).to(4)
      end
    end

    context "when orders_count is zero" do
      let(:customer) { create(:customer, orders_count: 0) }

      it "does not decrement below zero" do
        expect { customer.decrement_orders_count! }.not_to change { customer.reload.orders_count }
      end
    end
  end

  describe "traits" do
    it "creates customer with orders" do
      customer = create(:customer, :with_orders)
      expect(customer.orders_count).to be > 0
    end

    it "creates customer without address" do
      customer = create(:customer, :without_address)
      expect(customer.address).to be_nil
    end
  end
end
