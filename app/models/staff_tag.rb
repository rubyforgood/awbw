class StaffTag < ApplicationRecord
  include Publishable

  # Seeded in all environments (db/seeds.rb); the seed never overwrites admin edits.
  SEED = {
    "Potential future trainer" => "Facilitator we'd consider inviting to train others.",
    "Sector leader candidate" => "Potential future sector leader.",
    "Highlight roster" => "Facilitators to spotlight.",
    "Leads non-English workshops" => "Leads workshops in a language other than English (from annual eval).",
    "DV Leadership Cohort" => "Possible member of a domestic-violence leadership cohort.",
    "Foster Care Roundtable outreach" => "Possible outreach for a foster-care roundtable."
  }.freeze

  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true
  has_many :staff_taggings, dependent: :restrict_with_error
  has_many :people, through: :staff_taggings, source: :staff_taggable, source_type: "Person"

  validates :name, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }

  scope :ordered, -> { order(:name) }

  def to_s
    name
  end
end
