class EventStaff < ApplicationRecord
  belongs_to :event
  belongs_to :person

  validates :person_id, uniqueness: { scope: :event_id }

  normalizes :bio, with: ->(value) { value&.strip.presence }

  scope :ordered_by_name, -> {
    joins(:person).order(Arel.sql("people.first_name, people.last_name"))
  }

  # Bio shown on the public staff page. A per-event bio overrides the person's
  # profile bio; otherwise fall back to the profile bio when the person allows
  # it to be shown.
  def public_bio
    return bio if bio.present?
    person.bio if person&.profile_show_bio?
  end
end
