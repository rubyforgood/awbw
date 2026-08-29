class TimelineEntry < ApplicationRecord
  belongs_to :owner, polymorphic: true
  belongs_to :timeline_event
end
