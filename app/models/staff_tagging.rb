# Polymorphic join between a StaffTag and the record it tags (Person today).
class StaffTagging < ApplicationRecord
  belongs_to :staff_tag
  belongs_to :staff_taggable, polymorphic: true, touch: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  validates :staff_tag_id,
            uniqueness: { scope: [ :staff_taggable_type, :staff_taggable_id ], message: "has already been added" }

  before_create :stamp_created_by
  before_save :stamp_updated_by

  private

  # Current.user is set per request, so these work through nested attributes too.
  def stamp_created_by
    self.created_by ||= Current.user
  end

  def stamp_updated_by
    self.updated_by = Current.user if Current.user
  end
end
