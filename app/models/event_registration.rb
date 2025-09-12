class EventRegistration < ApplicationRecord
  belongs_to :event
  
  validates_presence_of :first_name, :last_name, :email, :event_id
  validates_uniqueness_of :email, scope: :event_id, message: 'is already registered for this event', case_sensitive: false
  validates_format_of :email, with: URI::MailTo::EMAIL_REGEXP
end
