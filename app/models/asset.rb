class Asset < ApplicationRecord
  self.inheritance_column = :type

  belongs_to :owner, polymorphic: true
  belongs_to :report, optional: true

  has_one_attached :file, dependent: :purge do |attachable|
    attachable.variant :thumbnail,
      resize_to_limit: [ 256, 256 ],
      format: :jpeg,
      saver: { quality: 80 }
  end
end
