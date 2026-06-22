class EventRegistration < ApplicationRecord
  include RemoteSearchable

  belongs_to :registrant, class_name: "Person"
  belongs_to :event
  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy
  has_many :event_registration_organizations, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :destroy
  has_many :organizations, through: :event_registration_organizations
  has_many :allocations, as: :allocatable
  has_many :scholarships, -> { distinct },
    through: :allocations, source: :source, source_type: "Scholarship"

  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attrs| attrs["body"].blank? }
  accepts_nested_attributes_for :notifications, reject_if: proc { |attrs| attrs["email_subject"].blank? }
  # Lets the registration edit form edit the registrant's shout-out text (which
  # lives on the Person) inline, alongside the registration's own shout-out flag.
  accepts_nested_attributes_for :registrant

  before_create :generate_slug
  after_create :snapshot_registrant_organizations
  after_commit :send_cancellation_emails, if: :status_changed_to_cancelled?

  ACTIVE_STATUSES = %w[ registered attended incomplete_attendance transferred_in ].freeze
  INACTIVE_STATUSES = %w[ cancelled no_show transferred_out ].freeze
  ATTENDANCE_STATUSES = (ACTIVE_STATUSES + INACTIVE_STATUSES).freeze

  # Default price the registrant owes per requested continuing-education hour.
  # The CE summary on the registration form multiplies it by ce_hours_requested.
  CE_HOURLY_RATE_DOLLARS = 25

  # Validations
  validates :registrant_id, uniqueness: { scope: :event_id }
  validates :event_id, presence: true
  validates :status, inclusion: { in: ATTENDANCE_STATUSES }, allow_nil: false
  validates :slug, uniqueness: true, allow_nil: true
  validates :ce_hours_requested, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  # Scopes
  scope :registrant_name, ->(registrant_name) { joins(:registrant).where(
    "LOWER(REPLACE(CONCAT(people.first_name, people.last_name), ' ', '')) LIKE :name
    OR LOWER(REPLACE(CONCAT(people.last_name, people.first_name), ' ', '')) LIKE :name
    OR LOWER(REPLACE(people.first_name, ' ', '')) LIKE :name
    OR LOWER(REPLACE(people.last_name, ' ', '')) LIKE :name", name: "%#{registrant_name}%") }
  scope :event_title, ->(event_title) { joins(:event).where("LOWER(events.title LIKE ?)", "%#{event_title}%") }
  scope :active, -> { where(status: ACTIVE_STATUSES) }
  scope :inactive, -> { where(status: INACTIVE_STATUSES) }
  scope :attended, -> { where(status: "attended") }
  scope :registrant_ids, ->(ids) { where(registrant_id: ids.to_s.split("-").map(&:to_i)) }
  scope :attendance_status, ->(status) { where(status: status) }
  scope :registrant_state, ->(state) {
    joins(registrant: :addresses)
      .where(addresses: { inactive: false, state: state })
      .distinct
  }
  # Accepts "STATE|County" (from the manage filter) to scope to a county within
  # a specific state, or a bare county name for backward compatibility.
  scope :registrant_county, ->(value) {
    state, county = value.to_s.include?("|") ? value.split("|", 2) : [ nil, value.to_s ]
    next none if county.blank?
    conditions = { inactive: false, county: county }
    conditions[:state] = state if state.present?
    joins(registrant: :addresses).where(addresses: conditions).distinct
  }
  scope :registrant_sector, ->(sector_id) {
    joins(registrant: :sectorable_items)
      .where(sectorable_items: { sector_id: sector_id })
      .distinct
  }
  scope :with_scholarship, -> {
    where(<<~SQL.squish)
      EXISTS (
        SELECT 1 FROM allocations
        WHERE allocations.allocatable_type = 'EventRegistration'
          AND allocations.allocatable_id = event_registrations.id
          AND allocations.source_type = 'Scholarship'
      )
    SQL
  }
  scope :scholarship_tasks_completed, -> { with_scholarship_where_tasks(true) }
  scope :scholarship_tasks_incomplete, -> { with_scholarship_where_tasks(false) }
  scope :with_scholarship_where_tasks, ->(completed) {
    where(<<~SQL.squish, completed)
      EXISTS (
        SELECT 1 FROM allocations
        INNER JOIN scholarships ON scholarships.id = allocations.source_id
        WHERE allocations.allocatable_type = 'EventRegistration'
          AND allocations.allocatable_id = event_registrations.id
          AND allocations.source_type = 'Scholarship'
          AND scholarships.tasks_completed = ?
      )
    SQL
  }
  scope :scholarship_status, ->(value) {
    case value
    when "yes" then with_scholarship
    when "complete" then scholarship_tasks_completed
    when "incomplete" then scholarship_tasks_incomplete
    else all
    end
  }
  scope :paid_in_full, -> {
    where(<<~SQL.squish)
      COALESCE((
        SELECT SUM(allocations.amount) FROM allocations
        WHERE allocations.allocatable_type = 'EventRegistration'
          AND allocations.allocatable_id = event_registrations.id
      ), 0) >= COALESCE((
        SELECT events.cost_cents FROM events WHERE events.id = event_registrations.event_id
      ), 0)
    SQL
  }
  scope :not_paid_in_full, -> {
    where(<<~SQL.squish)
      COALESCE((
        SELECT events.cost_cents FROM events WHERE events.id = event_registrations.event_id
      ), 0) > 0
      AND COALESCE((
        SELECT SUM(allocations.amount) FROM allocations
        WHERE allocations.allocatable_type = 'EventRegistration'
          AND allocations.allocatable_id = event_registrations.id
      ), 0) < COALESCE((
        SELECT events.cost_cents FROM events WHERE events.id = event_registrations.event_id
      ), 0)
    SQL
  }
  scope :payment_status, ->(value) {
    case value
    when "paid" then paid_in_full
    when "unpaid" then not_paid_in_full
    when "intends_to_pay" then where(intends_to_pay: true)
    else all
    end
  }
  scope :keyword, ->(term) {
    return none if term.blank?

    sanitized = "%#{sanitize_sql_like(term.downcase.strip)}%"
    left_joins(registrant: [ :user, :contact_methods, :addresses, { affiliations: [ :organization ] } ])
      .left_joins(registrant: { affiliations: { organization: :addresses } })
      .where(
        "LOWER(people.first_name) LIKE :term
        OR LOWER(people.last_name) LIKE :term
        OR LOWER(CONCAT(people.first_name, ' ', people.last_name)) LIKE :term
        OR LOWER(users.email) LIKE :term
        OR LOWER(people.email) LIKE :term
        OR LOWER(contact_methods.value) LIKE :term
        OR LOWER(addresses.city) LIKE :term
        OR LOWER(addresses.phone) LIKE :term
        OR LOWER(organizations.name) LIKE :term",
        term: sanitized
      )
      .distinct
  }

  def self.search_by_params(params)
    registrations = is_a?(ActiveRecord::Relation) ? self : all
    if params[:registrant_id].present?
      registrations = registrations.where(registrant_id: params[:registrant_id])
    elsif params[:registrant_name].present?
      registrations = registrations.registrant_name(params[:registrant_name].downcase.strip)
    end
    if params[:event_id].present?
      registrations = registrations.where(event_id: params[:event_id])
    elsif params[:event_name].present?
      registrations = registrations.event_title(params[:event_name].downcase.strip)
    end
    if params[:organization_id].present?
      registrations = registrations.joins(:event_registration_organizations)
                                   .where(event_registration_organizations: { organization_id: params[:organization_id] })
                                   .distinct
    end
    registrations
  end

  def name
    "(#{ registrant&.full_name }) #{ event.start_date.strftime("%Y-%m-%d @ %I:%M %p") }: #{ event.title }"
  end

  def active?
    status.in?(ACTIVE_STATUSES)
  end

  def checked_in?
    # checked_in_at.present?
  end

  def paid?
    paid_in_full?
  end

  # True when the registrant should be granted access to ticket materials
  # (training links, etc.) even though they haven't paid in full yet. Admins
  # flip the `intends_to_pay` flag when someone commits to paying after the
  # deadline so they aren't locked out in the meantime. This does NOT mark the
  # registration as paid — payment status still shows as due.
  #
  # This is the single seam for "may this registrant reach paid content?":
  # any payment-gated resource (the videoconference join link today, recordings
  # or downloads in the future) should gate on this, NOT on `paid?`. Reporting
  # surfaces (rosters, CSV exports, dashboard metrics) must keep using `paid?` /
  # `paid_in_full?` so they still reflect the real balance owed.
  def payment_access_granted?
    paid? || intends_to_pay?
  end

  # Human-readable payment status for rosters and CSV exports. Assumes the event
  # has a cost — callers show nothing for free events.
  def payment_status_label
    return "Paid" if paid_in_full?
    return "Intends to pay" if intends_to_pay?
    "Due"
  end

  def scholarship?
    scholarships.exists?
  end

  # Noun phrase distinguishing a scholarship-requested registration from a
  # standard one in email subjects and notification labels (e.g.
  # "event scholarship registration" vs "event registration"). Driven by the
  # `scholarship_requested` flag, which is set at registration time, so it's
  # reliable when the confirmation email goes out (before any Scholarship
  # record exists).
  def registration_subject_noun
    scholarship_requested? ? "event scholarship registration" : "event registration"
  end

  def scholarship_tasks_met?
    return true if scholarships.empty?
    scholarships.all?(&:tasks_completed?)
  end

  def allocations_sum
    allocations.sum(:amount)
  end

  def remaining_cost
    [ event.cost_cents - allocations_sum, 0 ].max
  end

  def paid_in_full?
    return true if event.cost_cents.to_i <= 0
    allocations_sum >= event.cost_cents.to_i
  end

  def payments_sum
    allocations.where(source_type: Payment.polymorphic_name).sum(:amount)
  end

  def partially_paid?
    !paid_in_full? && payments_sum.to_i.positive?
  end

  def discounted?
    allocations.where(source_type: "Discount").exists?
  end

  # True when the registrant has supplied a CE license number.
  def ce_license_provided?
    ce_license_number.present?
  end

  # What the registrant owes for their requested CE hours, in cents, at the
  # default hourly rate. Zero when no hours were requested.
  def ce_amount_owed_cents
    ce_hours_requested.to_i * CE_HOURLY_RATE_DOLLARS * 100
  end

  def joinable?
    active? && payment_access_granted? && event.videoconference_window_open?
  end

  # Bucket the registrant's login account into one of four states for the bulk
  # reminder filters. Precedence matters: a confirmed, unlocked, active account
  # has access regardless of when it was invited; a still-pending account counts
  # as "invited" only while it hasn't gained access. Returns one of
  # "none", "has_access", "invited", "no_access".
  def account_status
    account = registrant&.user
    return "none" if account.nil?
    return "has_access" if account.has_access?
    return "invited" if account.welcome_instructions_sent_at.present?
    "no_access"
  end

  def attendance_status_label
    return "—" if status.blank?
    case status
    when "registered" then "Registered"
    when "attended" then "Attended"
    when "incomplete_attendance" then "Incomplete attendance"
    when "cancelled" then "Cancelled"
    when "no_show" then "No show"
    when "transferred_in" then "Transferred in"
    when "transferred_out" then "Transferred out"
    else status.humanize
    end
  end

  remote_searchable_by :registrant,
    scope: ->(query) {
      return none if query.blank?

      words = query.split.flat_map { |w| w.split(/[\s\-]+/) }.reject(&:blank?)
      return none if words.blank?

      pattern = "%#{words.join('%')}%"
      active
        .joins(:registrant, :event)
        .where(
          "people.first_name LIKE :p
           OR people.last_name LIKE :p
           OR people.email LIKE :p
           OR people.legal_first_name LIKE :p
           OR people.email_2 LIKE :p
           OR events.title LIKE :p",
          p: pattern
        )
    }

  def remote_search_label
    {
      id: id,
      label: "#{registrant.full_name} - #{event.title} (##{id})"
    }
  end

  private

  def snapshot_registrant_organizations
    registrant.affiliations.active.includes(:organization).find_each do |aff|
      event_registration_organizations.create(organization: aff.organization)
    end
  end

  def generate_slug
    loop do
      self.slug = SecureRandom.urlsafe_base64(16)
      break unless EventRegistration.exists?(slug: slug)
    end
  end

  def status_changed_to_cancelled?
    saved_change_to_status? && status == "cancelled"
  end

  def send_cancellation_emails
    email = registrant&.preferred_email
    return if email.blank?

    NotificationServices::CreateNotification.call(
      noticeable: self,
      kind: "event_registration_cancelled",
      recipient_role: :person,
      recipient_email: email,
      notification_type: 1
    )

    NotificationServices::CreateNotification.call(
      noticeable: self,
      kind: "event_registration_cancelled_fyi",
      recipient_role: :admin,
      recipient_email: ENV.fetch("REPLY_TO_EMAIL", "programs@awbw.org"),
      notification_type: 1
    )
  end
end
