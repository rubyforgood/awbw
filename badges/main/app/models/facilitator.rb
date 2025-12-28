class Facilitator < ApplicationRecord
  include TagFilterable, Trendable, ViewCountable, WindowsTypeFilterable

  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"

  has_one :user, inverse_of: :facilitator, dependent: :nullify

  has_many :addresses, as: :addressable, dependent: :destroy
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :contact_methods, as: :contactable, dependent: :destroy
  has_many :categorizable_items, inverse_of: :categorizable, as: :categorizable, dependent: :destroy
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  has_many :stories_as_spotlighted_facilitator, inverse_of: :spotlighted_facilitator, class_name: "Story",
           dependent: :restrict_with_error
  # has_many through
  has_many :event_registrations, through: :user
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items


  # Image associations
  has_one :avatar_image, -> { where(type: "Images::SquareImage") },
          as: :owner, class_name: "Images::SquareImage",
          dependent: :destroy# new active storage

  # Validations
  validates :first_name, presence: true
  validates :last_name, presence: true

  CONTACT_TYPES = ["work", "personal"].freeze
  validates :email_type, inclusion: { in: %w[work personal] }, allow_blank: true
  validates :email_2_type, inclusion: { in: %w[work personal] }, allow_blank: true
  # TODO: add validation for zip code containing only numbers
  # TODO: add validation on STATE
  # TODO: add validation on phone number type

  # Nested attributes
  accepts_nested_attributes_for :addresses, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :avatar_image, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :contact_methods, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :sectorable_items, allow_destroy: true,
                                reject_if: proc { |attrs| attrs['sector_id'].blank? }
  accepts_nested_attributes_for :user, update_only: true

  # Search Cop
  include SearchCop
  search_scope :search do
    attributes :first_name, :last_name, :email, :email_2
    attributes user_first_name: "user.first_name"
    attributes user_last_name:  "user.last_name"
    attributes user_email:      "user.email"
    attributes user_phone:      "user.phone"
    attributes contact_methods_phone: "contact_methods.value"
  end

  scope :active, -> { all } # TODO - implement inactive field
  scope :by_most_viewed, ->(limit = 10) { order(view_count: :desc).limit(limit) }
  scope :published, -> { active.searchable }
  scope :published, ->(published=nil) { published ? active.searchable(published) : active.searchable }
  scope :searchable, ->(searchable=nil) { searchable ? where(profile_is_searchable: searchable) : where(profile_is_searchable: true) }
  scope :project_name, ->(project_name) {
    return all if project_name.blank?
    left_joins(user: { project_users: :project })
      .where("projects.name LIKE ?", "%#{sanitize_sql_like(project_name)}%")
      .distinct }
  scope :category_names, ->(names) { tag_names(:categories, names) }
  scope :sector_names,   ->(names) { tag_names(:sectors, names) }

  def self.search_by_params(params)
    results = self.all
    results = results.search(params[:contact_info]) if params[:contact_info].present?
    results = results.sector_names(params[:sector_names]) if params[:sector_names].present?
    results = results.sector_names(params[:category_names]) if params[:category_names].present?
    results = results.project_name(params[:project_name]) if params[:project_name].present?
    results = results.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    results
  end

  def sector_list
    sectors.pluck(:name)
  end

  def name
    case display_name_preference
    when "full_name"
      full_name
    when "first_name_last_initial"
      "#{first_name} #{last_name.first}"
    when "first_name_only"
      first_name
    when "last_name_only"
      last_name
    else
      full_name
    end
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def phone_number
    primary_phone = contact_methods.find_by(is_primary: true, inactive: false, kind: :phone)
    return primary_phone.value if primary_phone.present?

    first_phone = contact_methods.where(kind: :phone, inactive: false).first
    return first_phone.value if first_phone.present?

    nil
  end
end
