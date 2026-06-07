class Grant < ApplicationRecord
  belongs_to :donor, polymorphic: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :scholarships, dependent: :restrict_with_error

  DONOR_TYPES = %w[Organization Person].freeze

  validates :name, presence: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :donor_type, inclusion: { in: DONOR_TYPES }

  scope :by_deadline, -> { order(Arel.sql("application_deadline IS NULL, application_deadline ASC")) }

  # Money is stored in cents; expose a dollar-based accessor for forms and display.
  def amount_dollars
    amount_cents.to_d / 100 if amount_cents
  end

  def amount_dollars=(value)
    self.amount_cents = (value.to_d * 100).to_i if value.present?
  end

  # Resolve the polymorphic donor from a signed global id, mirroring the
  # GlobalID pattern used for scholarship allocatables.
  def donor_sgid
    donor&.to_signed_global_id&.to_s
  end

  def donor_sgid=(sgid)
    self.donor = GlobalID::Locator.locate_signed(sgid) if sgid.present?
  end

  # The donor is the funder of any scholarships drawn from the grant.
  def funder_name
    donor&.try(:full_name) || donor&.try(:name) || donor&.to_s
  end

  def scholarships_total_cents
    scholarships.sum(:amount_cents)
  end

  def remaining_cents
    amount_cents.to_i - scholarships_total_cents
  end

  def remaining_dollars
    remaining_cents.to_d / 100
  end

  # Criteria and tasks are stored as newline-separated text; expose them as
  # trimmed lists for display.
  def eligibility_criteria_list
    text_to_list(eligibility_criteria)
  end

  def task_list
    text_to_list(tasks)
  end

  private

  def text_to_list(text)
    text.to_s.split("\n").map(&:strip).reject(&:blank?)
  end
end
