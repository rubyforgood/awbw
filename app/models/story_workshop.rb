class StoryWorkshop < ApplicationRecord
  self.table_name = "stories_workshops"

  belongs_to :story
  belongs_to :workshop, optional: true

  validates :external_workshop_title, length: { maximum: 255 }
  validates :workshop_id, uniqueness: { scope: :story_id }, allow_nil: true
  validate :workshop_or_external_title_present

  private

  def workshop_or_external_title_present
    return if workshop.present? || external_workshop_title.present?
    errors.add(:base, "needs a workshop or a workshop title")
  end
end
