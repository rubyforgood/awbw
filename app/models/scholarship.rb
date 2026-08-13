class Scholarship < ApplicationRecord
  belongs_to :recipient, class_name: "Person"
  belongs_to :grant, optional: true
  has_one :allocation, as: :source, dependent: :destroy
  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :nullify
  has_many :agreement_responses, -> { chronological }, class_name: "ScholarshipAgreementResponse", dependent: :destroy

  AGREEMENT_RESPONSE_STATUSES = %w[pending accepted declined].freeze

  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attrs| attrs["body"].blank? }
  accepts_nested_attributes_for :notifications, allow_destroy: true, reject_if: proc { |attrs| attrs["email_subject"].blank? }

  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :agreement_response_status, inclusion: { in: AGREEMENT_RESPONSE_STATUSES }
  validate :recipient_must_match_allocation_registrant
  validate :allocation_must_be_valid
  validate :within_grant_budget, if: -> { grant && !agreement_declined? }

  # The allocation carries the award financially: zero while declined, else the
  # amount. Re-synced on any amount or status change so every allocation-based
  # total (balances, dashboards, grant budgets) stays correct.
  after_update :sync_allocation_amount, if: -> { saved_change_to_amount_cents? || saved_change_to_agreement_response_status? }
  # Every status transition appends a history row (the audit trail of the
  # accept ↔ decline back-and-forth).
  after_update :log_agreement_response, if: -> { saved_change_to_agreement_response_status? }
  after_create_commit :flag_event_registration_scholarship_requested

  scope :completed, -> { where(tasks_completed: true) }
  scope :agreement_signed, -> { where(agreement_response_status: "accepted") }
  scope :agreement_declined, -> { where(agreement_response_status: "declined") }
  # Declined scholarships are excluded from every total — the recipient turned the
  # award down, so it no longer counts toward amounts, counts, or budgets.
  scope :not_declined, -> { where.not(agreement_response_status: "declined") }

  # Funding split (the app-wide convention, mirrored by EventDashboard and
  # EventRevenueFigures): externally funded = backed by a grant whose funder isn't
  # the org itself; org-subsidized = no grant, or a grant AWBW funded itself.
  # Callers rendering both sides can pass an already-loaded self_funded set to
  # avoid re-running Grant.self_funded_ids (an Organization.awbw + pluck) per scope.
  # The funding split excludes declined awards — a declined scholarship funds
  # nothing, so it counts as neither externally funded nor org-subsidized.
  scope :externally_funded, ->(self_funded = Grant.self_funded_ids) { not_declined.where.not(grant_id: [ nil, *self_funded ]) }
  scope :org_subsidized, ->(self_funded = Grant.self_funded_ids) { not_declined.where(grant_id: [ nil, *self_funded ]) }

  # Scholarships from grants a given funder (Person/Organization) gave — the
  # "funder" filter. A blank funder matches nothing.
  scope :from_funder, ->(funder) { where(grant_id: Grant.where(funder: funder).select(:id)) }

  # Scholarships awarded at the given events, via the allocation → event
  # registration chain (a scholarship's allocation is on an EventRegistration).
  scope :for_events, ->(event_ids) {
    registration_ids = EventRegistration.where(event_id: event_ids).select(:id)
    source_ids = Allocation
      .where(allocatable_type: "EventRegistration", allocatable_id: registration_ids, source_type: "Scholarship")
      .select(:source_id)
    where(id: source_ids)
  }

  # Ids of events this relation's scholarships were awarded at — for narrowing an
  # event report to trainings a funder actually scholarshipped.
  def self.event_ids
    registration_ids = Allocation
      .where(allocatable_type: "EventRegistration", source_type: "Scholarship", source_id: all.select(:id))
      .select(:allocatable_id)
    EventRegistration.where(id: registration_ids).distinct.pluck(:event_id)
  end

  # Agreement state is a single tri-state column (pending → accepted → declined),
  # so the states are mutually exclusive by construction. `agreement_signed`
  # reads/writes as a virtual boolean so the admin form checkbox and strong
  # params keep working (checking it accepts, unchecking returns to pending).
  def agreement_pending? = agreement_response_status == "pending"
  def agreement_signed? = agreement_response_status == "accepted"
  def agreement_declined? = agreement_response_status == "declined"
  alias_method :agreement_signed, :agreement_signed?

  def agreement_signed=(value)
    signed = ActiveModel::Type::Boolean.new.cast(value)
    if signed
      assign_agreement_response("accepted") unless agreement_signed?
    elsif agreement_signed?
      assign_agreement_response("pending")
    end
  end

  # The recipient (or an admin) accepting the award. Idempotent — a repeat accept
  # is a no-op, so it doesn't append a duplicate history row.
  def accept_agreement!(by: "recipient")
    return if agreement_signed?

    assign_agreement_response("accepted", by:)
    save!
  end

  # The recipient declining, with their reason. Recording it (via after_update)
  # zeroes the allocation so the award stops counting in every total and appends
  # a history row; the row is kept for history.
  def decline_agreement!(reason, by: "recipient")
    assign_agreement_response("declined", reason:, by:)
    save!
  end

  # Admin re-offering a declined award: back to pending (the recipient decides
  # again) and the allocation is re-funded to the current amount. Explicit action —
  # editing the amount alone no longer reactivates a decline.
  def reoffer_agreement!(by: "admin")
    return if agreement_pending?

    assign_agreement_response("pending", by:)
    save!
  end

  # The event registration this scholarship is allocated against (nil for a
  # grant-funded scholarship with no registration).
  def event_registration
    registration = allocation&.allocatable
    registration if registration.is_a?(EventRegistration)
  end

  # The event this scholarship was awarded at, via its allocation's registration
  # (nil for a grant-funded scholarship with no event registration).
  def event
    event_registration&.event
  end

  # The current agreement response — the source for the responded-at date and
  # decline reason (which aren't stored on the scholarship; only the status is).
  # Nil while pending with no response yet.
  def latest_agreement_response
    agreement_responses.loaded? ? agreement_responses.max_by(&:responded_at) : agreement_responses.chronological.last
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

    others_total = grant.scholarships.not_declined.where.not(id: id).sum(:amount_cents)
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

  # Assign the new agreement state in memory (persisted by the caller's save).
  # The reason + responder are stashed for the history row the after_update
  # callback writes — they live on the response, not on the scholarship.
  def assign_agreement_response(status, reason: nil, by: "admin")
    self.agreement_response_status = status
    @agreement_response_reason = (status == "declined" ? reason.presence : nil)
    @agreement_response_by = by
  end

  def sync_allocation_amount
    return unless allocation

    desired = agreement_declined? ? 0 : amount_cents.to_i
    allocation.update!(amount: desired) unless allocation.amount == desired
  end

  def log_agreement_response
    agreement_responses.create!(
      status: agreement_response_status,
      reason: @agreement_response_reason,
      responded_at: Time.current,
      responder: @agreement_response_by.presence || "admin",
      amount_cents: amount_cents
    )
    @agreement_response_reason = nil
    @agreement_response_by = nil
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
