class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :recoverable,
    :rememberable, :trackable, :validatable

  after_create :set_default_values
  after_update :track_email_change
  after_update :track_login_event

  before_destroy :track_account_deleted
  before_destroy :reassign_reports_and_logs_to_orphaned_user

  # Associations
  belongs_to :person, optional: true
  has_many :bookmarks, dependent: :destroy
  has_many :event_registrations, foreign_key: :registrant_id, dependent: :destroy
  has_many :notifications, as: :noticeable

  has_many :reports
  has_many :resources
  has_many :user_forms, dependent: :destroy
  has_many :workshops
  has_many :workshop_logs

  # created_by associations
  has_many :stories_as_creator, foreign_key: :created_by_id, class_name: "Story"
  has_many :story_ideas_as_creator, foreign_key: :created_by_id, class_name: "StoryIdea"
  has_many :workshops_as_creator, foreign_key: :created_by_id, class_name: "Workshop"
  has_many :workshop_ideas_as_creator, foreign_key: :created_by_id, class_name: "WorkshopIdea"
  has_many :workshop_variations_as_creator, foreign_key: :created_by_id, class_name: "WorkshopVariation"
  has_many :workshop_variation_ideas_creator, foreign_key: :created_by_id, class_name: "WorkshopVariationIdea"

  # has_many through
  has_many :bookmarked_workshops, through: :bookmarks, source: :bookmarkable, source_type: "Workshop"
  has_many :bookmarked_resources, through: :bookmarks, source: :bookmarkable, source_type: "Resource"
  has_many :bookmarked_events, through: :bookmarks, source: :bookmarkable, source_type: "Event"

  has_many :events, through: :event_registrations

  has_many :user_form_form_fields, through: :user_forms, dependent: :destroy
  # Images
  has_one_attached :avatar

  # Nested attributes
  accepts_nested_attributes_for :user_forms


  # Validations
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validate :time_zone_must_be_valid, if: :time_zone_changed?
  validate :person_id_must_be_present_if_previously_set, on: :update
  validates_associated :person, if: -> { person.present? }


  # Search Cop
  include SearchCop
  search_scope :search do
    attributes [ :email, :first_name, :last_name, :phone ]
    attributes user: "organizations.name"
  end

  scope :active, -> { where(inactive: false) }

  def self.search_by_params(params)
    results = is_a?(ActiveRecord::Relation) ? self : all
    results = results.search(params[:search]) if params[:search].present?
    results = results.where(super_user: params[:super_user]) if params[:super_user].present?
    results = results.where(inactive: params[:inactive]) if params[:inactive].present?
    results
  end

  # TODO Remove once all view's use ActionPolicy
  def admin?
    super_user
  end



  def active_for_authentication?
    super && !inactive?
  end

  def bookmark_for(record)
    bookmarks.find_by(bookmarkable: record)
  end

  def full_name
    if person
      person.full_name
    else
      if !first_name || first_name.empty?
        email
      else
        "#{first_name} #{last_name}"
      end
    end
  end

  def devise_email_name
    person&.first_name.presence || first_name.presence || email
  end

  def submitted_monthly_report(submitted_date = Date.today, windows_type, organization_id)
    Report.where(organization_id: organization_id, type: "MonthlyReport", date: submitted_date,
      windows_type: windows_type).last
  end

  def recent_activity(activity_limit = 10)
    recent = []

    # recent.concat(events.order(updated_at: :desc).limit(activity_limit))
    recent.concat(bookmarks.order(updated_at: :desc).limit(activity_limit))
    recent.concat(workshops.order(updated_at: :desc).limit(activity_limit))
    recent.concat(workshop_logs.order(updated_at: :desc).limit(activity_limit))
    recent.concat(workshop_variations_as_creator.order(updated_at: :desc).limit(activity_limit))
    recent.concat(stories_as_creator.order(updated_at: :desc).limit(activity_limit))
    # recent.concat(quotes.order(updated_at: :desc).limit(activity_limit))
    recent.concat(resources.order(updated_at: :desc).limit(activity_limit))
    recent.concat(reports.where(owner_type: "MonthlyReport").order(updated_at: :desc).limit(activity_limit))
    recent.concat(reports.where(owner_id: 7).order(updated_at: :desc).limit(activity_limit)) # TODO: remove hard-coded

    # Sort by the most recent timestamp (updated_at preferred, fallback to created_at)
    recent.sort_by { |item| item.try(:updated_at) || item.created_at }.reverse.first(activity_limit * 8)
  end

  def organization_monthly_workshop_logs(date, *windows_type)
    where = windows_type.map { |wt| "windows_type_id = ?" }

    logs = organizations.map do |organization|
      organization.workshop_logs.where(where.join(" OR "), *windows_type)
    end.flatten
    logs = logs.select do |log|
      log.date && log.date.month == date.month.to_i &&
        log.date.year == date.year.to_i
    end.flatten
    logs.uniq.group_by { |log| log.date }
  end

  def organization_workshop_logs(date, windows_type, organization_id)
    if organization_id
      logs = workshop_logs.where(organization_id: organization_id, windows_type_id: windows_type.id)
      logs = logs.select do |log|
        log.date && log.date.month == date.month.to_i &&
          log.date.year == date.year.to_i
      end.flatten
      logs.uniq.group_by { |log| log.date }
    end
  end

  def name
    return email if !first_name || first_name.empty?
    "#{first_name} #{last_name}"
  end

  def agency_name
    agency ? agency.name : "No agency."
  end

  def has_bookmarkable?(bookmarkable, type: nil)
    bookmarkable_ids(bookmarkable_type: type || bookmarkable.object.class.name).include?(bookmarkable.id)
  end

  def bookmarkable_ids(bookmarkable_type:)
    public_send("bookmarked_#{bookmarkable_type.downcase.pluralize}")
      .pluck(:id)
  end

  def primary_asset # method needed for idea_submission_fyi mailer
  end

  def gallery_assets # method needed for idea_submission_fyi mailer
    []
  end

  private

  def time_zone_must_be_valid
    return if ActiveSupport::TimeZone[time_zone]

    errors.add(:time_zone, "is not a valid time zone")
  end

  def person_id_must_be_present_if_previously_set
    return unless person_id_was.present?
    return if person_id.present?

    errors.add(:person_id, "cannot be removed once set")
  end

  def set_default_values
    self.inactive = false if inactive.nil?
    self.confirmed = true if confirmed.nil?
  end

  def reassign_reports_and_logs_to_orphaned_user
    orphaned_user = User.find_by(email: "orphaned_reports@awbw.org")
    return unless orphaned_user

    # Reassign reports
    reports.update_all(user_id: orphaned_user.id)

    # Reassign workshop_logs
    workshop_logs.update_all(user_id: orphaned_user.id)
  end

  def after_confirmation
    super
    track_auth_event("auth.account_confirmed")
  end

  def after_lock
    super
    track_auth_event("auth.account_locked")
  end

  def after_unlock
    super
    track_auth_event("auth.account_unlocked")
  end

  def track_account_deleted
    track_auth_event("auth.account_deleted")
  end

  def track_auth_event(name, properties = {})
    payload = { name: name, properties: properties.merge(user_id: id) }
    Analytics::LifecycleBuffer.push(payload)
  end

  def track_email_change
    return unless saved_change_to_email?
    track_auth_event("auth.email_changed")
  end

  def track_login_event
    return unless saved_change_to_sign_in_count?

    track_auth_event("auth.login", {
      sign_in_count: sign_in_count
    })
  end
end
