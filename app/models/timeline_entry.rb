class TimelineEntry < ApplicationRecord
  belongs_to :timeline, polymorphic: true
  belongs_to :timeline_event
end
