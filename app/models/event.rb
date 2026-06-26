class Event < ApplicationRecord
  include Featureable, Publishable, TagFilterable, Trendable, WindowsTypeFilterable
  include ActionText::Attachable
  include RemoteSearchable

  # Grace window on either side of the event during which the videoconference
  # link is available to paid registrants.
  VIDEOCONFERENCE_JOIN_BUFFER = 30.minutes

  # How far ahead of the start the videoconference connection details (join link,
  # meeting ID, passcode) may be shared. Kept hidden until then so the link isn't
  # exposed — on the ticket, the videoconference page, or in calendar entries —
  # more than a week in advance.
  VIDEOCONFERENCE_DETAILS_LEAD = 7.days

  has_rich_text :rhino_header
  has_rich_text :rhino_description

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :location, optional: true
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :event_registrations, dependent: :destroy
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
    reject_if: proc { |attrs| attrs["title"].blank? }

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
  scope :staffed_by, ->(person) { joins(:event_staffs).where(event_staffs: { person_id: person }).distinct }
  # Events flagged as facilitator trainings (the "TAC" a scholarship recipient
  # attends). Drives the scholarship index's training column.
  scope :facilitator_trainings, -> { where(facilitator_training: true) }

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

  def videoconference_window_open?
    return false unless start_date && end_date
    now = Time.current
    now >= start_date - VIDEOCONFERENCE_JOIN_BUFFER && now <= end_date + VIDEOCONFERENCE_JOIN_BUFFER
  end

  # Whether the videoconference connection details may be revealed yet: only once
  # the event is within VIDEOCONFERENCE_DETAILS_LEAD of starting.
  def videoconference_details_visible?
    return false unless start_date
    Time.current >= start_date - VIDEOCONFERENCE_DETAILS_LEAD
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

  def time_title
    "(#{ start_text }) #{ name }"
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

  # Heading shown on the ticket call-out and the details page. Falls back to the
  # default even when an admin clears it, so the section never renders unlabelled.
  def event_details_label
    super.presence || "Before you attend"
  end

  # Heading shown on the CE hours ticket call-out and its details page. Falls
  # back to the default even when an admin clears it, so the section never
  # renders unlabelled.
  def ce_hours_details_label
    super.presence || "CE hours"
  end

  # Per-hour CE price in cents. Falls back to the standard rate when no per-event
  # override is set, so new and existing events both bill the default until an
  # admin changes it.
  def ce_hour_cost_cents
    super || ContinuingEducationRegistration::HOURLY_RATE_DOLLARS * 100
  end

  # What a registrant owes to earn this training's CE hours: the available hours
  # times the per-hour rate. Zero when the event grants no CE hours.
  def ce_amount_owed_cents
    return 0 if ce_hours.blank?

    (ce_hours * ce_hour_cost_cents).round
  end

  # Virtual attributes for date/time inputs (Firefox datetime-local compat)
  attr_writer :start_date_date, :start_date_time,
              :end_date_date, :end_date_time,
              :registration_close_date_date, :registration_close_date_time

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

  # Virtual attribute for the CE hourly cost in dollars (converts to/from
  # ce_hour_cost_cents), mirroring #cost. Reads back the default rate when unset
  # so the event form shows the standard rate for new and existing events.
  def ce_hour_cost
    ce_hour_cost_cents / 100.0
  end

  def ce_hour_cost=(dollar_amount)
    if dollar_amount.blank?
      self.ce_hour_cost_cents = nil
    else
      dollar_amount = dollar_amount.to_s.gsub(/[^\d.]/, "").to_f
      self.ce_hour_cost_cents = (dollar_amount * 100).round
    end
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
  end

  def merge_date_time(field)
    date_val = send(:"#{field}_date")
    time_val = send(:"#{field}_time")
    self[field] = build_datetime(date_val, time_val)
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
