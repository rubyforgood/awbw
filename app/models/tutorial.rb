class Tutorial < ApplicationRecord
  include TagFilterable, Trendable, RichTextSearchable

  has_rich_text :rhino_body

  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  # Asset associations
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy

  validates :title, presence: true, uniqueness: { case_sensitive: false }

  # Nested attributes
  accepts_nested_attributes_for :primary_asset, reject_if: :all_blank, allow_destroy: true
  accepts_nested_attributes_for :gallery_assets, reject_if: :all_blank, allow_destroy: true

  # SearchCop
  include SearchCop
  search_scope :search do
    attributes :title, :body

    scope { join_rich_texts }
    attributes action_text_body: "action_text_rich_texts.plain_text_body"
    options :action_text_body, type: :text, default: true, default_operator: :or
  end

  scope :body, ->(body) { where("body like ?", "%#{ body }%") }
  scope :published, ->(published = nil) {
    if [ "true", "false" ].include?(published)
      where(published: published)
    else
      where(published: true)
    end
  }
  scope :published_search, ->(published_search) { published_search.present? ? published(published_search) : all }
  scope :title, ->(title) { where("title like ?", "%#{ title }%") }
  scope :tutorial_name, ->(tutorial_name) { title(tutorial_name) }

  def self.search_by_params(params)
    resources = all
    resources = resources.search(params[:search]) if params[:search].present?
    resources = resources.title(params[:title]) if params[:title].present?
    resources = resources.body(params[:body]) if params[:body].present?
    resources = resources.published(params[:published]) if params[:published].present?
    resources
  end
end
