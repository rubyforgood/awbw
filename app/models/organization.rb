class Organization < ApplicationRecord
  include RemoteSearchable, Trendable, WindowsTypeFilterable # Publishable
  include Communicable
  include FilemakerCoded
  filemaker_archived_in FmProject, FmOrganization
  belongs_to :organization_status, optional: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
  belongs_to :organization_obligation, optional: true
  belongs_to :location, optional: true # TODO - remove Location if unused
  belongs_to :windows_type, optional: true
  # Self-referential nesting: an org can sit under a parent "roof" org (mirrors
  # FileMaker's Organization ParentID). Deleting a parent un-nests its children
  # rather than cascading. See ADR-0004.
  belongs_to :parent, class_name: "Organization", optional: true, inverse_of: :children
  has_many :children, class_name: "Organization", foreign_key: :parent_id, inverse_of: :parent, dependent: :nullify
  has_many :addresses, as: :addressable, dependent: :destroy
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :other_responses, as: :owner, dependent: :destroy
  has_many :invoices, as: :invoicee, dependent: :restrict_with_error
  has_many :affiliations, dependent: :restrict_with_error, inverse_of: :organization
  has_many :event_registration_organizations, dependent: :restrict_with_error
  has_many :event_registrations, through: :event_registration_organizations
  has_many :people, through: :affiliations
  has_many :users, through: :people
  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy

  # An organization is its own correspondent — there is no person behind it.
  def communications_email
    email
  end
  has_many :reports
  has_many :workshop_logs
  has_many :workshop_ideas
  has_many :workshops
  has_many :workshops_as_author, through: :people, source: :workshops_as_author
  has_many :workshop_ideas_as_author, through: :people, source: :workshop_ideas_as_author
  has_many :grants, as: :funder, dependent: :destroy

  has_many :categorizable_items, dependent: :destroy, inverse_of: :categorizable, as: :categorizable
  has_many :sectorable_items, as: :sectorable, dependent: :destroy
  # has_many through
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items

  # Asset associations
  has_one_attached :logo, dependent: :purge do |attachable|
    attachable.variant :thumbnail,
      resize_to_limit: [ 256, 256 ],
      format: :webp,
      saver: { quality: 80 }
  end

  # List pages must preload people with exactly this, or each row re-queries.
  PEOPLE_TAGGINGS = [ { sectorable_items: :sector }, { categorizable_items: { category: :category_type } } ].freeze

  # Org classifications offered by the org form and the registration form's
  # "Organization Type" question, in display order. Any stored value not listed
  # (e.g. the legacy "Other (please specify below)") folds into "Other" for display
  # so an unmatched select can't silently save as the first option.
  ORGANIZATION_TYPE_OTHER = "Other"
  ORGANIZATION_TYPES = [ "501c3/nonprofit", "For-profit", "Government agency", ORGANIZATION_TYPE_OTHER ].freeze

  # Validations
  validates :logo,
            content_type: %w[image/png image/jpeg image/webp],
            size: { less_than: 5.megabytes }
  normalizes :name, with: ->(name) { name.strip }
  validates :name, presence: true, length: { maximum: 255 }, uniqueness: { case_sensitive: false }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_blank: true, length: { maximum: 255 }
  validates :organization_type_other, length: { maximum: 255 }
  validates :tax_id, length: { maximum: 255 }
  validates :website_url, length: { maximum: 255 }
  validates :mission_vision_values, length: { maximum: 255 }
  validate :affiliation_dates_locked, if: -> { affiliations.any? && !Current.user&.super_user? }
  validate :parent_is_not_self_or_descendant, if: :parent_id_changed?

  # Nested attributes
  accepts_nested_attributes_for :addresses, allow_destroy: true,
                                reject_if: proc { |attrs| attrs.slice("locality", "city", "state", "street_address", "zip_code").values.all?(&:blank?) }
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
  # An org is active because someone is affiliated there, not because the legacy
  # status column says so (ADR-0001 D3, ADR-0003 D4).
  scope :active, -> { where(id: Affiliation.active.select(:organization_id)) }
  scope :with_active_facilitators, -> { where(id: Affiliation.active.facilitators.select(:organization_id)) }
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
  # Off facilitator affiliations only, never the legacy organization_status, so the
  # filter and the status chip can't disagree (ADR-0001 D3).
  scope :program_status, ->(bucket) {
    # with_duration for the same reason the chip drops zero-length rows: a no-show's
    # deactivated stub is not facilitation (ADR-0001 D8a).
    facilitations = Affiliation.facilitators.with_duration
    fac_ids = facilitations.select(:organization_id)
    active_fac_ids = facilitations.active.select(:organization_id)
    upcoming_fac_ids = facilitations.with_status("Upcoming").select(:organization_id)
    case bucket.to_s
    when "active"            then where(id: active_fac_ids)
    when "upcoming"          then where(id: upcoming_fac_ids).where.not(id: active_fac_ids)
    when "formerly_active"   then where(id: fac_ids).where.not(id: active_fac_ids).where.not(id: upcoming_fac_ids)
    when "never_active"      then where.not(id: fac_ids)
    when "formerly_or_never" then where.not(id: active_fac_ids)
    else all
    end
  }

  # The index's Program status dropdown, in display order. "Inactive" is the
  # not-active umbrella (formerly + never + upcoming) with the two narrower
  # buckets after it, mirroring Person::FACILITATOR_STATUS_FILTER_OPTIONS so the
  # two indexes read the same way.
  PROGRAM_STATUS_FILTER_OPTIONS = [
    [ "Active", "active" ],
    [ "Inactive", "formerly_or_never" ],
    [ "Upcoming", "upcoming" ],
    [ "Formerly active", "formerly_active" ],
    [ "Never active", "never_active" ]
  ].freeze

  # Org search: like TagFilterable (matches ALL names), but sectors and age ranges
  # match through any tag, primary or additional, an active facilitator holds.
  scope :sector_names_all, ->(names) {
    parsed = TagFilterable.parse_names(names)
    next all if parsed.empty?

    where(id: Organization.active_facilitator_sector_tags.joins(person: { sectorable_items: :sector })
                .where("LOWER(sectors.name) IN (?)", parsed)
                .group(:organization_id)
                .having("COUNT(DISTINCT LOWER(sectors.name)) = ?", parsed.size)
                .select(:organization_id))
  }

  scope :category_names_all, ->(names) {
    parsed = TagFilterable.parse_names(names)
    next all if parsed.empty?

    age_names = Category.age_ranges.where("LOWER(categories.name) IN (?)", parsed).pluck(Arel.sql("LOWER(categories.name)")).uniq
    own_names = parsed - age_names
    scope = all
    if age_names.any?
      scope = scope.where(id: Organization.active_facilitator_age_group_tags.joins(person: { categorizable_items: :category })
                                .where("LOWER(categories.name) IN (?)", age_names)
                                .group(:organization_id)
                                .having("COUNT(DISTINCT LOWER(categories.name)) = ?", age_names.size)
                                .select(:organization_id))
    end
    if own_names.any?
      scope = scope.where(id: Organization.unscoped.with_active_facilitators
                                .joins(:categories).where("LOWER(categories.name) IN (?)", own_names)
                                .group("organizations.id")
                                .having("COUNT(DISTINCT LOWER(categories.name)) = ?", own_names.size)
                                .select("organizations.id"))
    end
    scope
  }

  def self.active_facilitator_sector_tags
    Affiliation.active.facilitators.joins(person: :sectorable_items)
  end

  def self.active_facilitator_age_group_tags
    Affiliation.active.facilitators.joins(person: :categorizable_items)
               .where(categorizable_items: { category_id: Category.age_ranges.select(:id) })
  end

  # EXISTS conditions for the public tag lists (Sector/Category.has_published_taggings),
  # correlated on the outer sectors / categories row.
  def self.sector_tagging_exists
    active_facilitator_sector_tags.where("sectorable_items.sector_id = sectors.id").select("1").arel.exists
  end

  def self.category_tagging_exists
    via_people = active_facilitator_age_group_tags.where("categorizable_items.category_id = categories.id")
    own = with_active_facilitators.joins(:categorizable_items).where("categorizable_items.category_id = categories.id")
                   .where.not(categorizable_items: { category_id: Category.age_ranges.select(:id) })
    via_people.select("1").arel.exists.or(own.select("1").arel.exists)
  end

  # Org counts per tag for the tag matrix, matching the tag-search scopes above.
  def self.sector_tag_counts
    active_facilitator_sector_tags.group("sectorable_items.sector_id").distinct.count(:organization_id)
  end

  def self.category_tag_counts
    own = with_active_facilitators.joins(:categories).where.not(categories: { id: Category.age_ranges.select(:id) })
                   .group("categories.id").count
    own.merge(active_facilitator_age_group_tags.group("categorizable_items.category_id").distinct.count(:organization_id))
  end

  scope :organization_ids, ->(organization_ids) { where(id: organization_ids.to_s.split("-").map(&:to_i)) }
  scope :project_ids, ->(project_ids) { where(id: project_ids.to_s.split("-").map(&:to_i)) }
  scope :published, -> { active }

  def self.search_by_params(params)
    organizations = is_a?(ActiveRecord::Relation) ? self : all
    organizations = organizations.search(params[:query]) if params[:query].present?
    organizations = organizations.sector_names_all(params[:sector_names_all].presence || params[:sector_name])
    organizations = organizations.category_names_all(params[:category_names_all].presence || params[:age_group_name])
    organizations = organizations.address(params[:address]) if params[:address].present?
    organizations = organizations.organization_ids(params[:organization_ids]) if params[:organization_ids].present?
    organizations = organizations.program_status(params[:program_status]) if params[:program_status].present?
    organizations
  end

  def affiliated_workshop_logs
    direct = WorkshopLog.where(organization_id: id)
    legacy = WorkshopLog.where(organization_id: nil)
                        .where(created_by_id: users.select(:id))
    direct.or(legacy).distinct
  end

  def affiliated_workshops
    return Workshop.none unless persisted?

    direct = Workshop.where(organization_id: id)
    indirect = Workshop.where(author_id: people.select(:id))
    direct.or(indirect).distinct
  end
  alias_method :all_workshops, :affiliated_workshops

  def affiliated_workshop_ideas
    return WorkshopIdea.none unless persisted?

    direct = WorkshopIdea.where(organization_id: id)
    indirect = WorkshopIdea.where(author_id: people.select(:id))
    direct.or(indirect).distinct
  end
  alias_method :all_workshop_ideas, :affiliated_workshop_ideas

  # Display order, and what the attendees index filters on.
  FACILITATOR_PROGRAM_STATUSES = FacilitatorProgramStatus::STATUSES

  # A FacilitatorProgramStatus (verdict + reasoning) as of a date; nil `as_of`
  # anchors on the start of the current year. See ADR-0001 D4.
  def facilitator_program_status(as_of: nil)
    FacilitatorProgramStatus.for(self, as_of: as_of)
  end

  # The bare symbol, for counting and filtering.
  def facilitator_status_on(reference_date = nil)
    facilitator_program_status(as_of: reference_date).status
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

  def type_name
    "#{name} #{ " (#{windows_type.short_name})" if windows_type}"
  end

  def nested?
    parent_id.present?
  end

  # Every ancestor from the immediate parent up to the root, guarding against a
  # malformed cycle so a bad row can't loop forever.
  def ancestors
    result = []
    seen = [ id ]
    current = parent
    while current && seen.exclude?(current.id)
      result << current
      seen << current.id
      current = current.parent
    end
    result
  end

  # The topmost org in this org's tree — itself when it has no parent.
  def root
    ancestors.last || self
  end

  # Every org nested under this one, at any depth.
  def descendants
    children.flat_map { |child| [ child ] + child.descendants }
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

  # Needed for my_bookmarks. Keys off affiliations only — the stored
  # organization_status has drifted and is never consulted (ADR-0003 D4).
  # The loaded branch is the in-memory twin of the `active` scope, so a list page
  # that preloaded affiliations doesn't query once per row.
  def published?
    return affiliations.any?(&:active?) if affiliations.loaded?

    affiliations.active.exists?
  end

  # Sectors and age groups are never entered on an org — they roll up from the
  # primary tags of its active facilitators.
  # Most-held first, so a capped list shows the most representative; ties break
  # alphabetically for sectors and on age position for age groups.
  def active_facilitator_sectors
    active_facilitators.filter_map(&:primary_sector).tally
      .sort_by { |sector, count| [ -count, sector.name.to_s.downcase ] }.map(&:first)
  end

  def active_facilitator_age_groups
    active_facilitators.flat_map(&:primary_age_groups).tally
      .sort_by { |group, count| [ -count, group.position || 0, group.name.to_s ] }.map(&:first)
  end

  BREAKDOWN_SORT_OPTIONS = [ [ "Primary first", "primary" ], [ "Total", "total" ], [ "A–Z", "name" ] ].freeze
  BREAKDOWN_SORTS = BREAKDOWN_SORT_OPTIONS.map(&:last).freeze

  TagBreakdown = Data.define(:tag, :primary_count, :additional_count) do
    def total = primary_count + additional_count

    def sort_key(sort)
      name = tag.name.to_s.downcase
      case sort
      when "total" then [ -total, -primary_count, name ]
      when "name" then [ name ]
      else [ -primary_count, -additional_count, name ]
      end
    end
  end

  # Every sector active facilitators hold, primary or additional, for the full breakdown page.
  def active_facilitator_sector_breakdown(sort: nil)
    tag_breakdown(active_facilitators.flat_map { |person|
      person.sectorable_items.filter_map { |item| [ item.sector, item.is_primary? ] if item.sector && item.sector.name != Sector::OTHER_SECTOR_NAME }
    }, sort)
  end

  def active_facilitator_age_group_breakdown(sort: nil)
    tag_breakdown(active_facilitators.flat_map { |person|
      person.primary_age_groups.map { |group| [ group, true ] } + person.additional_age_groups.map { |group| [ group, false ] }
    }, sort)
  end

  # Reads preloaded affiliations, so a list page that nests PEOPLE_TAGGINGS under
  # them costs no queries per row.
  def active_facilitators
    @active_facilitators ||= begin
      facilitating = if affiliations.loaded?
        affiliations.select { |affiliation| affiliation.active? && affiliation.facilitator? }
      else
        affiliations.active.facilitators.includes(person: PEOPLE_TAGGINGS)
      end
      facilitating.filter_map(&:person).uniq
    end
  end

  # The roll-up cells aggregate across affiliated people, so retagging a person or
  # adding an affiliation leaves the organizations row untouched and `[organization]`
  # alone caches them stale. Reads preloaded associations, so it costs no queries.
  def rollup_cache_version
    records = affiliations.to_a + active_facilitators.flat_map { |person| person.sectorable_items.to_a + person.categorizable_items.to_a }
    [ records.size, records.filter_map(&:updated_at).max ]
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

  def tag_breakdown(tag_and_primary_pairs, sort)
    tag_and_primary_pairs.group_by(&:first)
      .map { |tag, pairs| TagBreakdown.new(tag:, primary_count: pairs.count(&:last), additional_count: pairs.count { |pair| !pair.last }) }
      .sort_by { |row| row.sort_key(sort) }
  end

  def affiliation_dates_locked
    if start_date_changed?
      errors.add(:start_date, "is managed automatically by affiliations")
    end
    if end_date_changed?
      errors.add(:end_date, "is managed automatically by affiliations")
    end
  end

  def parent_is_not_self_or_descendant
    return if parent_id.blank?

    if parent_id == id
      errors.add(:parent_id, "can't be the organization itself")
    elsif persisted? && descendants.any? { |org| org.id == parent_id }
      errors.add(:parent_id, "can't be one of this organization's nested organizations")
    end
  end
end
