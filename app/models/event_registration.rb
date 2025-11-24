class EventRegistration < ApplicationRecord
  belongs_to :registrant, class_name: "User", foreign_key: :registrant_id
  belongs_to :event

  # Validations
  validates :registrant_id, uniqueness: {scope: :event_id}
  validates :event_id, presence: true

  # Scopes
  scope :registrant_name, -> (registrant_name){ joins(:registrant).where(
    "LOWER(REPLACE(CONCAT(users.first_name, users.last_name), ' ', '')) LIKE :name
    OR LOWER(REPLACE(CONCAT(users.last_name, users.first_name), ' ', '')) LIKE :name
    OR LOWER(REPLACE(users.first_name, ' ', '')) LIKE :name
    OR LOWER(REPLACE(users.last_name, ' ', '')) LIKE :name", name: "%#{registrant_name}%") }
  scope :event_title, -> (event_title){ joins(:event).where("LOWER(events.title LIKE ?)", "%#{event_title}%") }

  def self.search_by_params(params)
    registrations = EventRegistration.all
    if params[:registrant_name].present?
      registrations = registrations.registrant_name(params[:registrant_name].downcase.strip)
    end
    if params[:event_name].present?
      registrations = registrations.event_title(params[:event_name].downcase.strip)
    end
    registrations
  end

  def name
    "(#{ registrant&.full_name }) #{ event.start_date.strftime("%Y-%m-%d @ %I:%M %p") }: #{ event.title }"
  end
end
