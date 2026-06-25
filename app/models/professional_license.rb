class ProfessionalLicense < ApplicationRecord
  has_paper_trail

  belongs_to :person
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :continuing_education_registrations, dependent: :destroy

  validates :number, uniqueness: { scope: :person_id }, allow_nil: true

  # Find the person's license for this number, or create it. A blank number
  # resolves to the person's single placeholder license (number nil) so a CE
  # opt-in without a number on file never spawns duplicate placeholders.
  def self.find_or_create_for(person:, number: nil)
    find_or_create_by(person: person, number: number.presence)
  end

  # Completeness: have we recorded the actual license number yet?
  def number_known?
    number.present?
  end

  # Validity: a license with a past expiration is expired. Unknown when no
  # expiration is on file.
  def expired?
    expires_on.present? && expires_on.past?
  end

  def label
    [ kind, number ].compact_blank.join(" ").presence || "License (number pending)"
  end
end
