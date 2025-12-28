class Tutorial < ApplicationRecord
	include TagFilterable, Trendable, ViewCountable

	has_rich_text :rhino_body

	has_many :bookmarks, as: :bookmarkable, dependent: :destroy
	# Image associations
	has_one :main_image, -> { where(type: "Images::MainImage") },
					as: :owner, class_name: "Images::MainImage", dependent: :destroy
	has_many :gallery_images, -> { where(type: "Images::GalleryImage") },
					 as: :owner, class_name: "Images::GalleryImage", dependent: :destroy

	validates :title, presence: true, uniqueness: { case_sensitive: false }

	# Nested attributes
	accepts_nested_attributes_for :main_image, reject_if: :all_blank, allow_destroy: true
	accepts_nested_attributes_for :gallery_images, reject_if: :all_blank, allow_destroy: true

	# SearchCop
	include SearchCop
	search_scope :search do
		attributes :title, :body
	end

	scope :body, -> (body) { where("body like ?", "%#{ body }%") }
	scope :by_most_viewed, ->(limit = 10) { order(view_count: :desc).limit(limit) }
	scope :published, ->(published=nil) {
		if ["true", "false"].include?(published)
			where(published: published)
		else
			where(published: true)
		end
	}
	scope :published_search, -> (published_search) { published_search.present? ? published(published_search) : all }
	scope :title, -> (title) { where("title like ?", "%#{ title }%") }
	scope :tutorial_name, -> (tutorial_name) { title(tutorial_name) }

	def self.search_by_params(params)
		resources = all
		resources = resources.search(params[:search]) if params[:search].present?
		resources = resources.title(params[:title]) if params[:title].present?
		resources = resources.body(params[:body]) if params[:body].present?
		resources = resources.published(params[:published]) if params[:published].present?
		resources
	end
end
