# frozen_string_literal: true

class Customer < ApplicationRecord
  # Validations
  validates :customer_name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :address, length: { maximum: 500 }, allow_blank: true
  validates :orders_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  # Scopes
  scope :by_name, ->(name) { where("customer_name ILIKE ?", "%#{name}%") }
  scope :with_orders, -> { where("orders_count > 0") }
  scope :recent, -> { order(created_at: :desc) }

  # Increment orders count when an order is created
  def increment_orders_count!
    increment!(:orders_count)
  end

  # Decrement orders count when an order is cancelled
  def decrement_orders_count!
    decrement!(:orders_count) if orders_count.positive?
  end
end
