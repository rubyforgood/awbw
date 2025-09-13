class Quote < ApplicationRecord
  scope :active, -> { where(inactive: false) }

  def speaker
    speaker_name.nil? || speaker_name.empty?  ? "Participant" : speaker_name
  end
end
