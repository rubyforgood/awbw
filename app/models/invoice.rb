class Invoice < ApplicationRecord
  has_many :invoice_line_items, dependent: :destroy
  belongs_to :client, polymorphic: true
  belongs_to :attention_person, class_name: "Person", optional: true

  accepts_nested_attributes_for :invoice_line_items, allow_destroy: true

  validates :number, :date, :client_id, :client_type, :bill_to_address, presence: true
  validates :number, uniqueness: true

  before_validation :generate_number, on: :create

  def client_sgid
    client&.to_signed_global_id&.to_s
  end

  def client_sgid=(sgid)
    self.client = GlobalID::Locator.locate_signed(sgid) if sgid.present?
  end

  def total_cents
    invoice_line_items.sum { |item| item.unit_price_cents * item.quantity }
  end

  def bill_to_name
    return unless client
    client.respond_to?(:full_name) ? client.full_name : client.name
  end

  private

  def generate_number
    return if number.present?
    prefix = ENV["INVOICE_PREFIX"] || "INV"
    count = Invoice.where("number LIKE ?", "#{prefix}-%").count + 1
    self.number = "#{prefix}-#{format('%03d', count)}"
  end
end
