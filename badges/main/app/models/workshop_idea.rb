class WorkshopIdea < ApplicationRecord
  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"
  belongs_to :windows_type
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :notifications, as: :noticeable, dependent: :destroy
  has_many :workshops
  has_many :workshop_series_children, # When this workshop is the parent in a series
           -> { order(:position) },
           class_name: "WorkshopSeriesMembership",
           foreign_key: "workshop_parent_id",
           dependent: :destroy
  has_many :workshop_series_parents, # When this workshop is the child in a series
           class_name: "WorkshopSeriesMembership",
           foreign_key: "workshop_child_id",
           dependent: :destroy
  # Images
  has_one_attached :header
  # Asset associations
  has_one :primary_asset, -> { where(type: "PrimaryAsset") },
          as: :owner, class_name: "PrimaryAsset", dependent: :destroy
  has_many :gallery_assets, -> { where(type: "GalleryAsset") },
           as: :owner, class_name: "GalleryAsset", dependent: :destroy
  has_many :assets, as: :owner, dependent: :destroy

  before_save :set_time_frame

  # Nested attributes
  accepts_nested_attributes_for :workshop_series_children,
                                reject_if: proc { |attributes| attributes["workshop_child_id"].blank? },
                                allow_destroy: true

  has_rich_text :rhino_objective
  has_rich_text :rhino_materials
  has_rich_text :rhino_optional_materials
  has_rich_text :rhino_setup
  has_rich_text :rhino_introduction
  has_rich_text :rhino_opening_circle
  has_rich_text :rhino_demonstration
  has_rich_text :rhino_warm_up
  has_rich_text :rhino_visualization
  has_rich_text :rhino_creation
  has_rich_text :rhino_closing
  has_rich_text :rhino_notes
  has_rich_text :rhino_tips
  has_rich_text :rhino_misc1
  has_rich_text :rhino_misc2
  has_rich_text :rhino_extra_field

  has_rich_text :rhino_objective_spanish
  has_rich_text :rhino_materials_spanish
  has_rich_text :rhino_optional_materials_spanish
  has_rich_text :rhino_age_range_spanish
  has_rich_text :rhino_setup_spanish
  has_rich_text :rhino_introduction_spanish
  has_rich_text :rhino_opening_circle_spanish
  has_rich_text :rhino_demonstration_spanish
  has_rich_text :rhino_warm_up_spanish
  has_rich_text :rhino_visualization_spanish
  has_rich_text :rhino_creation_spanish
  has_rich_text :rhino_closing_spanish
  has_rich_text :rhino_notes_spanish
  has_rich_text :rhino_tips_spanish
  has_rich_text :rhino_misc1_spanish
  has_rich_text :rhino_misc2_spanish
  has_rich_text :rhino_extra_field_spanish

  # Scopes
  scope :title, ->(title) { where("workshop_ideas.title like ?", "%#{ title }%") }
  scope :author_name, ->(author_name) { joins(:created_by).
    where("users.first_name like ? or users.last_name like ? or users.email like ?",
          "%#{author_name}%", "%#{author_name}%", "%#{author_name}%") }

  def self.search(params)
    results = WorkshopIdea.all
    results = results.title(params[:title]) if params[:title].present?
    results = results.author_name(params[:author_name]) if params[:author_name].present?
    results
  end

  def time_frame_total
    total_minutes = time_intro.to_i + time_demonstration.to_i +
      time_opening.to_i + time_opening_circle.to_i + time_warm_up.to_i +
      time_creation.to_i + time_closing.to_i

    return "00:00" if total_minutes == 0

    # Custom rounding: minimum 15 min, then nearest 15
    total_minutes = [ 15, (total_minutes / 15.0).round * 15 ].max

    hours, minutes = total_minutes.divmod(60)

    if hours.positive?
      "#{hours}:#{format('%02d', minutes)} hours"
    else
      "#{minutes} min"
    end
  end

  private

  def set_time_frame
    self.timeframe = time_frame_total
  end
end
