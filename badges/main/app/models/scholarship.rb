class Scholarship < ApplicationRecord
  belongs_to :recipient, class_name: "Person"
  belongs_to :grant, optional: true
  has_one :allocation, as: :source, dependent: :destroy
  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :destroy

  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attrs| attrs["body"].blank? }
  accepts_nested_attributes_for :notifications, allow_destroy: true, reject_if: proc { |attrs| attrs["email_subject"].blank? }

  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validate :recipient_must_match_allocation_registrant
  validate :allocation_must_be_valid
  validate :within_grant_budget, if: :grant

  after_update :sync_allocation_amount, if: -> { saved_change_to_amount_cents? }
  after_create_commit :flag_event_registration_scholarship_requested

  scope :completed, -> { where(tasks_completed: true) }
  scope :agreement_signed, -> { where.not(agreement_signed_at: nil) }

  # The agreement is signed when a signed-at timestamp is present — a single
  # source of truth. `agreement_signed` reads/writes as a virtual boolean so the
  # admin form checkbox and strong params keep working, stamping or clearing the
  # timestamp accordingly (and preserving an existing time across re-saves).
  def agreement_signed? = agreement_signed_at.present?
  alias_method :agreement_signed, :agreement_signed?

  def agreement_signed=(value)
    signed = ActiveModel::Type::Boolean.new.cast(value)
    self.agreement_signed_at = signed ? (agreement_signed_at || Time.current) : nil
  end

  def amount_dollars
    amount_cents.to_d / 100 if amount_cents
  end

  def amount_dollars=(value)
    self.amount_cents = (value.to_d * 100).to_i if value.present?
  end

  # Email the communications box matches notifications against. Uniform accessor
  # so the shared notifications/_communications partial works across records.
  def communications_email
    recipient&.preferred_email
  end

  private

  def within_grant_budget
    return unless amount_cents

    others_total = grant.scholarships.where.not(id: id).sum(:amount_cents)
    if others_total + amount_cents > grant.amount_cents
      errors.add(:amount_cents, "would exceed the grant's available funds")
    end
  end

  # A newly built allocation is only persisted by has_one autosave *after* the
  # parent saves, and Rails silently drops it (returning true from save) if it's
  # invalid. That left orphaned scholarships with no allocation — awarded per the
  # success flash, but invisible on the registration, which finds them through
  # allocations. Validate it up front so an over-owed amount fails the save with a
  # clear message. Scoped to a new allocation so unrelated re-saves of an existing
  # scholarship aren't blocked by an already-persisted (possibly legacy) allocation.
  def allocation_must_be_valid
    return unless allocation&.new_record?
    return if allocation.valid?

    allocation.errors.full_messages.each { |message| errors.add(:base, message) }
  end

  def recipient_must_match_allocation_registrant
    return unless allocation&.allocatable.respond_to?(:registrant)

    if recipient != allocation.allocatable.registrant
      errors.add(:recipient, "must be the same person as the event registration's registrant")
    end
  end

  def sync_allocation_amount
    return unless allocation

    allocation.update!(amount: amount_cents.to_i)
  end

  # When a scholarship is awarded against an event registration, the registration
  # should reflect that a scholarship was requested. We never clear this on delete:
  # removing an awarded scholarship doesn't undo the fact that one was requested.
  def flag_event_registration_scholarship_requested
    registration = allocation&.allocatable
    return unless registration.is_a?(EventRegistration)
    return if registration.scholarship_requested?

    registration.update!(scholarship_requested: true)
  end
end
