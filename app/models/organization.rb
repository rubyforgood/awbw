class Organization < ApplicationRecord
  include RemoteSearchable, TagFilterable, Trendable, WindowsTypeFilterable, SectorsTaggable, AgeGroupTaggable # Publishable
  belongs_to :organization_status
  belongs_to :organization_obligation, optional: true
  belongs_to :location, optional: true # TODO - remove Location if unused
  belongs_to :windows_type, optional: true
  has_many :addresses, as: :addressable, dependent: :destroy
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :affiliations, dependent: :restrict_with_error
  has_many :event_registration_organizations, dependent: :restrict_with_error
  has_many :event_registrations, through: :event_registration_organizations
  has_many :people, through: :affiliations
  has_many :users, through: :people
  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy
  has_many :reports
  has_many :workshop_logs
  has_many :grants, as: :donor, dependent: :destroy

  has_many :categorizable_items, dependent: :destroy, inverse_of: :categorizable, as: :categorizable
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  # has_many through
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items
  has_many :workshops, through: :users

  # Asset associations
  has_one_attached :logo, dependent: :purge do |attachable|
    attachable.variant :thumbnail,
      resize_to_limit: [ 256, 256 ],
      format: :webp,
      saver: { quality: 80 }
  end

  # Validations
  validates :logo,
            content_type: %w[image/png image/jpeg image/webp],
            size: { less_than: 5.megabytes }
  validates :name, presence: true
  validates :organization_status_id, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_blank: true
  validate :affiliation_dates_locked, if: -> { affiliations.any? && !Current.user&.super_user? }

  # Nested attributes
  accepts_nested_attributes_for :addresses, allow_destroy: true,
                                reject_if: proc { |attrs| attrs.slice("locality", "city", "state", "street_address", "zip_code").values.all?(&:blank?) }
  accepts_nested_attributes_for :sectorable_items, allow_destroy: true,
                                reject_if: proc { |attrs| attrs["sector_id"].blank? }
  after_save :remove_duplicate_sectorable_items
  accepts_nested_attributes_for :affiliations, allow_destroy: true,
                                reject_if: proc { |attrs| attrs["person_id"].blank? }
  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attrs| attrs["body"].blank? }

  # SearchCop
  include SearchCop
  search_scope :search do
    attributes :name
  end

  # Scopes
  # See TagFilterable, Trendable, WindowsTypeFilterable
  scope :active, -> {
    status_active = joins(:organization_status).where(organization_statuses: { name: "Active" })
    affiliation_active = where(id: Affiliation.active.select(:organization_id))
    status_active.or(affiliation_active)
  }
  scope :address, ->(address) do
    return all if address.blank?
    terms = address.to_s.strip.split(/[\s,]+/).reject(&:blank?)
    return all if terms.empty?

    scope = joins(:addresses)
    terms.each do |term|
      wildcard = "%#{sanitize_sql_like(term)}%"
      scope = scope.where(<<~SQL.squish, wildcard: wildcard)
        addresses.street_address LIKE :wildcard OR
        addresses.city LIKE :wildcard OR
        addresses.state LIKE :wildcard OR
        addresses.county LIKE :wildcard OR
        addresses.country LIKE :wildcard OR
        addresses.district LIKE :wildcard OR
        addresses.locality LIKE :wildcard OR
        addresses.phone LIKE :wildcard OR
        addresses.zip_code LIKE :wildcard OR
        CAST(addresses.la_city_council_district AS CHAR) LIKE :wildcard OR
        CAST(addresses.la_service_planning_area AS CHAR) LIKE :wildcard OR
        CAST(addresses.la_supervisorial_district AS CHAR) LIKE :wildcard
      SQL
    end
    scope.distinct
  end
  scope :organization_ids, ->(organization_ids) { where(id: organization_ids.to_s.split("-").map(&:to_i)) }
  scope :project_ids, ->(project_ids) { where(id: project_ids.to_s.split("-").map(&:to_i)) }
  scope :published, -> { active }

  def self.search_by_params(params)
    organizations = is_a?(ActiveRecord::Relation) ? self : all
    organizations = organizations.search(params[:query]) if params[:query].present?
    organizations = organizations.sector_names_all(params[:sector_names_all]) if params[:sector_names_all].present?
    organizations = organizations.category_names_all(params[:category_names_all]) if params[:category_names_all].present?
    organizations = organizations.address(params[:address]) if params[:address].present?
    organizations = organizations.windows_type_name(params[:windows_type_name]) if params[:windows_type_name].present?
    organizations = organizations.organization_ids(params[:organization_ids]) if params[:organization_ids].present?
    organizations = organizations.where(organization_status_id: params[:organization_status_id]) if params[:organization_status_id].present?
    organizations
  end

  def affiliated_workshop_logs
    direct = WorkshopLog.where(organization_id: id)
    legacy = WorkshopLog.where(organization_id: nil)
                        .where(created_by_id: users.select(:id))
    direct.or(legacy).distinct
  end

  # Classifies this organization as a facilitator program relative to a reference
  # ("current") facilitator affiliation — typically a registrant's affiliation
  # captured through the event registration form:
  #   :new        — the reference is the organization's first facilitator
  #                 affiliation (none started before it)
  #   :ongoing    — the organization already had a facilitator affiliation that
  #                 was still active when the reference one started
  #   :reinstated — the organization had facilitator affiliation(s) before, but
  #                 they all ended before the reference one started (a lapse)
  def facilitator_status(current_affiliation)
    reference_start = current_affiliation.start_date || Date.current

    earlier = affiliations.facilitators
      .where.not(id: current_affiliation.id)
      .where.not(start_date: nil)
      .where("affiliations.start_date < ?", reference_start)

    return :new unless earlier.exists?

    active_overlap = earlier.where("affiliations.end_date IS NULL OR affiliations.end_date >= ?", reference_start)
    active_overlap.exists? ? :ongoing : :reinstated
  end

  # Methods
  def led_by?(user)
    return false unless leader
    leader.user == user
  end

  def state
    addresses.active.first&.state
  end

  def city_state
    first_active = if addresses.loaded?
      addresses.find { |a| !a.inactive? }
    else
      addresses.active.first
    end
    [ organization_locality, first_active&.state ].compact_blank.join(", ")
  end

  # Actual "City, State" of the program, from the first active address — the
  # location column on the scholarship index. (Distinct from #city_state, which
  # reports the broader locality bucket rather than the literal city.)
  def program_location
    first_active = if addresses.loaded?
      addresses.find { |a| !a.inactive? }
    else
      addresses.active.first
    end
    return unless first_active

    [ first_active.city, first_active.state ].compact_blank.join(", ").presence
  end

  # Status of this organization as an AWBW "program," relative to a scholarship
  # recipient — the New/Ongoing/Reinstate column on the scholarship index:
  #   * "Reinstate" — the org has facilitator affiliations but none are currently
  #     active (it is returning after a lapse);
  #   * "Ongoing"   — the org has facilitator affiliations beyond this recipient
  #     (an established program);
  #   * "New"       — no prior facilitator affiliations (this recipient is the
  #     program's first).
  # Heuristic based on affiliations (computed in memory to reuse a preloaded
  # association); confirm the exact business rule with the team.
  def program_status(recipient = nil)
    facilitators = affiliations.select(&:facilitator?)
    return "New" if facilitators.empty?
    return "Reinstate" if facilitators.none?(&:active?)

    prior = recipient ? facilitators.reject { |a| a.person_id == recipient.id } : facilitators
    prior.any? ? "Ongoing" : "New"
  end

  def type_name
    "#{name} #{ " (#{windows_type.short_name})" if windows_type}"
  end

  def organization_description
    locality = organization_locality
    locality.present? ? "#{name}, #{locality}" : name
  end

  def organization_locality
    if addresses.loaded?
      addresses.select { |a| !a.inactive? }.first&.locality
    else
      addresses.active.first&.locality
    end
  end

  def published? # needed for my_bookmarks
    return true if organization_status&.name == "Active"
    affiliations.active.exists?
  end

  def sector_list
    sectors.pluck(:name)
  end

  def direct_sectors
    sectors
 end

  def affiliated_sectors
    users
      .includes(person: :sectors)
      .map(&:person)
      .compact
      .flat_map(&:sectors)
  end

  def all_sectors
    (direct_sectors + affiliated_sectors).uniq
  end

  # Age groups served across the organization — its own tags plus every
  # affiliated person's — deduped so a category shared by several members shows
  # once. A category that is primary anywhere wins over an additional tagging.
  def all_primary_age_groups
    collect_age_groups(:primary_age_groups)
  end

  def all_additional_age_groups
    collect_age_groups(:additional_age_groups) - all_primary_age_groups
  end

  remote_searchable_by :name

  # Returns the website as a clickable, scheme-qualified URL — prepending
  # https:// to a bare domain like "awbw.org" — or nil when the value is blank or
  # not a usable web address. Drives the external links on the org profile and
  # recipients pages without forcing users to type a scheme.
  def website_link_url
    return if website_url.blank?
    candidate = website_url.strip
    candidate = "https://#{candidate}" unless candidate.match?(/\Ahttps?:\/\//i)
    uri = URI.parse(candidate) rescue nil
    candidate if uri.is_a?(URI::HTTP) && uri.host.present?
  end

  private

  # Union of the org's own age groups and its affiliated people's, deduped. The
  # affiliated people (with their taggings) are loaded once and memoized so the
  # several aggregation calls a page render makes don't re-query.
  def collect_age_groups(kind)
    ([ self ] + affiliated_people_with_age_data).flat_map { |record| record.public_send(kind) }.uniq
  end

  def affiliated_people_with_age_data
    @affiliated_people_with_age_data ||=
      people.includes(categorizable_items: { category: :category_type }).to_a
  end

  def affiliation_dates_locked
    if start_date_changed?
      errors.add(:start_date, "is managed automatically by affiliations")
    end
    if end_date_changed?
      errors.add(:end_date, "is managed automatically by affiliations")
    end
  end

  def leader
    affiliations.find_by(position: 2)
  end

  def remove_duplicate_sectorable_items
    sectorable_items
      .group_by(&:sector_id)
      .each_value { |dupes| dupes.drop(1).each(&:destroy) }
  end
end
