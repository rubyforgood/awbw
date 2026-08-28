class CategorizableItem < ApplicationRecord
  include Timelineable

  def self.timeline_renderer_class
    NestedRecordTimelineRenderer
  end

  CATEGORIZABLE_TIMELINE_ATTRIBUTES = %w[ category_id is_primary ].freeze

  belongs_to :categorizable, polymorphic: true
  belongs_to :category

  # Validations
  validates_presence_of :categorizable_type, :categorizable_id, :category_id
  validates :category_id, uniqueness: { scope: [ :categorizable_type, :categorizable_id ] }

  def timeline_label
    "category '#{category.name}'"
  end

  def timeline_changes
    saved_changes
      .slice(*CATEGORIZABLE_TIMELINE_ATTRIBUTES)
      .transform_values { |(old_value, new_value)| [old_value.to_s, new_value.to_s] }
  end
end
