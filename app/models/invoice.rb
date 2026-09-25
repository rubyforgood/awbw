class Invoice < ApplicationRecord
  has_many :invoice_line_items, dependent: :destroy
  belongs_to :invoicee, polymorphic: true
  belongs_to :bill_to_address, class_name: "Address", optional: true
  belongs_to :attention_person, class_name: "Person", optional: true

  accepts_nested_attributes_for :invoice_line_items, allow_destroy: true,
                                 reject_if: proc { |attrs| attrs["description"].blank? }

  validates :number, :date, :invoicee_id, :invoicee_type, presence: true
  validates :number, uniqueness: true
  validate :bill_to_address_belongs_to_invoicee

  def invoicee_sgid
    invoicee&.to_signed_global_id&.to_s
  end

  def invoicee_sgid=(sgid)
    self.invoicee = GlobalID::Locator.locate_signed(sgid) if sgid.present?
  end

  def bill_to_address_belongs_to_invoicee
    return if bill_to_address.blank? || invoicee.blank?
    return if bill_to_address.addressable == invoicee

    errors.add(:bill_to_address, "must be one of the invoicee's addresses")
  end

  def self.next_number
    prefix = ENV["INVOICE_PREFIX"] || "INV"
    max = Invoice.where("number LIKE ?", "#{prefix}-%")
                 .pluck(:number)
                 .filter_map { |n| n[/\A#{Regexp.escape(prefix)}-(\d+)\z/, 1]&.to_i }
                 .max || 0
    "#{prefix}-#{format('%03d', max + 1)}"
  end

  def total_cents
    invoice_line_items.sum { |item| item.unit_price_cents * item.quantity }
  end

  def bill_to_name
    return unless invoicee
    invoicee.respond_to?(:full_name) ? invoicee.full_name : invoicee.name
  end
end
