RailsAdmin.config do |config|
  config.model Report do
    object_label_method do
      :users_admin_type
    end
  end
end
class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :recoverable,
         :rememberable, :trackable, :validatable
  # Avatar
  has_attached_file :avatar, styles: { medium: "300x300>", thumb: "100x100>" }, default_url: "/images/missing.png"
  validates_attachment_content_type :avatar, content_type: /\Aimage\/.*\z/

  # Associations
  has_many :workshops

  # has_many :curriculum_workshops, -> (user) {  }, class_name: 'Workshop'
  has_many :workshop_logs
  has_many :reports
  has_many :communal_reports, through: :projects, source: :reports
  has_many :bookmarks, dependent: :destroy
  has_many :bookmarked_workshops, through: :bookmarks, source: :bookmarkable, source_type: 'Workshop'
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

  # Rails Admin
  rails_admin do
    exclude_fields :reset_password_sent_at, :remember_created_at, :sign_in_count,
                   :current_sign_in_at, :last_sign_in_at, :current_sign_in_ip,
                   :last_sign_in_ip, :reset, :workshops, :workshop_logs,
                   :bookmarks, :projects, :permissions, :user_permissions, :colleagues,
                   :notifications, :user_form_form_fields, :resources, :communal_reports,
                   :user_forms, :windows_types, :birthday
    field :reports do
      label do
        'Communal Reports'
      end
    end

    edit do
      include_fields :first_name, :last_name, :email, :password, :password_confirmation, :reset_password_token
      group 'More Fields' do
        active false
        field :agency_id
        field :phone
        field :address
        field :city
        field :state
        field :zip
        field :subscribecode
        field :comment
        field :notes
        field :legacy
        field :legacy_id
        field :confirmed
        field :phone2
        field :phone3
        field :best_time_to_call
        field :address2
        field :city2
        field :state2
        field :zip2
        field :primary_address
        field :avatar
      end
    end

    list do
      field :password do
        filterable false
        visible false
      end
      field :password_confirmation do
        filterable false
        visible false
      end
      field :reset_password_token do
        filterable false
        visible false
      end
      field :agency_id do
        filterable false
        visible false
      end
      field :phone do
        filterable false
        visible false
      end
      field :address do
        filterable false
        visible false
      end
      field :city do
        filterable false
        visible false
      end
      field :state do
        filterable false
        visible false
      end
      field :zip do
        filterable false
        visible false
      end
      field :subscribecode do
        filterable false
        visible false
      end
      field :comment do
        filterable false
        visible false
      end
      field :notes do
        filterable false
        visible false
      end
      field :legacy do
        filterable false
        visible false
      end
      field :legacy_id do
        filterable false
        visible false
      end
      field :confirmed do
        filterable false
        visible false
      end
      field :phone2 do
        filterable false
        visible false
      end
      field :phone3 do
        filterable false
        visible false
      end
      field :best_time_to_call do
        filterable false
        visible false
      end
      field :address2 do
        filterable false
        visible false
      end
      field :city2 do
        filterable false
        visible false
      end
      field :state2 do
        filterable false
        visible false
      end
      field :zip2 do
        filterable false
        visible false
      end
      field :primary_address do
        filterable false
        visible false
      end
      field :avatar do
        filterable false
        visible false
      end
    end
  end

  # Nested
  accepts_nested_attributes_for :user_forms
  accepts_nested_attributes_for :project_users, reject_if: :all_blank, allow_destroy: true

  # Validations
  # validates :first_name, :last_name, presence: true

  after_create :set_default_values

  before_destroy { |record|
    orphaned_user = User.find_by(email: "orphaned_reports@awbw.org")
    orphaned_user.reports << record.reports unless record.reports.nil?
    orphaned_user.workshop_logs << record.workshop_logs unless record.workshop_logs.nil?
  }

  def has_liasion_position_for?(project_id)
    !project_users.where(project_id: project_id, position: 1).first.nil?
  end

  def active_for_authentication?
    super && !self.inactive?
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

  def recent_activity(limit=4)
    recent_activity  = workshops.where(inactive: true).last(10)
    recent_activity += workshop_logs.last(10)
    recent_activity += reports.where('owner_type = "MonthlyReport"').
                       last(10)
    recent_activity += reports.where('owner_id = "7"').
                       last(10)

    recent_activity.sort{|x,y| y.created_at <=> x.created_at}[0..(limit - 1)]
  end

  def liaison_in_projects?(projects)
    (liaison_project_ids & projects.map(&:id)).any?
  end

  def liaison?
    liaison_project_ids.count > 0
  end

  def project_monthly_workshop_logs(date, *windows_type)
    where = windows_type.map do |wt| 'windows_type_id = ?' end

    logs = projects.map do |project|
      project.workshop_logs.where(where.join(' OR '), *windows_type)
    end.flatten
    logs = logs.select do |log|
      log.date && log.date.month == date.month.to_i && \
      log.date.year == date.year.to_i
    end.flatten
    logs.uniq.group_by { |log| log.date }
  end

  def project_workshop_logs(date, windows_type, project_id)
   if project_id
      logs = workshop_logs.where(project_id: project_id, windows_type_id: windows_type.id)
      logs = logs.select do |log|
        log.date && log.date.month == date.month.to_i && \
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

  def curriculum(klass = Workshop)
    results = klass.joins(:windows_type)
    results = results.where('windows_types.name IN (?) and inactive is false', permissions_list)

    results = results.where(kind: ['Template','Handout', 'Scholarship',
                                   'Toolkit', 'Form', 'Resource']) if klass == Resource

    results
  end

  def name
    return email if !first_name || first_name.empty?
    "#{first_name} #{last_name}"
  end

  def agency_name
   agency ? agency.name : 'No agency.'
  end

  def has_bookmarked_workshop?(workshop)
    bookmarked_workshop_ids.include?(workshop.id)
  end

  def bookmarked_workshop_ids
    bookmarked_workshops.pluck(:id)
  end

  private

  def liaison_project_ids
    project_users.liaisons.pluck(:project_id)
  end

  def set_default_values
    update(inactive: false)
    combined_perm = Permission.find_by(security_cat: "Combined Adult and Children's Windows")
    adult_perm = Permission.find_by(security_cat: "Adult Windows")
    children_perm = Permission.find_by(security_cat: "Children's Windows")


    self.permissions << combined_perm
    self.permissions << adult_perm
    self.permissions << children_perm
  end
end
