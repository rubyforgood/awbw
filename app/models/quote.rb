class Quote < ApplicationRecord
  has_many :quotable_item_quotes, dependent: :destroy

  validates :quote, presence: true, unless: -> { quote.blank? }

  scope :active, -> { where(inactive: false) }

  def speaker
    speaker_name.nil? || speaker_name.empty?  ? "Participant" : speaker_name
  end

  def name
    quote.truncate(30)
  end
end
