class SectorableItem < ApplicationRecord
  belongs_to :sector
  belongs_to :sectorable, polymorphic: true, touch: true
  has_many :people, through: :sectorable_items, source: :sectorable, source_type: "Person"

  # Validations
  validates_presence_of :sector_id
  validates :sector_id, uniqueness: { scope: [ :sectorable_type, :sectorable_id ], message: "has already been added" }

  before_create :skip_if_duplicate

  # Methods
  def title
    return id unless sectorable && sectorable.class != WorkshopLog
    "#{sectorable.title} - #{sectorable.windows_type.name if sectorable.windows_type}"
  end

  private

  def skip_if_duplicate
    return if sector_id.blank?

    exists = SectorableItem.where(
      sector_id: sector_id,
      sectorable_type: sectorable_type,
      sectorable_id: sectorable_id
    ).exists?

    throw(:abort) if exists
  end
end
