# frozen_string_literal: true

class SectorDeduper < BaseDeduper
  # Public alias for backwards compatibility
  def merge_sectors(sector_to_keep, sector_to_delete)
    merge(sector_to_keep, sector_to_delete)
  end

  private

  def model_class = Sector
  def join_class = SectorableItem
  def foreign_key = :sector_id
  def polymorphic_type_column = :sectorable_type
  def polymorphic_id_column = :sectorable_id
end
