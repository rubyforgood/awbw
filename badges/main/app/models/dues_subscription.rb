class DuesSubscription < ApplicationRecord
  has_paper_trail

  belongs_to :person
  has_many :dues_registrations, -> { order(start_date: :desc) }, dependent: :destroy

  accepts_nested_attributes_for :dues_registrations

  # When nil, charge standard cost. A value is an override
  validates :cost_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :one_uncancelled_subscription_per_person

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

  def one_uncancelled_subscription_per_person
    return if cancelled_at.present? || person_id.blank?

    others = DuesSubscription.not_cancelled.where(person_id: person_id)
    others = others.where.not(id: id) if persisted?
    return unless others.exists?

    errors.add(:base, "This person already has a dues subscription that hasn't been cancelled")
  end
end
