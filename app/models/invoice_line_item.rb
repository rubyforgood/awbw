class InvoiceLineItem < ApplicationRecord
  belongs_to :invoice

  validates :description, :quantity, :unit_price_cents, presence: true
  validates :quantity, numericality: { greater_than_or_equal_to: 1 }
  validates :unit_price_cents, numericality: { greater_than_or_equal_to: 0 }

  def unit_price_dollars
    unit_price_cents.to_d / 100
  end

  def unit_price_dollars=(value)
    self.unit_price_cents = (value.to_d * 100).to_i if value.present?
  end

  def amount_cents
    unit_price_cents * quantity
  end
end
