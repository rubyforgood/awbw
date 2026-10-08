class StoryIdea < ApplicationRecord
  include AuthorCreditable
  include CategoriesTaggable, SectorsTaggable
  include Communicable
  # The submitter is the author when none is named.
  credits_creator

  include SearchCop
  search_scope :search do
    attributes :title, :body
  end

  def self.search_by_params(params)
    results = is_a?(ActiveRecord::Relation) ? self : all
    results = results.search(params[:query]) if params[:query].present?
    results = results.where(id: by_credited_person_name(params[:author_name]).select("story_ideas.id")) if params[:author_name].present?
    results = results.where(organization_id: params[:organization_id]) if params[:organization_id].present?
    results = results.created_by_person(params[:created_by_person_id]) if params[:created_by_person_id].present?
    results
  end

  has_rich_text :rhino_body

  belongs_to :author, class_name: "Person", inverse_of: :story_ideas_as_author, optional: true
  belongs_to :co_author, class_name: "Person", inverse_of: :story_ideas_as_co_author, optional: true
  # Spotlight is not an author credit, so it ignores the credit preference entirely.
  belongs_to :spotlighted_facilitator, class_name: "Person",
             foreign_key: "spotlighted_facilitator_id",
             inverse_of: :story_ideas_as_spotlighted_facilitator, optional: true
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
  belongs_to :organization, optional: true
  belongs_to :windows_type
  # Kept as a legacy safety copy alongside story_idea_workshops during the
  # multi-step import; the join is the source of truth for display and editing.
  belongs_to :workshop, optional: true
  has_many :story_idea_workshops, -> { order(:position, :id) }, inverse_of: :story_idea, dependent: :destroy
  has_many :workshops, through: :story_idea_workshops
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :categorizable_items, dependent: :destroy, inverse_of: :categorizable, as: :categorizable
  has_many :sectorable_items, dependent: :destroy, inverse_of: :sectorable, as: :sectorable
  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy
  has_many :stories

  # Asset associations
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy
  # has_many through
  has_many :categories, through: :categorizable_items
  has_many :sectors, through: :sectorable_items

  # The column stays optional so admins can file an idea without one; the form
  # sets this flag to require organization from everyone else.
  attr_accessor :organization_required

  # Validations
  validates :created_by_id, presence: true
  validates :updated_by_id, presence: true
  validates :organization_id, presence: true, if: :organization_required
  validates :windows_type_id, presence: true
  validates :permission_given, presence: true
  validates :rhino_body, presence: true
  validates :external_workshop_title, length: { maximum: 255 }
  validates :youtube_url, length: { maximum: 255 }
  normalizes :co_author_credit_preference, with: ->(value) { value.presence }
  validates :co_author_credit_preference, inclusion: { in: AuthorCreditable::AUTHOR_CREDIT_PREFERENCES }, allow_blank: true
  # A second author has to sit behind a first.
  validates :author_id, presence: { message: "is required when a second author is credited" },
            if: -> { co_author_id.present? }
  validate :co_author_differs_from_author

  # A story idea credits either author, so both the author chip filter and the
  # person profile listing match on author_id or co_author_id.
  scope :authored_by, ->(person_id) {
    where("story_ideas.author_id = :id OR story_ideas.co_author_id = :id", id: person_id) if person_id.present?
  }

  scope :credited_to_person, ->(person) {
    return none if person.blank?
    where(author_id: person.id)
      .or(where(co_author_id: person.id))
      .or(where(author_id: nil, created_by_id: User.where(person_id: person.id).select(:id)))
  }

  # Nested attributes
  accepts_nested_attributes_for :story_idea_workshops, allow_destroy: true,
    reject_if: ->(attrs) { attrs[:workshop_id].blank? && attrs[:external_workshop_title].blank? }
  accepts_nested_attributes_for :primary_asset, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_assets, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attrs| attrs["body"].blank? }

  def name
    "StoryIdea ##{id}"
  end

  def communications_email
    created_by&.email
  end

  def full_name
    base = "#{created_at.strftime("%Y-%m-%d")} #{author_credit}"
    title = workshop_title
    title.present? ? "#{base}: #{title}" : base
  end

  def workshop_title
    return direct_workshop_title if story_idea_workshops.empty?
    story_idea_workshops.map { |siw| story_idea_workshop_label(siw) }.compact_blank.presence&.join(" / ")
  end

  def organization_name
    organization&.name
  end

  def organization_locality
    organization&.organization_locality
  end

  def organization_description
    organization&.organization_description
  end

  private

  def direct_workshop_title
    [ workshop&.title, external_workshop_title.presence ].compact_blank.presence&.join(" / ")
  end

  def story_idea_workshop_label(story_idea_workshop)
    workshop_title = story_idea_workshop.workshop&.title
    external_title = story_idea_workshop.external_workshop_title.presence
    return "#{external_title} (from the #{workshop_title})" if external_title && workshop_title
    external_title || workshop_title
  end

  def co_author_differs_from_author
    return if co_author_id.blank? || author_id.blank?
    return if co_author_id != author_id

    errors.add(:co_author_id, "must be different from the first author")
  end
end
