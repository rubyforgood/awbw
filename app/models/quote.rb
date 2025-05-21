class Quote < ApplicationRecord
  scope :active, -> { where(inactive: false) }
  rails_admin do
    field :quote
    field :speaker_name do
      label 'Speaker'
    end
    field :inactive
    field :legacy
    field :workshop_id
    field :age
    field :gender
  end

  def speaker
    speaker_name.nil? || speaker_name.empty?  ? "Participant" : speaker_name
  end
end
