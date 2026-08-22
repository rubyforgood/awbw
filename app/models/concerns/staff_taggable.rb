# Mixed into models that can carry internal admin StaffTags (Person today). The
# join is polymorphic, so adding another taggable model later is just an include.
# StaffTags are admin-only and never surfaced publicly — the visibility boundary
# lives in StaffTagPolicy and the views, not here.
module StaffTaggable
  extend ActiveSupport::Concern

  included do
    has_many :staff_taggings, as: :staff_taggable, dependent: :destroy
    has_many :staff_tags, through: :staff_taggings
  end
end
