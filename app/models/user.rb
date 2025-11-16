class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :recoverable,
    :rememberable, :trackable, :validatable

  after_create :set_default_values
  before_destroy :reassign_reports_and_logs_to_orphaned_user

  # Avatar
  ACCEPTED_CONTENT_TYPES = ["image/jpeg", "image/png"].freeze
  has_one_attached :avatar
  validates :avatar, content_type: ACCEPTED_CONTENT_TYPES

  # Associations
  belongs_to :facilitator, optional: true
  has_many :workshops
  has_many :workshop_logs
  has_many :reports
  has_many :communal_reports, through: :projects, source: :reports
  has_many :bookmarks, dependent: :destroy
  has_many :bookmarked_workshops, through: :bookmarks, source: :bookmarkable, source_type: "Workshop"
  has_many :bookmarked_resources, through: :bookmarks, source: :bookmarkable, source_type: "Resource"
  has_many :bookmarked_events, through: :bookmarks, source: :bookmarkable, source_type: "Event"
  has_many :project_users, dependent: :destroy
  has_many :projects, through: :project_users
  has_many :windows_types, through: :projects
  has_many :user_permissions, dependent: :destroy
  has_many :permissions, through: :user_permissions
  has_many :resources
  has_many :user_forms, dependent: :destroy
  has_many :user_form_form_fields, through: :user_forms, dependent: :destroy
  has_many :colleagues, -> { select(:user_id, :position, :project_id).distinct }, through: :projects, source: :project_users
  has_many :notifications, as: :noticeable
  has_many :event_registrations, foreign_key: :registrant_id, dependent: :destroy
  has_many :events, through: :event_registrations

  has_many :stories_as_creator, foreign_key: :created_by_id, class_name: "Story"
  has_many :story_ideas_as_creator, foreign_key: :created_by_id, class_name: "StoryIdea"
  has_many :workshop_variations_as_creator, foreign_key: :created_by_id, class_name: "WorkshopVariation"
  has_many :workshops_as_creator, foreign_key: :created_by_id, class_name: "Workshop"

  # Nested
  accepts_nested_attributes_for :user_forms
  accepts_nested_attributes_for :project_users,
    reject_if: proc { |attrs| attrs["organization_id"].blank? },
    allow_destroy: true

  # Validations
  validates :first_name, :last_name, presence: true
  validates :email, presence: true, uniqueness: {case_sensitive: false}

  # Search Cop
  include SearchCop
  search_scope :search do
    attributes [:email, :first_name, :last_name, :phone]
    attributes user: "projects.name"
  end

  scope :active, -> { where(inactive: false) }

  def self.search_by_params(params)
    results = User.all
    results = results.search(params[:search]) if params[:search].present?
    results = results.where(super_user: params[:super_user]) if params[:super_user].present?
    results = results.where(inactive: params[:inactive]) if params[:inactive].present?
    results
  end

  def has_liasion_position_for?(project_id)
    !project_users.where(project_id: project_id, position: 1).first.nil?
  end

  def active_for_authentication?
    super && !inactive?
  end

  def bookmark_for(record)
    bookmarks.find_by(bookmarkable: record)
  end

  def full_name
    if !first_name || first_name.empty?
      email
    else
      "#{first_name} #{last_name}"
    end
  end

  def submitted_monthly_report(submitted_date = Date.today, windows_type, project_id)
    Report.where(project_id: project_id, type: "MonthlyReport", date: submitted_date,
      windows_type: windows_type).last
  end

  def recent_activity(activity_limit = 10)
    recent = []

    # recent.concat(events.order(updated_at: :desc).limit(activity_limit))
    recent.concat(workshops.order(updated_at: :desc).limit(activity_limit))
    recent.concat(workshop_logs.order(updated_at: :desc).limit(activity_limit))
    recent.concat(workshop_variations_as_creator.order(updated_at: :desc).limit(activity_limit))
    # recent.concat(stories.order(updated_at: :desc).limit(activity_limit))
    # recent.concat(quotes.order(updated_at: :desc).limit(activity_limit))
    recent.concat(resources.order(updated_at: :desc).limit(activity_limit))
    recent.concat(reports.where(owner_type: "MonthlyReport").order(updated_at: :desc).limit(activity_limit))
    recent.concat(reports.where(owner_id: 7).order(updated_at: :desc).limit(activity_limit)) # TODO: remove hard-coded

    # Sort by the most recent timestamp (updated_at preferred, fallback to created_at)
    recent.sort_by { |item| item.try(:updated_at) || item.created_at }.reverse.first(activity_limit * 8)
  end

  def liaison_in_projects?(projects)
    (liaison_project_ids & projects.map(&:id)).any?
  end

  def project_monthly_workshop_logs(date, *windows_type)
    where = windows_type.map { |wt| "windows_type_id = ?" }

    logs = projects.map do |project|
      project.workshop_logs.where(where.join(" OR "), *windows_type)
    end.flatten
    logs = logs.select do |log|
      log.date && log.date.month == date.month.to_i &&
        log.date.year == date.year.to_i
    end.flatten
    logs.uniq.group_by { |log| log.date }
  end

  def project_workshop_logs(date, windows_type, project_id)
    if project_id
      logs = workshop_logs.where(project_id: project_id, windows_type_id: windows_type.id)
      logs = logs.select do |log|
        log.date && log.date.month == date.month.to_i &&
          log.date.year == date.year.to_i
      end.flatten
      logs.uniq.group_by { |log| log.date }
    end
  end

  def permissions_list
    security_list = permissions.pluck(:security_cat)
    result = []

    result << "ADULT WORKSHOP LOG" if security_list.include? "Adult Windows"
    result << "CHILDREN WORKSHOP LOG" if security_list.include? "Children's Windows"
    result << "ADULT & CHILDREN COMBINED (FAMILY) LOG" if security_list.include? "Combined Adult and Children's Windows"

    result
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

  private

  def liaison_project_ids
    project_users.liaisons.pluck(:project_id)
  end

  def set_default_values
    self.inactive = false if inactive.nil?
    self.confirmed = true if confirmed.nil?

    combined_perm = Permission.find_by(security_cat: "Combined Adult and Children's Windows")
    adult_perm = Permission.find_by(security_cat: "Adult Windows")
    children_perm = Permission.find_by(security_cat: "Children's Windows")

    permissions << combined_perm
    permissions << adult_perm
    permissions << children_perm
  end

  def reassign_reports_and_logs_to_orphaned_user
    orphaned_user = User.find_by(email: "orphaned_reports@awbw.org")
    return unless orphaned_user

    # Reassign reports
    reports.update_all(user_id: orphaned_user.id)

    # Reassign workshop_logs
    workshop_logs.update_all(user_id: orphaned_user.id)
  end
end
