class Event < ApplicationRecord
  belongs_to :created_by, class_name: "User", optional: true
  has_many :bookmarks, as: :bookmarkable, dependent: :destroy
  has_many :event_registrations, dependent: :destroy
  has_many :registrants, through: :event_registrations, class_name: "User"

  validates_presence_of :title, :start_date, :end_date
  validates_inclusion_of :publicly_visible, in: [true, false]

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
