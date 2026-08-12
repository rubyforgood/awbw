class Event < ApplicationRecord
  include Featureable, Publishable, TagFilterable, Trendable, WindowsTypeFilterable
  include ActionText::Attachable
  include RemoteSearchable

  # Grace window on either side of the event during which the videoconference
  # link is available to paid registrants.
  VIDEOCONFERENCE_JOIN_BUFFER = 30.minutes

  # How long a finished event keeps a full card on the events index before it
  # collapses into the compact archive list (admins only — they're the only ones
  # who see past and unpublished events there).
  CARD_ARCHIVE_AGE = 1.month

  has_rich_text :rhino_header
  has_rich_text :rhino_description

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :location, optional: true
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :event_registrations, dependent: :destroy
  has_many :topic_subscriptions, foreign_key: :interested_event_id, inverse_of: :interested_event, dependent: :nullify
  has_many :event_staffs, dependent: :destroy
  has_many :event_forms, dependent: :destroy
  has_many :registration_ticket_callouts, -> { ordered }, dependent: :destroy, inverse_of: :event
  # Block destroying an event that has submissions (registrations, scholarship
  # applications, payments). Submissions that were never tied to an event are
  # unaffected. Destroying instead would orphan the payments that hang off a
  # submission (payments have an FK to form_submissions and no dependent rule).
  has_many :form_submissions, dependent: :restrict_with_error

  has_many :categorizable_items, dependent: :destroy, inverse_of: :categorizable, as: :categorizable
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  # Asset associations
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy
  # has_many through
  has_many :forms, through: :event_forms
  has_many :registrants, through: :event_registrations, class_name: "Person"
  has_many :staff_members, through: :event_staffs, source: :person
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items

  accepts_nested_attributes_for :event_staffs, allow_destroy: true,
    reject_if: proc { |attrs| attrs["person_id"].blank? }
  accepts_nested_attributes_for :registration_ticket_callouts, allow_destroy: true,
    # Reject only blank *new* callouts; existing rows (with an id) must always
    # process so a control-only built-in row's hidden/position toggle persists even
    # though it submits no title.
    reject_if: proc { |attrs| attrs["id"].blank? && attrs["title"].blank? }

  # Callbacks
  after_commit :build_public_registration_form, if: :public_registration_just_enabled?
  before_validation :merge_date_time_fields

  # Validations
  validates_presence_of :title, :start_date, :end_date
  validates_inclusion_of :published, in: [ true, false ]
  validates_numericality_of :cost_cents, greater_than_or_equal_to: 0, allow_nil: true
  validate :registration_form_required_when_publicly_registerable, on: :update
  validate :staff_members_are_unique, on: :update

  # Nested attributes
  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank

  # SearchCop
  include SearchCop
  search_scope :search do
    attributes :title, :description
  end

  # Autocomplete (used by the admin "favorite event" picker on user accounts)
  remote_searchable_by :title

  def self.remote_search(query)
    super.reorder(start_date: :desc)
  end

  def remote_search_label
    label = start_date ? "#{title} (#{start_date.to_date.to_fs(:long)})" : title
    { id: id, label: label }
  end

  # Scopes
  # See Featureable, Publishable, TagFilterable, Trendable, WindowsTypeFilterable
  scope :featured, -> { registerable.where(published: true, featured: true) } # overrides Publishable
  scope :publicly_featured, -> { where(published: true, publicly_visible: true, publicly_featured: true) } # overrides Featureable
  scope :registerable, -> { where("registration_close_date IS NULL OR registration_close_date >= ?", Time.current) }
  scope :using_form, ->(form_id) { joins(:event_forms).where(event_forms: { form_id: form_id }).distinct }
  # Events flagged as facilitator trainings (the "TAC" a scholarship recipient
  # attends). Drives the scholarship index's training column.
  scope :facilitator_trainings, -> { where(facilitator_training: true) }
  # Delivery format: self-paced ("On-demand") vs scheduled instructor-led ("Live").
  scope :on_demand, -> { where(on_demand: true) }
  scope :live, -> { where(on_demand: false) }
  # start_date is a date column, so compare against a date — a Time would be cast
  # to midnight and drop events starting today.
  scope :upcoming, -> { where("start_date >= ?", Date.current) }
  # Events that charge a registration fee (cost_cents may be nil for free ones).
  scope :paid, -> { where("cost_cents > 0") }
  # Paid events whose ticket payment deadline lands on the given date (in the app
  # time zone). Drives the payment reminders' "one week before" / "one day before"
  # windows. payment_due_deadline is a datetime, so match against the whole day.
  scope :payment_due_on, ->(date) { paid.where(payment_due_deadline: date.all_day) }
  # Paid events whose ticket payment deadline has already passed, within the given
  # half-open time window (`from...to`). Drives the one-time overdue reminder,
  # bounded so a fresh deploy or a stalled cron never blasts long-past deadlines.
  scope :payment_due_between, ->(from, to) { paid.where(payment_due_deadline: from...to) }
  # Events whose start date falls in the given calendar year. Keyed off the year
  # of start_date directly — a date range would miss same-day times on Dec 31,
  # since start_date is a datetime and the range's upper bound is midnight.
  scope :in_year, ->(year) { where("YEAR(start_date) = ?", year.to_i) }

  def self.search_by_params(params)
    stories = is_a?(ActiveRecord::Relation) ? self : all
    stories = stories.search(params[:query]) if params[:query].present?
    stories = stories.sector_names_all(params[:sector_names_all]) if params[:sector_names_all].present?
    stories = stories.category_names_all(params[:category_names_all]) if params[:category_names_all].present?
    stories = stories.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    stories = stories.using_form(params[:form_id]) if params[:form_id].present?
    stories
  end

  def registration_form
    forms.find_by(event_forms: { role: "registration" })
  end

  def registration_form_ids
    event_forms.registration.pluck(:form_id)
  end

  # Whether a signed-in user should register in one click rather than being
  # routed to the registration form. True when no registration form is linked,
  # or when an admin has explicitly opted members out of the form. A linked form
  # (even one without fields yet) routes signed-in users to the form.
  def one_click_for_signed_in?
    signed_in_one_click_enabled? || registration_form.nil?
  end

  def scholarship_form
    forms.find_by(event_forms: { role: "scholarship" })
  end

  def bulk_payment_form
    forms.find_by(event_forms: { role: "bulk_payment" })
  end

  def continuing_education_form
    forms.find_by(event_forms: { role: "continuing_education" })
  end

  def active_registration_for(person)
    return nil unless person
    event_registrations.active.find_by(registrant_id: person.id)
  end

  def actively_registered?(person)
    active_registration_for(person).present?
  end

  def ended?
    end_date < Time.current
  end

  # Whether the event shows as a full card on the events index. Unpublished
  # events and events that ended more than a month ago collapse into the compact
  # archive list instead of taking up a card.
  def shown_as_card?
    published? && end_date >= CARD_ARCHIVE_AGE.ago
  end

  def videoconference_window_open?
    return false unless start_date && end_date
    now = Time.current
    now >= start_date - VIDEOCONFERENCE_JOIN_BUFFER && now <= end_date + VIDEOCONFERENCE_JOIN_BUFFER
  end

  # The drip date on the materialized videoconference callout — nil when there's no
  # callout or its date was cleared, in which case the details unlock immediately.
  def videoconference_details_available_from
    return @videoconference_details_available_from if defined?(@videoconference_details_available_from)
    @videoconference_details_available_from =
      registration_ticket_callouts.builtin.find_by(builtin_key: "videoconference")&.display_from
  end

  # Whether the videoconference connection details may be revealed yet. A drip
  # date gates them until it arrives; with no drip date there's nothing to wait
  # on, so they're available immediately (still subject to the per-registration
  # payment gate in EventRegistration#videoconference_details_visible?).
  def videoconference_details_visible?(now = Time.current)
    from = videoconference_details_available_from
    from.blank? || now >= from
  end

  def registerable?
    !ended? && (registration_close_date.nil? || registration_close_date >= Time.current)
  end

  # How many calendar days the event spans (inclusive), clamped to 1..5 — drives
  # how many per-day attendance columns the Onboarding tab shows.
  def day_count
    return 1 if start_date.blank?

    last_day = (end_date.presence || start_date).to_date
    span = (last_day - start_date.to_date).to_i + 1
    span.clamp(1, 5)
  end

  # Attendance sign-in opens this long before a training day's start, so early
  # arrivals can sign in (the CE sheet shows people arriving ~10 min early). Sign-out
  # isn't windowed — an open entry can always be closed, since forgetting to sign out
  # is the common failure.
  ATTENDANCE_SIGN_IN_LEAD = 30.minutes

  # The calendar dates this event runs, inclusive, capped to day_count. Events store
  # only one start_date/end_date, so multi-day events are assumed to run on
  # consecutive days — the same assumption day_count already makes.
  def event_dates
    return [] if start_date.blank?

    first = start_date.in_time_zone(Time.zone).to_date
    (0...day_count).map { |offset| first + offset }
  end

  # Whether the event actually runs past the last day #event_dates covers — day_count
  # is clamped to 5, so a longer event has no sign-in window, no report column and no
  # sheet row past day 5. Both the attendance report (for staff) and the registrant's
  # own sign-in sheet say so rather than silently stopping.
  def event_dates_truncated?
    last_day = end_date&.in_time_zone(Time.zone)&.to_date
    dates = event_dates
    return false unless last_day && dates.any?

    last_day > dates.last
  end

  # A day's start datetime: that date at start_date's time-of-day, in the app zone.
  # Every event day is assumed to start at the same time (the only time we have).
  def daily_start_at(date)
    combine_date_and_time(date, start_date)
  end

  # A day's scheduled end datetime: that date at end_date's time-of-day, in the app
  # zone. Nil when no end time was entered (the form's End time is optional, so
  # end_date lands at midnight) — there's no scheduled end to work from, and each
  # caller decides what to do without one.
  def daily_end_at(date)
    source = end_date.presence || start_date
    return nil if source.blank?

    time = source.in_time_zone(Time.zone)
    return nil if time.hour.zero? && time.min.zero?

    combine_date_and_time(date, source)
  end

  # Whether a registrant may start a new sign-in right now: it's an event day and
  # now falls within [day start − lead, day end]. Sign-out is deliberately not
  # gated by this (see ATTENDANCE_SIGN_IN_LEAD). With no end time on the event the
  # day stays open to its end rather than never opening at all.
  def attendance_sign_in_open?(at = Time.current)
    date = event_dates.find { |d| d == at.in_time_zone(Time.zone).to_date }
    return false unless date

    closes_at = daily_end_at(date) || daily_start_at(date).end_of_day
    at.between?(daily_start_at(date) - ATTENDANCE_SIGN_IN_LEAD, closes_at)
  end

  # When sign-in next becomes available — the earliest upcoming day's window opening
  # (day start − lead). Nil once the last day's window has already opened (or passed).
  def next_attendance_sign_in_opens_at(at = Time.current)
    event_dates
      .map { |date| daily_start_at(date) - ATTENDANCE_SIGN_IN_LEAD }
      .find { |opens_at| opens_at > at }
  end

  def time_title
    "(#{ start_text }) #{ name }"
  end

  # Like time_title but date only — no time or parens — for filter dropdowns.
  def date_title
    start_date ? "#{start_date.to_date.iso8601} — #{name}" : name
  end

  def full_name
    "#{ name } (#{ start_text })"
  end

  def start_text
    start_date.strftime("%Y-%m-%d @ %I:%M %p")
  end

  def name
    title
  end

  # The CE hours callout's admin-edited heading, read from its materialized row's
  # title (that's where the label lives now the ce_hours_details_label column is
  # gone). Falls back to the default so the CE card/mailer never render unlabelled.
  def ce_hours_label
    registration_ticket_callouts.find_by(builtin_key: "ce_hours")&.title.presence || "CE hours"
  end

  # Virtual attributes for date/time inputs (Firefox datetime-local compat)
  attr_writer :start_date_date, :start_date_time,
              :end_date_date, :end_date_time,
              :registration_close_date_date, :registration_close_date_time,
              :ce_payment_due_deadline_date, :ce_payment_due_deadline_time,
              :payment_due_deadline_date, :payment_due_deadline_time

  def start_date_date
    @start_date_date || start_date&.strftime("%Y-%m-%d")
  end

  def start_date_time
    @start_date_time || start_date&.strftime("%H:%M")
  end

  def end_date_date
    @end_date_date || end_date&.strftime("%Y-%m-%d")
  end

  def end_date_time
    @end_date_time || end_date&.strftime("%H:%M")
  end

  def registration_close_date_date
    @registration_close_date_date || registration_close_date&.strftime("%Y-%m-%d")
  end

  def registration_close_date_time
    @registration_close_date_time || registration_close_date&.strftime("%H:%M")
  end

  def ce_payment_due_deadline_date
    @ce_payment_due_deadline_date || ce_payment_due_deadline&.strftime("%Y-%m-%d")
  end

  def ce_payment_due_deadline_time
    @ce_payment_due_deadline_time || ce_payment_due_deadline&.strftime("%H:%M")
  end

  def payment_due_deadline_date
    @payment_due_deadline_date || payment_due_deadline&.strftime("%Y-%m-%d")
  end

  def payment_due_deadline_time
    @payment_due_deadline_time || payment_due_deadline&.strftime("%H:%M")
  end

  # Virtual attribute for cost in dollars (converts to/from cost_cents)
  def cost
    return nil if cost_cents.nil?
    cost_cents / 100.0
  end

  def cost=(dollar_amount)
    if dollar_amount.blank?
      self.cost_cents = nil
    else
      dollar_amount = dollar_amount.to_s.gsub(/[^\d.]/, "").to_f
      self.cost_cents = (dollar_amount.to_f * 100).round
    end
  end

  # Virtual attribute for the total CE cost in dollars (converts to/from
  # ce_hours_cost_cents), mirroring #cost.
  def ce_hours_cost
    return nil if ce_hours_cost_cents.nil?
    ce_hours_cost_cents / 100.0
  end

  def ce_hours_cost=(dollar_amount)
    if dollar_amount.blank?
      self.ce_hours_cost_cents = nil
    else
      dollar_amount = dollar_amount.to_s.gsub(/[^\d.]/, "").to_f
      self.ce_hours_cost_cents = (dollar_amount * 100).round
    end
  end

  # An event grants CE credit when it offers a positive number of hours. Derived
  # from ce_hours_offered rather than a separate stored flag, so there's a single
  # source of truth.
  def ce_eligible?
    ce_hours_offered.to_f.positive?
  end

  def scholarship_eligible?
    cost_cents.to_i.positive? || scholarship_form.present?
  end

  def attachable_content_type
    "application/vnd.active_record.event"
  end

  def to_attachable_partial_path
    "events/registration_button"
  end

  def to_trix_content_attachment_partial_path
    "events/registration_button"
  end

  def to_partial_path
    "events/registration_button"
  end

  private

  def merge_date_time_fields
    merge_date_time(:start_date)
    merge_date_time(:end_date)
    merge_date_time(:registration_close_date)
    merge_date_time(:ce_payment_due_deadline)
    merge_date_time(:payment_due_deadline)
  end

  def merge_date_time(field)
    date_val = send(:"#{field}_date")
    time_val = send(:"#{field}_time")
    self[field] = build_datetime(date_val, time_val)
  end

  # Combine a Date with the time-of-day of a datetime source, in the app zone —
  # e.g. "day 2's date" + "the event's 9:00am start" → that day at 9:00am.
  def combine_date_and_time(date, source)
    time = source.in_time_zone(Time.zone)
    Time.zone.local(date.year, date.month, date.day, time.hour, time.min)
  end

  def build_datetime(date_str, time_str)
    return nil if date_str.blank? && time_str.blank?
    return Time.zone.parse(date_str) if date_str.present? && time_str.blank?
    return Time.zone.parse("2000-01-01 #{time_str}") if date_str.blank? && time_str.present?
    Time.zone.parse("#{date_str} #{time_str}")
  end

  def registration_form_required_when_publicly_registerable
    return unless public_registration_enabled?
    return if will_save_change_to_public_registration_enabled?
    return if event_forms.registration.exists?

    errors.add(:public_registration_enabled, "requires a registration form to be selected")
  end

  # The event_staffs unique index catches duplicates already persisted, but two
  # new rows for the same person in one submission both pass the per-record
  # uniqueness check (neither is saved yet) and would hit the index on save.
  def staff_members_are_unique
    person_ids = event_staffs.reject(&:marked_for_destruction?).filter_map(&:person_id)
    return if person_ids.uniq.length == person_ids.length

    errors.add(:base, "A person can only be added to the staff once.")
  end

  def public_registration_just_enabled?
    public_registration_enabled? && saved_change_to_public_registration_enabled?
  end

  def build_public_registration_form
    return if event_forms.registration.exists?

    form_name = title&.match?(/training/i) ? "Extended Event Registration" : "Short Event Registration"
    form = Form.standalone.find_by(name: form_name)
    return unless form

    event_forms.create!(form: form, role: "registration")
  end
end
