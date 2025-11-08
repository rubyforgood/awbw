class SectorableItem < ApplicationRecord
  # Associations
  belongs_to :sector
  belongs_to :sectorable, polymorphic: true
  has_many :facilitators, through: :sectorable_items, source: :sectorable, source_type: "Facilitator"

  # validates :sectorable, uniqueness: { scope: :sector }
  # validates_uniqueness_of [:sector, :sectorable]
  # validates :sector_id, uniqueness: { scope: [ :sectorable_type, :sectorable_id ] }
  # Attr Access
  attr_accessor :_create

  # Validations
  # validates_presence_of :sectorable_type, :sectorable_id, :sector_id

  # Methods
  def title
    return id unless sectorable && sectorable.class != WorkshopLog
    "#{sectorable.title} - #{sectorable.windows_type.name if sectorable.windows_type}"
  end

  private
end
