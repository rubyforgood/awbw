module HasTimeline
  extend ActiveSupport::Concern

  included do
    has_many :timeline_entries, as: :owner, dependent: :destroy
    has_many :timeline_events, through: :timeline_entries
  end
end
