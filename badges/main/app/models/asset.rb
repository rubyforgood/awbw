class Asset < ApplicationRecord
  self.inheritance_column = :type

  belongs_to :owner, polymorphic: true
  belongs_to :report, optional: true
  # Images
  has_one_attached :file, dependent: :purge
end
