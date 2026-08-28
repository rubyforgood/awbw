class SectorableItem < ApplicationRecord
  belongs_to :sector
  belongs_to :sectorable, polymorphic: true, touch: true
  has_many :people, through: :sectorable_items, source: :sectorable, source_type: "Person"

  # Validations
  validates_presence_of :sector_id
  validates :sector_id, uniqueness: { scope: [ :sectorable_type, :sectorable_id ], message: "has already been added" }

  before_create :skip_if_duplicate

  # A tagging reads as the sector it applied. Only a workshop log carries a title
  # and a windows type to compose with it — an organization or a person doesn't,
  # and asking for one raised.
  def title
    return sector&.name.to_s unless sectorable.is_a?(WorkshopLog)

    "#{sectorable.title} - #{sectorable.windows_type&.name}"
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
