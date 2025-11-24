class Event < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :event_registrations, dependent: :destroy
  has_many :registrants, through: :event_registrations, class_name: "User"
  # Image associations
  has_one :main_image, -> { where(type: "Images::MainImage") },
          as: :owner, class_name: "Images::MainImage", dependent: :destroy
  has_many :gallery_images, -> { where(type: "Images::GalleryImage") },
           as: :owner, class_name: "Images::GalleryImage", dependent: :destroy

  # Validations
  validates_presence_of :title, :start_date, :end_date
  validates_inclusion_of :publicly_visible, in: [true, false]

  # Nested attributes
  accepts_nested_attributes_for :main_image, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :gallery_images, allow_destroy: true, reject_if: :all_blank

  scope :featured, -> { where(featured: true) }
  scope :published, -> { publicly_visible }
  scope :publicly_visible, -> { where(publicly_visible: true) }

  def inactive?
    !publicly_visible
  end

  def registerable?
    publicly_visible &&
      (registration_close_date.nil? || registration_close_date >= Time.current)
  end

  def full_name
    "#{ title } (#{ start_date.strftime("%Y-%m-%d @ %I:%M %p") })"
  end

  def name
    title
  end
end
