class Event < ApplicationRecord
  has_many :event_registrations, dependent: :destroy
  
  validates_presence_of :title, :start_date, :end_date
  validates_inclusion_of :publicly_visible, in: [true, false]
end
