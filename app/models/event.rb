class Event < ApplicationRecord
  validates_presence_of :title, :start_date, :end_date, :publicly_visible
end
