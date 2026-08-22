# Join between a StaffTag and the record it tags (Person today; polymorphic so
# organizations/events/etc. can opt in later). created_by records which admin
# applied the tag, and when.
class StaffTagging < ApplicationRecord
  belongs_to :staff_tag
  belongs_to :staff_taggable, polymorphic: true, touch: true
  belongs_to :created_by, class_name: "User", optional: true

  validates :staff_tag_id,
            uniqueness: { scope: [ :staff_taggable_type, :staff_taggable_id ], message: "has already been added" }

  before_create :stamp_created_by

  private

  # Record which admin applied the tag. Current.user is set per request, so this
  # works whether the tagging is built through nested attributes or directly.
  def stamp_created_by
    self.created_by ||= Current.user
  end
end
