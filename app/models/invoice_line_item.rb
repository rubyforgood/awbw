class InvoiceLineItem < ApplicationRecord
  belongs_to :invoice

  validates :description, :quantity, :unit_price_cents, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 1 }
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0 }

  def amount_cents
    unit_price_cents * quantity
  end
end
