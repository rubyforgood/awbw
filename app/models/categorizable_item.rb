class CategorizableItem < ApplicationRecord
  include Timelineable

  def self.timeline_renderer_class
    NestedRecordTimelineRenderer
  end

  belongs_to :categorizable, polymorphic: true
  belongs_to :category

  # Validations
  validates_presence_of :categorizable_type, :categorizable_id, :category_id
  validates :category_id, uniqueness: { scope: [ :categorizable_type, :categorizable_id ] }

  def timeline_label
    "category '#{category.name}'"
  end
end
