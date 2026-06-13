# Shared sector-tagging rules for models that own sectorable_items (Person,
# Organization). Currently enforces that at most one tagged sector is marked
# primary; the chip editor's single-star UI is the first line of defense, this
# is the data-integrity guarantee for imports, the console, and any future API.
module SectorsTaggable
  extend ActiveSupport::Concern

  included do
    validate :at_most_one_primary_sector
  end

  # Sectorable items ordered for display: the primary sector first, then the
  # rest alphabetically by sector name. Sorts the in-memory association rather
  # than issuing a query, so it stays correct when a form re-renders its
  # unsaved items after a failed save.
  def sectorable_items_primary_first
    sectorable_items.sort_by { |item| [ item.is_primary? ? 0 : 1, item.sector&.name.to_s.downcase ] }
  end

  private

  def at_most_one_primary_sector
    # Count the in-memory set (not a DB query): with nested attributes both
    # primaries are built and saved in one transaction, so a row-level check
    # would see neither persisted yet and let both through.
    primary_count = sectorable_items.reject(&:marked_for_destruction?).count(&:is_primary?)
    return if primary_count <= 1

    errors.add(:base, "Only one sector can be marked as primary")
  end
end
