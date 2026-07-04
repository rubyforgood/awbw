class Grant < ApplicationRecord
  belongs_to :donor, polymorphic: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :scholarships, dependent: :restrict_with_error

  DONOR_TYPES = %w[Organization Person].freeze

  validates :name, presence: true
  validates :amount_cents, numericality: { greater_than_or_equal_to: 0 }
  validates :donor_type, inclusion: { in: DONOR_TYPES }
  validate :amount_covers_scholarships_already_issued

  scope :by_deadline, -> { order(Arel.sql("application_deadline IS NULL, application_deadline ASC")) }

  # Total scholarship draws against a grant, as a correlated subquery. Used by the
  # funds scopes so they stay flat WHERE clauses — no GROUP BY/HAVING, which would
  # break will_paginate's total_entries count on the paginated index.
  ALLOCATED_CENTS_SUBQUERY =
    "COALESCE((SELECT SUM(scholarships.amount_cents) FROM scholarships WHERE scholarships.grant_id = grants.id), 0)".freeze

  # Grants that still have unallocated funds (donation amount exceeds the sum of
  # scholarships drawn against them).
  scope :with_funds_remaining, -> { where("grants.amount_cents > #{ALLOCATED_CENTS_SUBQUERY}") }

  # Grants whose full donation has been issued as scholarships (nothing left to
  # award) — the complement of with_funds_remaining.
  scope :fully_issued, -> { where("grants.amount_cents <= #{ALLOCATED_CENTS_SUBQUERY}") }

  # Task-completion filters keyed off the grant's scholarships. "Outstanding"
  # means at least one scholarship still has incomplete tasks; "all completed"
  # means the grant has scholarships and none are outstanding. The subqueries
  # exclude grant-less scholarships (grant_id IS NULL) — a stray NULL in the
  # NOT IN set below would otherwise make all_tasks_completed match nothing.
  scope :tasks_outstanding, -> {
    where(id: Scholarship.where(tasks_completed: false).where.not(grant_id: nil).select(:grant_id))
  }
  scope :all_tasks_completed, -> {
    where(id: Scholarship.where.not(grant_id: nil).select(:grant_id))
      .where.not(id: Scholarship.where(tasks_completed: false).where.not(grant_id: nil).select(:grant_id))
  }

  # Grants offered in a scholarship's "Funded by grant" picker: every grant with
  # funds left, plus the one this scholarship is already drawn from — that grant
  # stays selectable even when fully allocated, since this scholarship is what
  # exhausted it and deselecting it should remain possible.
  def self.selectable_for(scholarship)
    # Eager-load the polymorphic donor: the picker renders name_with_funder (→
    # funder_name → donor) for every grant, which is an N+1 without this.
    grants = with_funds_remaining.includes(:donor).by_deadline.to_a
    connected = scholarship&.grant
    grants << connected if connected && grants.exclude?(connected)
    grants
  end

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

  # Display label for dropdowns: the grant name with its funder in parens
  # (e.g. "Spring 2026 Fund (Acme Foundation)") so awarders can tell apart
  # grants that share a name.
  def name_with_funder
    funder_name.present? ? "#{name} (#{funder_name})" : name
  end

  # Total scholarship draws against this grant. Sums the already-loaded
  # association in memory when present (the index eager-loads :scholarships) to
  # avoid a per-row SQL SUM; otherwise issues a single aggregate query.
  def scholarships_total_cents
    return scholarships.sum { |s| s.amount_cents.to_i } if scholarships.loaded?

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

  # A grant's amount can't be lowered below what has already been awarded against
  # it — the scholarships are committed, so the grant must at least cover them.
  # Mirrors Scholarship#within_grant_budget from the other side of the ledger.
  def amount_covers_scholarships_already_issued
    return unless amount_cents

    issued = scholarships_total_cents
    if amount_cents < issued
      errors.add(:amount_cents, "can't be less than the #{MoneyFormatter.dollars_from_cents(issued)} already awarded in scholarships")
    end
  end

  def text_to_list(text)
    text.to_s.split("\n").map(&:strip).reject(&:blank?)
  end
end
