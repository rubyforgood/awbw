class TimelineEvent < ApplicationRecord
  belongs_to :subject, polymorphic: true
  belongs_to :actor, polymorphic: true, optional: true
  has_many :timeline_entries, dependent: :destroy

  validates :action, presence: true
  validates :snapshot, presence: true

  def actor_label
    actor&.full_name || snapshot["actor_label"] || "System"
  end
end
