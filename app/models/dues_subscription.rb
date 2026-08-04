class DuesSubscription < ApplicationRecord
  has_paper_trail

  belongs_to :person
  has_many :dues_registrations, -> { order(start_date: :desc) }, dependent: :destroy

  # A nil rate_cents means "charge the standard rate, whatever it currently is", so
  # a rate rise moves these members automatically. A stored value is a rate this
  # member is locked into — the distinction is what makes grandfathering possible.
  validates :rate_cents, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  validate :one_uncancelled_subscription_per_person

  scope :not_cancelled, -> { where(cancelled_at: nil) }
  scope :cancelled, -> { where.not(cancelled_at: nil) }

  def cancelled? = cancelled_at.present?

  private

  def one_uncancelled_subscription_per_person
    return if cancelled_at.present? || person_id.blank?

    others = DuesSubscription.not_cancelled.where(person_id: person_id)
    others = others.where.not(id: id) if persisted?
    return unless others.exists?

    errors.add(:base, "This person already has a dues subscription that hasn't been cancelled")
  end
end
