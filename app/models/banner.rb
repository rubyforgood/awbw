class Banner < ApplicationRecord
  include Publishable

  belongs_to :created_by, class_name: "User"
  belongs_to :updated_by, class_name: "User"

  validates :content, presence: true
  validate :ended_at_after_started_at

  # Scopes
  # See Publishable

  # Published banners whose optional schedule window includes now. A nil
  # started_at means "already started"; a nil ended_at means "never ends".
  scope :active, ->(now = Time.current) {
    published
      .where("started_at IS NULL OR started_at <= ?", now)
      .where("ended_at IS NULL OR ended_at >= ?", now)
  }

  def name
    content.truncate(50)
  end

  private

  def ended_at_after_started_at
    return if started_at.blank? || ended_at.blank?
    errors.add(:ended_at, "must be after the start date") if ended_at <= started_at
  end
end
