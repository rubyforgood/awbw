class StaffTagging < ApplicationRecord
  include Communicable
  include Timelineable

  def self.timeline_renderer_class
    NestedRecordTimelineRenderer
  end

  STAFF_TAGGING_TIMELINE_ATTRIBUTES = %w[ staff_tag_id ].freeze

  belongs_to :staff_tag
  belongs_to :staff_taggable, polymorphic: true, touch: true
  belongs_to :created_by, class_name: "User", optional: true
  belongs_to :updated_by, class_name: "User", optional: true

  has_many :comments, -> { newest_first }, as: :commentable, dependent: :destroy
  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attrs| attrs["body"].blank? }

  validates :staff_tag_id,
            uniqueness: { scope: [ :staff_taggable_type, :staff_taggable_id ], message: "has already been added" }

  # The taggable is always a Person today; guard the polymorphism so a comm logged
  # here is addressed to them.
  def communications_email
    staff_taggable.try(:preferred_email)
  end

  before_create :stamp_created_by
  before_save :stamp_updated_by

  def timeline_label
    "Tag: #{staff_tag.name}"
  end

  def timeline_changes
    saved_changes
      .slice(*STAFF_TAGGING_TIMELINE_ATTRIBUTES)
      .transform_values { |(old_value, new_value)| [old_value.to_s, new_value.to_s] }
  end

  private

  def stamp_created_by
    self.created_by ||= Current.user
  end

  def stamp_updated_by
    self.updated_by = Current.user if Current.user
  end
end
