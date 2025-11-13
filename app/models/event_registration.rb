class EventRegistration < ApplicationRecord
  belongs_to :registrant, class_name: "User", foreign_key: :registrant_id
  belongs_to :event

  validates :registrant_id, uniqueness: {scope: :event_id}
end
