class WindowsType < ApplicationRecord
  TYPES = ["Adult", "Children's", "Combined"]

  has_many :workshops
  has_many :age_ranges
  has_many :reports
  has_many :form_builders
end
