class TimelineEvent < ApplicationRecord
  belongs_to :subject, polymorphic: true, optional: true
  belongs_to :actor, polymorphic: true, optional: true
  has_many :timeline_entries, dependent: :destroy

  validates :action, presence: true
  validates :snapshot, presence: true
  validate :subject_must_be_timelineable

  ACTION_LABELS = { "destroyed" => "removed" }.freeze

  def actor_label
    actor&.full_name || snapshot["actor_label"] || "System"
  end

  def action_label
    ACTION_LABELS.fetch(action, action.humanize.downcase)
  end

  private

  def subject_must_be_timelineable
    return if subject.nil?
    return if subject.class.include?(Timelineable)

    errors.add(:subject, "must include Timelineable")
  end
end
