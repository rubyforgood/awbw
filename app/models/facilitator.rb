class Facilitator < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
  has_one :user, inverse_of: :facilitator, dependent: :nullify
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  has_many :sectors, through: :sectorable_items
  has_many :stories_as_spotlighted_facilitator, inverse_of: :spotlighted_facilitator, class_name: "Story",
           dependent: :restrict_with_error
  # Image associations
  has_one :avatar_image, -> { where(type: "Images::SquareImage") },
          as: :owner, class_name: "Images::SquareImage",
          dependent: :destroy# new active storage

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true

  CONTACT_TYPES = [nil, "Work", "Personal"].freeze
  validates :primary_email_address_type, inclusion: {in: CONTACT_TYPES}
  validates :mailing_address_type, inclusion: {in: CONTACT_TYPES}
  validates :phone_number_type, inclusion: {in: CONTACT_TYPES}
  # TODO: add validation for zip code containing only numbers
  # TODO: add validation on STATE
  # TODO: add validation on phone number type

  # Nested attributes
  accepts_nested_attributes_for :avatar_image, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :sectorable_items, allow_destroy: true,
                                reject_if: proc { |attrs| attrs['sector_id'].blank? }
  accepts_nested_attributes_for :user, update_only: true

  # Search Cop
  include SearchCop
  search_scope :search do
    attributes :first_name, :last_name, :phone_number, :primary_email_address
    attributes user_first_name: "user.first_name"
    attributes user_last_name:  "user.last_name"
    attributes user_email:      "user.email"
    attributes user_phone:      "user.phone"
  end

  scope :searchable, -> { where(profile_is_searchable: true) }
  scope :project_name, ->(project_name) {
    return all if project_name.blank?
    left_joins(user: { project_users: :project })
      .where("projects.name LIKE ?", "%#{sanitize_sql_like(project_name)}%")
      .distinct
  }
  scope :sector_name, ->(sector_name) {
    return all if sector_name.blank?
    left_joins(sectorable_items: :sector)
      .where("sectors.name LIKE ?", "%#{sanitize_sql_like(sector_name)}%")
      .distinct
  }

  def self.search_by_params(params)
    results = self.all
    results = results.search(params[:contact_info]) if params[:contact_info].present?
    results = results.sector_name(params[:sector_name]) if params[:sector_name].present?
    results = results.project_name(params[:project_name]) if params[:project_name].present?
    results
  end

  def sector_list
    sectors.pluck(:name)
  end

  def name
    case display_name_preference
    when "full_name"
      user.full_name
    when "first_name_last_initial"
      "#{user.first_name} #{user.last_name.first}"
    when "first_name_only"
      user.first_name
    when "last_name_only"
      user.last_name
    else
      user.full_name
    end
  end

  def full_name
    user.full_name
  end
end
