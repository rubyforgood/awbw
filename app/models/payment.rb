class Payment < ApplicationRecord
  has_paper_trail
  PAYER_TYPES = %w[Person Organization].freeze

  # Rolling time windows for the index "Time period" filter, keyed label => value.
  # The index defaults to DEFAULT_PERIOD so the first search shows recent payments;
  # pick "All time" to intentionally search the full history.
  PERIOD_OPTIONS = {
    "Past day" => "past_day",
    "Past week" => "past_week",
    "Past month" => "past_month",
    "Past year" => "past_year",
    "All time" => "all_time"
  }.freeze
  DEFAULT_PERIOD = "past_month".freeze

  has_many :allocations, as: :source
  has_many :refunds, as: :refundable
  belongs_to :person, optional: true
  belongs_to :organization, optional: true
  belongs_to :form_submission, optional: true

  validates :amount_cents, numericality: { greater_than: 0 }
  validates :currency, presence: true
  validates :payer_type, presence: true, inclusion: { in: PAYER_TYPES }

  validate :at_least_one_payer
  validate :payer_and_designation_distinct_kinds, if: :sgid_assigned?

  before_create :set_external_origin
  before_validation :set_amount_cents_remaining, if: :new_record?
  before_validation :assign_parties_from_sgids, if: :sgid_assigned?
  before_validation :auto_set_payer_type

  attr_accessor :payer_sgid, :additional_designation_sgid

  scope :by_type, ->(types) {
    return if types.blank?
    types = types.split(",") if types.is_a?(String)
    types = types.reject(&:blank?)
    where(type: types) if types.present?
  }
  scope :has_remaining, ->(value) {
    case value
    when "yes" then where("amount_cents_remaining > 0")
    when "no" then where("amount_cents_remaining = 0")
    end
  }
  scope :in_period, ->(period) {
    window = case period
    when "past_day" then 1.day.ago
    when "past_week" then 1.week.ago
    when "past_month" then 1.month.ago
    when "past_year" then 1.year.ago
    end
    where(created_at: window..) if window
  }

  def self.search_by_params(params)
    results = all
    results = results.by_type(params[:type]) if params[:type].present?
    results = results.where(payer_type: params[:payer_type]) if params[:payer_type].present?
    results = results.where(person_id: params[:person_id]) if params[:person_id].present?
    results = results.where(organization_id: params[:organization_id]) if params[:organization_id].present?
    results = results.has_remaining(params[:has_remaining]) if params[:has_remaining].present? && params[:has_remaining] != "all"
    results = results.matching_search(params[:search]) if params[:search].present?
    results = results.where("amount_cents >= ?", (params[:amount_min].to_d * 100).to_i) if params[:amount_min].present?
    results = results.where("amount_cents <= ?", (params[:amount_max].to_d * 100).to_i) if params[:amount_max].present?
    results = results.in_period(params[:period].presence || DEFAULT_PERIOD)
    results
  end

  # Free-text search across the JSON metadata blob and the Stripe charge id.
  def self.matching_search(query)
    pattern = "%#{sanitize_sql_like(query)}%"
    where("CAST(metadata AS CHAR) LIKE :q OR stripe_charge_id LIKE :q", q: pattern)
  end

  def payer
    case payer_type
    when "Organization" then organization
    else person
    end
  end

  # The record currently selected in the "Payer" dropdown. Falls back to the
  # organization (then person) for an unsaved payment that hasn't picked a
  # payer_type yet, so a form prefilled from a registration defaults sensibly.
  def form_payer
    return payer if payer_type.present?
    organization || person
  end

  # The other party — whichever of person/organization isn't the payer.
  def form_additional_designation
    [ organization, person ].compact.find { |record| record != form_payer }
  end

  # The record a submitted sgid resolves to, falling back to the saved/default
  # selection. Used to set the columns and to re-render the form (with the user's
  # picks intact) after a validation failure.
  def selected_payer
    defined?(@payer_sgid) ? locate_party(@payer_sgid) : form_payer
  end

  def selected_additional_designation
    defined?(@additional_designation_sgid) ? locate_party(@additional_designation_sgid) : form_additional_designation
  end



  def amount_dollars
    amount_cents.to_d / 100 if amount_cents
  end

  def amount_dollars=(value)
    self.amount_cents = (value.to_d * 100).to_i if value.present?
  end

  def allocated_dollars
    (amount_cents - (amount_cents_remaining || 0)).to_d / 100
  end

  def allocated_dollars=(value)
    self.amount_cents_remaining = ((amount_cents || 0) - (value.to_d * 100).to_i) if value.present?
  end

  def remaining_dollars
    amount_cents_remaining.to_d / 100 if amount_cents_remaining
  end

  def remaining_dollars=(value)
    self.amount_cents_remaining = (value.to_d * 100).to_i if value.present?
  end

  private

  def set_external_origin
    self.external_origin = false unless is_a?(ExternalProcessorPayment)
  end

  def set_amount_cents_remaining
    self.amount_cents_remaining = amount_cents if amount_cents_remaining.nil? && amount_cents.present?
  end

  def auto_set_payer_type
    if person_id.present? && organization_id.blank?
      self.payer_type = "Person"
    elsif organization_id.present? && person_id.blank?
      self.payer_type = "Organization"
    end
  end

  def sgid_assigned?
    defined?(@payer_sgid) || defined?(@additional_designation_sgid)
  end

  def assign_parties_from_sgids
    payer_record = selected_payer
    other_record = selected_additional_designation

    self.person_id = nil
    self.organization_id = nil

    case payer_record
    when Organization
      self.payer_type = "Organization"
      self.organization_id = payer_record.id
    when Person
      self.payer_type = "Person"
      self.person_id = payer_record.id
    end

    fill_party_slot(other_record)
  end

  # Fill whichever of person_id / organization_id the payer didn't already take.
  # If the additional designation is the same kind as the payer, the single
  # column for that kind is already used, so it's dropped (the schema only holds
  # one person and one organization per payment).
  def fill_party_slot(record)
    case record
    when Organization
      self.organization_id ||= record.id
    when Person
      self.person_id ||= record.id
    end
  end

  def locate_party(sgid)
    return if sgid.blank?
    record = GlobalID::Locator.locate_signed(sgid)
    record if record.is_a?(Person) || record.is_a?(Organization)
  rescue StandardError
    nil
  end

  def at_least_one_payer
    if person_id.blank? && organization_id.blank?
      errors.add(:base, "At least one payer (person or organization) must be present")
    end
  end

  # A payment holds one person and one organization, so the payer and the
  # additional designation can't be the same kind. Reject the submission rather
  # than silently dropping the designation (fill_party_slot's no-op).
  def payer_and_designation_distinct_kinds
    payer_record = selected_payer
    designation = selected_additional_designation
    return if payer_record.blank? || designation.blank?

    same_kind = [ Person, Organization ].any? do |klass|
      payer_record.is_a?(klass) && designation.is_a?(klass)
    end
    return unless same_kind

    errors.add(:base, "The payer and additional designation must be different kinds — a payment records one person and one organization, not two of the same.")
  end
end
