class StoryIdeaWorkshop < ApplicationRecord
  self.table_name = "story_ideas_workshops"

  belongs_to :story_idea
  belongs_to :workshop, optional: true

  normalizes :external_workshop_title, with: ->(value) { value&.strip.presence }

  validates :external_workshop_title, length: { maximum: 255 }
  validate :workshop_or_external_title_present
  validate :link_not_already_present

  # A workshop may repeat within an idea under a different free-text title
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
    return unless duplicated_among_submitted_rows? || duplicated_in_database?

    errors.add(workshop_id.present? ? :workshop_id : :external_workshop_title,
               "is already linked to this story idea")
  end

  def duplicated_among_submitted_rows?
    submitted_rows.reject(&:marked_for_destruction?).any? { |row| row.link_key == link_key }
  end

  # Rows flagged for removal are deleted before this one is written, so a link
  # they still hold isn't a conflict. An unsaved idea has no id yet, so no stored
  # row can hold this link — only the rows beside it can.
  def duplicated_in_database?
    return false if story_idea_id.blank?
    return false if workshop.present? && workshop_id.blank?

    scope = StoryIdeaWorkshop.where(story_idea_id: story_idea_id, workshop_id: workshop_id,
                                    external_workshop_title: external_workshop_title)
    scope = scope.where.not(id: id) if persisted?
    removed_ids = submitted_rows.select(&:marked_for_destruction?).filter_map(&:id)
    scope = scope.where.not(id: removed_ids) if removed_ids.any?
    scope.exists?
  end

  # The rows saved alongside this one. An idea is only edited from its own form,
  # so the sibling rows are the idea's — reading the association target rather
  # than the collection keeps this from querying rows the save isn't touching.
  def submitted_rows
    Array(story_idea&.story_idea_workshops&.target).reject { |row| row.equal?(self) }
  end
end
