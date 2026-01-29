# frozen_string_literal: true

class Order < ApplicationRecord
  # Enum with string values for better readability in database
  enum :status, {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    cancelled: "cancelled"
  }

  # Validations
  validates :customer_id, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :product_name, presence: true, length: { minimum: 2, maximum: 255 }
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :status, presence: true, inclusion: { in: statuses.keys }

  # Scopes
  scope :by_customer, ->(customer_id) { where(customer_id: customer_id) }
  scope :by_status, ->(status) { where(status: status) }
  scope :recent, -> { order(created_at: :desc) }

  # Calculate total amount
  def total_amount
    quantity * price
  end

  # Alias for serializer compatibility
  alias_method :total, :total_amount

  # State transition helpers
  def can_cancel?
    pending? || processing?
  end

  def can_complete?
    pending? || processing?
  end
end
