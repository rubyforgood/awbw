# That a person completed an anonymous form for an event — never which submission
# was theirs. Keeps a date only (no timestamps), so it can't be lined up with the
# person-less FormSubmission it accompanies.
class FormCompletion < ApplicationRecord
  belongs_to :person
  belongs_to :form
  belongs_to :event

  validates :completed_on, presence: true
  validates :form_id, uniqueness: { scope: %i[person_id event_id] }

  def self.record!(person:, form:, event:)
    find_or_create_by!(person:, form:, event:) { |completion| completion.completed_on = Date.current }
  end
end
