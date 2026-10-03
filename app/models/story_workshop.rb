class StoryWorkshop < ApplicationRecord
  self.table_name = "stories_workshops"

  belongs_to :story
  belongs_to :workshop, optional: true

  normalizes :external_workshop_title, with: ->(value) { value&.strip.presence }

  validates :external_workshop_title, length: { maximum: 255 }
  validate :workshop_or_external_title_present
  validate :link_not_already_present

  # A workshop may repeat within a story under a different free-text title
  # ("Teen variant (from the Anger Volcano)"), so a link is the pair.
  def link_key
    [ workshop_id, external_workshop_title ]
  end

  private

  def workshop_or_external_title_present
    return if workshop.present? || external_workshop_title.present?
    errors.add(:base, "needs a workshop or a workshop title")
  end

  def link_not_already_present
    return if story_id.blank?
    return unless duplicated_among_submitted_rows? || duplicated_in_database?

    errors.add(workshop_id.present? ? :workshop_id : :external_workshop_title,
               "is already linked to this story")
  end

  def duplicated_among_submitted_rows?
    submitted_rows.reject(&:marked_for_destruction?).any? { |row| row.link_key == link_key }
  end

  # Rows flagged for removal are deleted before this one is written, so a link
  # they still hold isn't a conflict.
  def duplicated_in_database?
    scope = StoryWorkshop.where(story_id: story_id, workshop_id: workshop_id,
                                external_workshop_title: external_workshop_title)
    scope = scope.where.not(id: id) if persisted?
    removed_ids = submitted_rows.select(&:marked_for_destruction?).filter_map(&:id)
    scope = scope.where.not(id: removed_ids) if removed_ids.any?
    scope.exists?
  end

  # The rows saved alongside this one, from whichever side's form is saving.
  # Reading the association target rather than the collection keeps this from
  # querying for rows the save isn't touching.
  def submitted_rows
    [ story, workshop ].compact
      .flat_map { |parent| parent.story_workshops.target }
      .uniq
      .reject { |row| row.equal?(self) }
  end
end
