class EventRegistration < ApplicationRecord
  include RemoteSearchable
  include Registerable

  belongs_to :registrant, class_name: "Person"
  belongs_to :event
  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy
  has_many :event_registration_organizations, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :destroy
  has_many :organizations, through: :event_registration_organizations
  has_many :allocations, as: :allocatable
  has_many :continuing_education_registrations, dependent: :destroy
  has_many :scholarships, -> { distinct },
    through: :allocations, source: :source, source_type: "Scholarship"
  has_many :checklist_completions, class_name: "EventRegistrationChecklistCompletion", dependent: :destroy

  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attrs| attrs["body"].blank? }
  accepts_nested_attributes_for :notifications, allow_destroy: true, reject_if: proc { |attrs| attrs["email_subject"].blank? }
  # Lets the registration edit form edit the registrant's shout-out text (which
  # lives on the Person) inline, alongside the registration's own shout-out flag.
  accepts_nested_attributes_for :registrant

  before_create :generate_slug
  after_update :release_scholarships, if: :status_changed_to_cancelled?
  after_commit :send_cancellation_emails, if: :status_changed_to_cancelled?

  ACTIVE_STATUSES = %w[ registered attended incomplete_attendance transferred_in ].freeze
  INACTIVE_STATUSES = %w[ cancelled no_show transferred_out ].freeze
  ATTENDANCE_STATUSES = (ACTIVE_STATUSES + INACTIVE_STATUSES).freeze

  # Manual onboarding checklist steps shown on the event's Onboarding tab. Each is
  # an audited boolean (stored as a row in event_registration_checklist_completions,
  # capturing who completed it and when). The keys double as the param/column keys
  # the toggle endpoint accepts. Adding/removing a step here needs no migration.
  CHECKLIST_STEPS = {
    "set_up_in_mailchimp" => "Mailchimp",
    "set_up_in_cms" => "CMS"
  }.freeze

  # Per-day attendance booleans on event_registrations. Plain (un-audited) columns,
  # only the first event.day_count of them are shown on the Onboarding tab.
  DAY_FIELDS = (1..5).map { |day| "completed_day_#{day}" }.freeze

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
  # Mirrors ReminderRecipientFilter#matches_ce_status?. The "license"/"hours"
  # sub-statuses only make sense for someone who requested CE credit, so they're
  # gated on it. "paid" has no CE-specific payment record yet, so it falls back
  # to the registrant being paid in full.
  scope :ce_status, ->(value) {
    case value
    when "requested" then where(ce_credit_requested: true)
    when "license_not_provided" then where(ce_credit_requested: true).where(ce_license_number: [ nil, "" ])
    when "hours_not_provided" then where(ce_credit_requested: true).where("COALESCE(ce_hours_requested, 0) <= 0")
    when "paid" then where(ce_credit_requested: true).merge(paid_in_full)
    else all
    end
  }
  scope :comment_status, ->(value) {
    commented = Comment.where(commentable_type: "EventRegistration").select(:commentable_id)
    case value
    when "none" then where.not(id: commented)
    when "present" then where(id: commented)
    when "flagged" then where(id: Comment.where(commentable_type: "EventRegistration", flagged: true).select(:commentable_id))
    else all
    end
  }
  # Mirrors EventRegistration#account_status (none / has_access / invited /
  # no_access) as a DB filter, joining the registrant's login account.
  scope :account_status, ->(value) {
    # Guard every subquery against NULL person_id (system/audit users) — a NULL in
    # a NOT IN list makes the whole comparison return no rows.
    with_user = User.where.not(person_id: nil).select(:person_id)
    has_access = User.has_access.where.not(person_id: nil).select(:person_id)
    invited = User.where.not(person_id: nil).where.not(welcome_instructions_sent_at: nil).select(:person_id)
    case value
    when "none" then where.not(registrant_id: with_user)
    when "has_access" then where(registrant_id: has_access)
    when "invited" then where(registrant_id: invited).where.not(registrant_id: has_access)
    when "no_access" then where(registrant_id: with_user).where.not(registrant_id: has_access).where.not(registrant_id: invited)
    else all
    end
  }
  # "linked" = at least one organization linked; "pending" = the registrant
  # submitted an agency name on the event's registration form but nothing is
  # linked yet (mirrors the Pending chip on the roster). Needs the event to
  # resolve its registration form's agency_name field.
  scope :organization_status, ->(value, event) {
    linked = EventRegistrationOrganization.select(:event_registration_id)
    case value
    when "linked" then where(id: linked)
    when "pending"
      field = event.registration_form&.form_fields&.find_by(field_identifier: "agency_name")
      next none unless field
      submitted = FormAnswer.joins(:form_submission)
        .where(form_field_id: field.id, form_submissions: { form_id: event.registration_form.id })
        .where.not(submitted_answer: [ nil, "" ])
        .select(Arel.sql("form_submissions.person_id"))
      where(registrant_id: submitted).where.not(id: linked)
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

  # Email the communications box matches notifications against. Uniform accessor
  # so the shared notifications/_communications partial works across records.
  def communications_email
    registrant&.preferred_email
  end

  def active?
    status.in?(ACTIVE_STATUSES)
  end

  # Cancel this registration. Releasing scholarships and sending cancellation
  # emails hang off the status-change callbacks, so this and every other path to
  # "cancelled" (e.g. the admin edit form's status dropdown) behave identically.
  def cancel!
    update!(status: "cancelled")
  end

  # True once the event has happened and an attendance outcome is on record —
  # attended, partially attended, or a no-show. Cancelled/transferred are not
  # attendance outcomes. (Distinct from #active?, which is about registration
  # standing, and #attended?, which is specifically "fully attended".)
  def attendance_recorded?
    status.in?(%w[ attended incomplete_attendance no_show ])
  end

  # Transferred out to another event. The trail to where the registrant went is
  # history worth keeping, so it blocks deletion. Transferred_in is deliberately
  # excluded: it's an ordinary active registration here, and the source event's
  # transferred_out record already preserves the transfer trail.
  def transferred_out?
    status == "transferred_out"
  end

  # Safe to delete only when removing the record would not orphan financial data
  # or erase history. Allocations tie the registration to a financial source of
  # any kind (payments, scholarships, and others) and have no dependent: :destroy,
  # so a registration with any allocation must be kept — even a reverted payment
  # leaves its (now net-zero) allocation rows. An attendance outcome (attended,
  # incomplete, or no-show) or a transfer out is likewise history worth keeping.
  def deletable?
    !allocations.exists? && !attendance_recorded? && !transferred_out?
  end

  def checked_in?
    # checked_in_at.present?
  end

  # True when the registrant should be granted access to ticket materials
  # (training links, etc.) even though they haven't paid in full yet. Admins
  # flip the `intends_to_pay` flag when someone commits to paying after the
  # deadline so they aren't locked out in the meantime. This does NOT mark the
  # registration as paid — payment status still shows as due.
  #
  # This is the single seam for "may this registrant reach paid content?":
  # any payment-gated resource (the videoconference join link today, recordings
  # or downloads in the future) should gate on this, NOT on `paid_in_full?`.
  # Reporting surfaces (rosters, CSV exports, dashboard metrics) must keep using
  # `paid_in_full?` so they still reflect the real balance owed.
  def payment_access_granted?
    paid_in_full? || intends_to_pay?
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

  def attended?
    status == "attended"
  end

  # The certificate of completion unlocks once the training has happened, the
  # registrant attended, and any scholarship tasks are complete.
  def certificate_available?
    event.end_date.present? && event.end_date.past? && attended? && scholarship_tasks_met?
  end

  # An invoice (and receipt) only make sense for a paid event — free events have
  # nothing to bill or receipt.
  def invoice_available?
    event.cost_cents.to_i.positive?
  end

  # A paid-in-full receipt is available once a paid event carries no balance.
  def receipt_available?
    invoice_available? && remaining_cost.zero?
  end

  # Cost source for the Registerable payment interface: the event's price.
  def cost_cents
    event.cost_cents
  end

  # True when the registrant has supplied a CE license number.
  def ce_license_provided?
    ce_license_number.present?
  end

  # A short label summarizing the registrant's CE credit standing, matching the
  # ce_status filter buckets. Nil when CE credit was not requested, so callers
  # can render a placeholder. "Incomplete" takes precedence over "Paid" because
  # a missing license/hours is the actionable state regardless of payment.
  def ce_status_label
    return unless ce_credit_requested?
    return "Incomplete" if !ce_license_provided? || ce_hours_requested.to_i <= 0
    return "Paid" if paid_in_full?
    "Requested"
  end

  # What the registrant owes for their requested CE hours, in cents, at the
  # default hourly rate. Zero when no hours were requested.
  def ce_amount_owed_cents
    ce_hours_requested.to_i * CE_HOURLY_RATE_DOLLARS * 100
  end

  def joinable?
    active? && payment_access_granted? && event.videoconference_window_open?
  end

  # Whether this registrant may see the videoconference connection details yet
  # (join link, meeting ID, passcode) — on the ticket, the videoconference page,
  # and in calendar entries. Gated on payment access (paid or intends to pay) AND
  # the event being within a week of starting, so the link isn't shared early.
  # Distinct from #joinable?, which is the tight 30-minute "click to join now"
  # window for the live link.
  def videoconference_details_visible?
    payment_access_granted? && event.videoconference_details_visible?
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

  # The completion record for a checklist step, or nil. Reads from the loaded
  # association so the Onboarding matrix can preload completions and avoid N+1.
  def checklist_completion_for(step)
    checklist_completions.detect { |completion| completion.step == step.to_s }
  end

  def checklist_step_completed?(step)
    checklist_completion_for(step).present?
  end

  def day_completed?(day)
    DAY_FIELDS.include?("completed_day_#{day}") && public_send("completed_day_#{day}")
  end

  # How many of the event's in-range days (the first event.day_count of them) are
  # marked complete on this registration.
  def completed_day_count
    DAY_FIELDS.first(event.day_count).count { |field| public_send(field) }
  end

  # The attendance status implied purely by how many days are marked complete:
  # none → registered, all → attended, some-but-not-all → incomplete_attendance.
  # (A one-day event has no partial state: 0 → registered, 1 → attended.)
  def attendance_status_for_days
    completed = completed_day_count
    return "registered" if completed.zero?
    return "attended" if completed >= event.day_count
    "incomplete_attendance"
  end

  # Realign the attendance status to match the completed-day count after a day
  # checkbox is toggled on the Onboarding matrix. Only auto-managed while the
  # registration is in an active status — cancelled and no_show are deliberate
  # manual states we never override by toggling a day. Returns true if the status
  # actually changed.
  def sync_attendance_status_to_days!
    return false unless status.in?(ACTIVE_STATUSES)
    derived = attendance_status_for_days
    return false if derived == status
    update!(status: derived)
    true
  end

  # Program status(es) for THIS registration only: classify each organization
  # linked to the registration as of the training date (the 1st of the event's
  # month), excluding the registrant's own facilitator affiliation to that org so
  # the status reflects whether the *org* was already a facilitator program when
  # they joined. Distinct, so one linked org shows one badge — unlike the
  # registrant-wide rollup, this ignores affiliations to other organizations.
  def program_statuses
    reference_date = (event&.start_date&.to_date || Date.current).beginning_of_month
    organizations.filter_map do |organization|
      own = registrant.affiliations.find { |affiliation| affiliation.organization_id == organization.id && affiliation.facilitator? }
      organization.facilitator_status_on(reference_date, excluding_affiliation_id: own&.id)
    end.uniq
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

  def generate_slug
    loop do
      self.slug = SecureRandom.urlsafe_base64(16)
      break unless EventRegistration.exists?(slug: slug)
    end
  end

  def status_changed_to_cancelled?
    saved_change_to_status? && status == "cancelled"
  end

  # On cancellation, release any awarded scholarship back to its grant by zeroing
  # the amount (Scholarship#sync_allocation_amount zeroes the allocation to match).
  # scholarship_requested is left set on purpose: reactivating won't re-award, but
  # the registration should still reflect that a scholarship was requested.
  def release_scholarships
    scholarships.each { |scholarship| scholarship.update!(amount_cents: 0) }
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
