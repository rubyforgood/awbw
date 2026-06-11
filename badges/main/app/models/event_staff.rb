class EventStaff < ApplicationRecord
  belongs_to :event
  belongs_to :person

  validates :person_id, uniqueness: { scope: :event_id }

  scope :ordered_by_name, -> {
    joins(:person).order(Arel.sql("people.first_name, people.last_name"))
  }
end
