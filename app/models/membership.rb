class Membership < ApplicationRecord
  # TODO enable for production when the full membership feature is complete
  def self.enabled?
    !Rails.env.production?
  end

  TIME_ZONE = "Pacific Time (US & Canada)".freeze
  INVOICE_PERIOD = 1.year

  ANNUAL_COST_CENTS = ENV.fetch("ANNUAL_MEMBERSHIP_CENTS", 2500).to_i
  GRACE_PERIOD_DAYS = ENV.fetch("ANNUAL_MEMBERSHIP_GRACE_PERIOD_DAYS", 30).to_i
  RENEWAL_WINDOW_DAYS = ENV.fetch("ANNUAL_MEMBERSHIP_RENEWAL_WINDOW_DAYS", 30).to_i

  has_paper_trail

  belongs_to :person
  has_many :membership_invoices, -> { order(start_date: :desc) }, dependent: :destroy

  accepts_nested_attributes_for :membership_invoices

  # When nil, charge standard cost. A value is an override
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :one_uncancelled_membership_per_person

  scope :not_cancelled, -> { where(cancelled_at: nil) }
  scope :cancelled, -> { where.not(cancelled_at: nil) }

  def cancelled? = cancelled_at.present?
  alias_method :cancelled, :cancelled?

  def cancelled=(value)
    flag = ActiveModel::Type::Boolean.new.cast(value)
    self.cancelled_at = flag ? (cancelled_at || Time.current) : nil
  end

  def cost_dollars
    cost_cents.to_d / 100 if cost_cents
  end

  def cost_dollars=(value)
    self.cost_cents = value.present? ? (value.to_d * 100).to_i : nil
  end

  private

  def one_uncancelled_membership_per_person
    return if cancelled_at.present? || person_id.blank?

    others = Membership.not_cancelled.where(person_id: person_id)
    others = others.where.not(id: id) if persisted?
    return unless others.exists?

    errors.add(:base, "This person already has a membership that hasn't been cancelled")
  end
end
