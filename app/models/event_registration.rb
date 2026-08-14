class EventRegistration < ApplicationRecord
  include RemoteSearchable
  include Registerable
  include Certifiable

  # Sentinel for the roster's Payment method filter that matches buddy-system
  # registrations (someone_else_will_pay), which isn't an expected_payment_method
  # value. Equals the column name so the meaning is self-evident.
  BUDDY_PAYMENT_FILTER = "someone_else_will_pay".freeze

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
  # Attendance outcomes surfaced as their own participation buckets; every other
  # status falls into "other" (registered, transfers, cancellations).
  NAMED_OUTCOME_STATUSES = %w[ attended incomplete_attendance no_show ].freeze
  # Sentinel filter value meaning "don't narrow on this dimension" — for a filter
  # that defaults to something specific (the attendees index defaults to attended
  # registrations on trainings, so it needs a way to say "all of them").
  FILTER_ALL = "all".freeze
  # Attendance-outcome filter options, shared by the registrations index and the
  # attendees index so the vocabulary can't drift between them.
  ATTENDANCE_FILTER_OPTIONS = (
    ATTENDANCE_STATUSES.map { |status| [ status.humanize, status ] } +
    [ [ "Other (registered, transfers, cancellations)", "other" ] ]
  ).freeze
  # Event-type filter options, matching the .event_type scope's vocabulary and the
  # report suite's Event type select (events/_event_type_filter), so the same value
  # means the same thing on a report and on the attendees index it drills into.
  EVENT_TYPE_FILTER_OPTIONS = [
    [ "All trainings", "trainings" ],
    [ "Live trainings", "live" ],
    [ "On-demand trainings", "on_demand" ],
    [ "Other events", "other" ]
  ].freeze
  # Payment-situation filter options (the .payment_status scope's vocabulary),
  # shared by the registrants filter bar and the attendees index's applied-filter
  # chips so a value can't be worded one way in the select and another in the chip.
  PAYMENT_STATUS_FILTER_OPTIONS = [
    [ "Due", "unpaid" ],
    [ "Paid", "paid" ],
    [ "Intends to pay", "intends_to_pay" ]
  ].freeze
  # Scholarship funding-source options (the .funder scope's vocabulary), named the
  # way Scholarship.externally_funded / .org_subsidized name the same split. No
  # select offers these yet — they arrive from the revenue report's drill-ins.
  FUNDER_FILTER_OPTIONS = [
    [ "Grant-funded", "external" ],
    [ "Org-subsidized", "awbw" ]
  ].freeze
  # Scholarship-status filter options (the .scholarship_status scope's vocabulary).
  SCHOLARSHIP_STATUS_FILTER_OPTIONS = [
    [ "All recipients", "yes" ],
    [ "Agreed", "agreed" ],
    [ "Tasks complete", "complete" ],
    [ "Tasks not complete", "incomplete" ],
    [ "No scholarship", "no" ]
  ].freeze
  # The ce_status value meaning "never signed up for CE" — the only one that asks
  # about the absence of a CE registration rather than its stage.
  NO_CE = "none".freeze
  # CE-status filter options (the .ce_status scope's vocabulary). Issued/not issued
  # are worded as the certificate's state because they read as overlapping
  # otherwise — one person can match both across two registrations.
  CE_STATUS_FILTER_OPTIONS = [
    [ "Registered for CE", "registered" ],
    [ "Requested", "requested" ],
    [ "Needs license", "needs_license" ],
    [ "Paid", "paid" ],
    [ "Certificate issued", "issued" ],
    [ "Certificate outstanding", "not_issued" ],
    [ "No CE", NO_CE ]
  ].freeze
  # Login-account filter options (the .account_status scope's vocabulary).
  ACCOUNT_STATUS_FILTER_OPTIONS = [
    [ "No account", "none" ],
    [ "Not invited yet", "not_invited" ],
    [ "Invited", "invited" ],
    [ "Has access", "has_access" ],
    [ "No access", "no_access" ]
  ].freeze
  # Comment filter options (the .comment_status scope's vocabulary).
  COMMENT_STATUS_FILTER_OPTIONS = [
    [ "None", "none" ],
    [ "Present", "present" ],
    [ "Flagged", "flagged" ]
  ].freeze

  # Human labels for each attendance status — the single source of truth for
  # status display (badges, filters, the dashboard breakdown).
  ATTENDANCE_STATUS_LABELS = {
    "registered" => "Registered",
    "attended" => "Attended",
    "incomplete_attendance" => "Incomplete attendance",
    "transferred_in" => "Transferred in",
    "cancelled" => "Cancelled",
    "no_show" => "No show",
    "transferred_out" => "Transferred out"
  }.freeze

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

  # Validations
  validates :registrant_id, uniqueness: { scope: :event_id }
  validates :event_id, presence: true
  validates :status, inclusion: { in: ATTENDANCE_STATUSES }, allow_nil: false
  validates :slug, uniqueness: true, allow_nil: true

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
  scope :attendance_status, ->(status) {
    status == "other" ? where.not(status: NAMED_OUTCOME_STATUSES) : where(status: status)
  }
  # Registrations on facilitator-training events ("trainings", narrowable to the
  # "live"/"on_demand" delivery formats) vs everything else ("other"); any other
  # value is a no-op so "all events" passes through.
  scope :event_type, ->(type) {
    case type
    when "trainings" then joins(:event).where(events: { facilitator_training: true })
    when "live" then joins(:event).where(events: { facilitator_training: true, on_demand: false })
    when "on_demand" then joins(:event).where(events: { facilitator_training: true, on_demand: true })
    when "other" then joins(:event).where(events: { facilitator_training: false })
    else all
    end
  }
  # Registrations whose event falls in the given calendar year. Uses a subquery
  # (via Event.in_year) so it composes with the other filters without extra joins.
  scope :in_event_year, ->(year) { where(event_id: Event.in_year(year.to_i)) }
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
  scope :registrant_city, ->(term) {
    return all if term.blank?
    like = "%#{sanitize_sql_like(term.downcase.strip)}%"
    joins(registrant: :addresses)
      .where("LOWER(addresses.city) LIKE ?", like)
      .where(addresses: { inactive: false })
      .distinct
  }
  scope :registrant_sector, ->(sector_id) {
    joins(registrant: :sectorable_items)
      .where(sectorable_items: { sector_id: sector_id })
      .distinct
  }
  # Registrant holds an active subscription to the given topic subscription list.
  scope :registrant_topic_subscription, ->(type_id) {
    where(registrant_id: TopicSubscription.active.where(topic_subscription_type_id: type_id).select(:person_id)).distinct
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
  scope :with_agreed_scholarship, -> {
    where(<<~SQL.squish)
      EXISTS (
        SELECT 1 FROM allocations
        INNER JOIN scholarships ON scholarships.id = allocations.source_id
        WHERE allocations.allocatable_type = 'EventRegistration'
          AND allocations.allocatable_id = event_registrations.id
          AND allocations.source_type = 'Scholarship'
          AND scholarships.agreement_signed_at IS NOT NULL
      )
    SQL
  }
  scope :without_scholarship, -> {
    where(<<~SQL.squish)
      NOT EXISTS (
        SELECT 1 FROM allocations
        WHERE allocations.allocatable_type = 'EventRegistration'
          AND allocations.allocatable_id = event_registrations.id
          AND allocations.source_type = 'Scholarship'
      )
    SQL
  }
  scope :scholarship_status, ->(value) {
    case value
    when "yes" then with_scholarship
    when "no" then without_scholarship
    when "agreed" then with_agreed_scholarship
    when "complete" then scholarship_tasks_completed
    when "incomplete" then scholarship_tasks_incomplete
    else all
    end
  }
  # Funded vs org-subsidized follow the app-wide split (Scholarship.externally_funded
  # / .org_subsidized): a grant AWBW funded itself counts as subsidy, not
  # external funding, so it lands in the unfunded set alongside grant-less awards.
  scope :with_funded_scholarship, -> { where(id: scholarship_allocatable_ids(Scholarship.externally_funded)) }
  scope :with_unfunded_scholarship, -> { where(id: scholarship_allocatable_ids(Scholarship.org_subsidized)) }
  # EventRegistration ids that a scholarship in the given relation is allocated to.
  def self.scholarship_allocatable_ids(scholarships)
    Allocation
      .where(allocatable_type: "EventRegistration", source_type: "Scholarship", source_id: scholarships.select(:id))
      .select(:allocatable_id)
  end
  # Funding source of a registrant's scholarship. "awbw" = org-subsidized (no
  # grant, or a grant AWBW funded itself); "external" = grant-funded (drawn from an
  # external funder's grant).
  scope :funder, ->(value) {
    case value
    when "awbw" then with_unfunded_scholarship
    when "external" then with_funded_scholarship
    else all
    end
  }
  # Free-text match on the funder behind a registrant's scholarship: the grant's
  # polymorphic funder (a Person or Organization). Labeled "Funder" in the UI. The
  # param is :funder_name to stay clear of the awbw/external funding-source
  # :funder scope above.
  scope :funder_name, ->(term) {
    return all if term.blank?
    like = "%#{sanitize_sql_like(term.downcase.strip)}%"
    where(<<~SQL.squish, like, like)
      EXISTS (
        SELECT 1 FROM allocations
        INNER JOIN scholarships ON scholarships.id = allocations.source_id
        INNER JOIN grants ON grants.id = scholarships.grant_id
        LEFT JOIN people funder_people
          ON grants.funder_type = 'Person' AND funder_people.id = grants.funder_id
        LEFT JOIN organizations funder_orgs
          ON grants.funder_type = 'Organization' AND funder_orgs.id = grants.funder_id
        WHERE allocations.allocatable_type = 'EventRegistration'
          AND allocations.allocatable_id = event_registrations.id
          AND allocations.source_type = 'Scholarship'
          AND (
            LOWER(CONCAT(funder_people.first_name, ' ', funder_people.last_name)) LIKE ?
            OR LOWER(funder_orgs.name) LIKE ?
          )
      )
    SQL
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
  # Filter the roster by payment situation: the expected payment method (the stored
  # form answer, e.g. "Credit card (now)"), or the buddy-system sentinel, which
  # matches registrations where someone else will pay. Surfaced as short-code badges.
  scope :payment_method, ->(value) {
    if value == BUDDY_PAYMENT_FILTER
      where(someone_else_will_pay: true)
    else
      where(expected_payment_method: value)
    end
  }
  # Filter by CE state. All derived (no stored CE status): payment (requested/paid)
  # is computed from allocations vs cost like the registration's own payment state;
  # issued/not_issued read the certificate delivery; needs_license is a CE
  # registration sitting on a placeholder license. "registered" adds no condition
  # of its own — the EXISTS alone means "signed up for CE, whatever its state".
  # NO_CE is the one value asking about the absence of a CE registration.
  scope :ce_status, ->(value) {
    paid_sql = <<~SQL.squish
      COALESCE((SELECT SUM(a.amount) FROM allocations a
        WHERE a.allocatable_type = 'ContinuingEducationRegistration'
          AND a.allocatable_id = cer.id), 0) >= cer.cost_cents
    SQL
    condition =
      case value
      when "registered" then "TRUE"
      when "needs_license" then "pl.number IS NULL"
      when "paid" then paid_sql
      when "requested" then "NOT (#{paid_sql})"
      when "issued" then "cer.certificate_sent_at IS NOT NULL"
      when "not_issued" then "cer.certificate_sent_at IS NULL"
      when NO_CE then "TRUE"
      end
    next all if condition.blank?

    # "No CE" is the one value that asks for the absence of a CE registration, so it
    # negates the same EXISTS the others qualify. The license join never drops a row
    # (professional_license_id is NOT NULL), so "registered" and NO_CE are exact
    # complements.
    existence = value == NO_CE ? "NOT EXISTS" : "EXISTS"
    where(<<~SQL.squish)
      #{existence} (
        SELECT 1 FROM continuing_education_registrations cer
        JOIN professional_licenses pl ON pl.id = cer.professional_license_id
        WHERE cer.event_registration_id = event_registrations.id
          AND (#{condition})
      )
    SQL
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
  # Free-text match on a registrant's comments — topic or body.
  scope :comment_text, ->(term) {
    return all if term.blank?
    where(id: Comment.where(commentable_type: "EventRegistration").matching(term).select(:commentable_id))
  }
  # Mirrors EventRegistration#account_status (none / has_access / invited /
  # no_access) as a DB filter, joining the registrant's login account. Also
  # supports "not_invited" — an umbrella for everyone who still needs an invite
  # (no account at all, or an account that was never sent a welcome invite),
  # i.e. none ∪ no_access.
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
    when "not_invited" then where.not(registrant_id: invited).where.not(registrant_id: has_access)
    else all
    end
  }
  # "linked" = at least one organization linked; "unlinked" = no organization
  # linked (whether or not an agency name was submitted); "pending" = the
  # registrant submitted an agency name on the event's registration form but
  # nothing is linked yet (mirrors the Pending chip on the roster). Needs the
  # event to resolve its registration form's agency_name field.
  scope :organization_status, ->(value, event) {
    linked = EventRegistrationOrganization.select(:event_registration_id)
    case value
    when "linked" then where(id: linked)
    when "unlinked" then where.not(id: linked)
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
  # Filter by how many form submissions the registrant made for this event:
  # none, at least one, or more than one.
  scope :submission_status, ->(value, event) {
    submissions = FormSubmission.where(event_id: event.id)
    case value
    when "none" then where.not(registrant_id: submissions.select(:person_id))
    when "has" then where(registrant_id: submissions.select(:person_id))
    when "multiple"
      where(registrant_id: submissions.group(:person_id).having("COUNT(*) > 1").select(:person_id))
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

  # { event_id => { status => count } } from a single grouped query, so callers
  # never round-trip per event. The single-event dashboard reads its own event's
  # slice; the participation report reads every event's at once.
  def self.status_counts_by_event(event_ids)
    where(event_id: event_ids)
      .group(:event_id, :status)
      .count
      .each_with_object({}) do |((event_id, status), count), map|
        (map[event_id] ||= {})[status] = count
      end
  end

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
    if params[:ce_status].present?
      registrations = registrations.ce_status(params[:ce_status])
    end
    if params[:attendance_status].present?
      registrations = registrations.attendance_status(params[:attendance_status])
    end
    if params[:event_type].present?
      registrations = registrations.event_type(params[:event_type])
    end
    if params[:event_year].present?
      registrations = registrations.in_event_year(params[:event_year])
    end
    if params[:payment_status].present?
      registrations = registrations.payment_status(params[:payment_status])
    end
    if params[:scholarship].present?
      registrations = registrations.scholarship_status(params[:scholarship])
    end
    if params[:funder].present?
      registrations = registrations.funder(params[:funder])
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
    # any? (not exists?) so a preloaded :scholarships association is reused
    # instead of firing a per-row query on the registrants roster.
    scholarships.any?
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

  # Display-only: a scholarship is only *shown* as awarded once the recipient has
  # signed the agreement. The record and its allocation exist beforehand (the data
  # is unchanged) — the award is just presented as pending acceptance until signed.
  def scholarship_awarded?
    scholarship? && scholarships.all?(&:agreement_signed?)
  end

  def attended?
    status == "attended"
  end

  # The certificate of completion unlocks once the training has happened, the
  # registrant attended, and any scholarship tasks are complete. Issuing a CE
  # certificate (an admin marking the credit sent) is itself an affirmation that
  # the registrant completed the training, so it unlocks the certificate too —
  # even when attendance was never tracked.
  def certificate_available?
    return true if ce_certificate_issued?

    event.end_date.present? && event.end_date.past? && attended? && scholarship_tasks_met?
  end

  # An invoice (and receipt) only make sense for a paid event — free events have
  # nothing to bill or receipt.
  def invoice_available?
    event.cost_cents.to_i.positive?
  end

  # A receipt is proof money changed hands, so it's available only once a paid
  # event is settled in full AND at least some of that settlement was an actual
  # payment. A balance cleared purely by scholarship or discount (no money
  # received) gets no receipt — nor does merely intending to pay.
  def receipt_available?
    invoice_available? && remaining_cost.zero? && payment_received?
  end

  # AWBW's own W-9 is only useful to a payer who actually paid us, so it's gated on
  # a paid event AND an actual payment being on file (cash, check, or card). A
  # balance cleared purely by scholarship or discount doesn't unlock it.
  def w9_available?
    invoice_available? && payment_received?
  end

  # Cost source for the Registerable payment interface: the event's price.
  def cost_cents
    event.cost_cents
  end

  # CE is now tracked as one or more ContinuingEducationRegistration records,
  # each against a professional license. These aggregate across them so callers
  # (callouts, onboarding, CSV) read a single registration-level figure.
  # `ce_registered?` is whether a CE registration record actually exists —
  # the readers below key off the record(s).
  def ce_registered?
    if ce_registrations_in_memory?
      return continuing_education_registrations.any?
    end
    continuing_education_registrations.exists?
  end

  def ce_hours_total
    if ce_registrations_in_memory?
      return continuing_education_registrations.sum { |c| c.hours.to_d }
    end
    continuing_education_registrations.sum(:hours)
  end

  # A short label summarizing the registrant's CE credit standing, matching the
  # ce_status filter buckets. Nil when CE wasn't requested, so callers can render
  # a placeholder. "Needs license" takes precedence (it's the actionable state),
  # then certificate issuance, then payment.
  def ce_status_label
    return unless ce_registered?
    return "Needs license" unless ce_license_provided?
    return "Issued" if continuing_education_registrations.all? { |c| c.certificate_sent_at.present? }
    return "Paid" if ce_paid_in_full?
    "Requested"
  end

  def ce_amount_owed_cents
    if ce_registrations_in_memory?
      return continuing_education_registrations.sum { |c| c.cost_cents.to_i }
    end
    continuing_education_registrations.sum(:cost_cents)
  end

  # Outstanding CE balance across this registration's CE registrations — cost net
  # of payments/discounts, floored at zero. The "$X due" the registrant still owes;
  # drops to zero once paid. remaining_cost is computed (not a column), so this sums
  # in Ruby.
  def ce_amount_due_cents
    continuing_education_registrations.sum { |c| c.remaining_cost }
  end

  # CE cash collected across this registration's CE registrations (payments only,
  # excluding discounts) — the CE analogue of payments_sum, for revenue reporting.
  def ce_amount_paid_cents
    continuing_education_registrations.sum { |c| c.payments_sum }
  end

  # True only when every CE registration has a known license number on file.
  def ce_license_provided?
    return false unless ce_registered?

    continuing_education_registrations.all? { |c| c.professional_license&.number_known? }
  end

  # True when CE is registered and every CE registration's certificate has been
  # issued (sent) — the terminal state of the CE lifecycle.
  def ce_certificate_issued?
    return false unless ce_registered?

    continuing_education_registrations.all? { |c| c.certificate_sent_at.present? }
  end

  # The registration's completion certificate, as shown by the registrants-roster
  # toggle. For a CE-eligible registration that's the CE certificate
  # (certificate_sent_at on its CE registrations, so it stays in sync with the CE
  # edit page); otherwise the registration's own certificate_sent_at (Certifiable).
  def certificate_issued?
    ce_registered? ? ce_certificate_issued? : certificate_sent?
  end

  def mark_certificate_issued!(issued)
    at = issued ? Time.current : nil
    if ce_registered?
      continuing_education_registrations.each { |c| c.update!(certificate_sent_at: at) }
    else
      update!(certificate_sent_at: at)
    end
  end

  # True when a CE registration exists and every one is fully paid.
  def ce_paid_in_full?
    return false unless ce_registered?

    continuing_education_registrations.all?(&:paid_in_full?)
  end

  # License numbers on file across this registration's CE registrations.
  def ce_license_numbers
    continuing_education_registrations.filter_map { |c| c.professional_license&.number }
  end

  # Read CE registrations from the in-memory collection rather than the DB when
  # it's already loaded or this registration isn't persisted (e.g. the unsaved
  # sample-ticket preview builds CE registrations without saving).
  def ce_registrations_in_memory?
    continuing_education_registrations.loaded? || new_record?
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
    ATTENDANCE_STATUS_LABELS.fetch(status, status.humanize)
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
      break unless self.class.exists?(slug: slug)
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
