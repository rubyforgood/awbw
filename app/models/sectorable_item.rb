class SectorableItem < ApplicationRecord
  attr_accessor :_create

  belongs_to :sector
  belongs_to :sectorable, polymorphic: true, optional: true
  has_many :facilitators, through: :sectorable_items, source: :sectorable, source_type: "Facilitator"

  # Validations
  # Note: sectorable_id will be set by Rails when the parent is saved
  # so we don't validate its presence during build phase
  validates_presence_of :sectorable_type, :sector_id
  validates :sector_id, uniqueness: { scope: [ :sectorable_type, :sectorable_id ] }, if: -> { sectorable_id.present? }

  scope :published, -> { where(inactive: false) }

  # Methods
  def title
    return id unless sectorable && sectorable.class != WorkshopLog
    "#{sectorable.title} - #{sectorable.windows_type.name if sectorable.windows_type}"
  end

  private
end
