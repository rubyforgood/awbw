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
  # unsaved items after a failed save. Used by profile, recipients, and dashboard
  # views, where the primary should always lead.
  def sectorable_items_primary_first
    sectorable_items.sort_by { |item| [ item.is_primary? ? 0 : 1, item.sector&.name.to_s.downcase ] }
  end

  # Sectorable items in stable order for the edit form: alphabetically by sector
  # name (sectors have no position column, so name is the position-equivalent).
  # Unlike sectorable_items_primary_first, the primary is NOT floated to the top,
  # so starring a sector on the form doesn't reshuffle the chips.
  def sectorable_items_ordered
    sectorable_items.sort_by { |item| item.sector&.name.to_s.downcase }
  end

  # Additively tag sectors as primary/additional without disturbing other
  # taggings — used by registration, where a respondent names a single primary
  # sector (the dropdown) plus any number of additional sectors (the checkboxes).
  # Mirrors AgeGroupTaggable#tag_age_groups, but upholds the single-primary rule:
  # at most one id is promoted, and any prior primary the respondent didn't
  # re-select is demoted first. A sector listed as both primary and additional is
  # treated as primary.
  def tag_sectors(primary_ids:, additional_ids:)
    primary = sanitize_sector_ids(primary_ids).first(1)
    additional = sanitize_sector_ids(additional_ids) - primary

    demote_unselected_primary_sectors(primary) if primary.any?
    upsert_sector_items(primary, is_primary: true)
    upsert_sector_items(additional, is_primary: false)
    sectorable_items.reset
  end

  private

  # Demote any currently-primary sector that isn't the newly selected primary, so
  # promoting the new pick never leaves two primaries behind.
  def demote_unselected_primary_sectors(primary_ids)
    sectorable_items.where(is_primary: true).where.not(sector_id: primary_ids)
      .update_all(is_primary: false)
  end

  def upsert_sector_items(sector_ids, is_primary:)
    # "Other" is the free-text catch-all, never a real tag — a typed "Other" is
    # captured as an OtherResponse, so it must not become a SectorableItem even
    # if its id slips into the submitted set.
    Sector.where(id: sector_ids).excluding_other.find_each do |sector|
      item = sectorable_items.find_or_initialize_by(sector: sector)
      item.is_primary = is_primary
      item.save!
    end
  end

  def sanitize_sector_ids(ids)
    Array(ids).reject(&:blank?).map(&:to_i)
  end

  def at_most_one_primary_sector
    # Count the in-memory set (not a DB query): with nested attributes both
    # primaries are built and saved in one transaction, so a row-level check
    # would see neither persisted yet and let both through.
    primary_count = sectorable_items.reject(&:marked_for_destruction?).count(&:is_primary?)
    return if primary_count <= 1

    errors.add(:base, "Only one sector can be marked as primary")
  end
end
