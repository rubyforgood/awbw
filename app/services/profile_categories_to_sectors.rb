# Turns people's profile-specific category tags (the retired workshop settings) into
# additional sectors, reading each category name through TagTranslation so the tag
# aliases (ADR-0007) decide what it means. Idempotent: a sector the person already
# carries keeps its primary flag. The category tags themselves are left in place.
#
# Organizations' sectors are a roll-up of their facilitators', so their tags are only
# counted, never converted.
class ProfileCategoriesToSectors
  Result = Data.define(:added, :people, :unmatched, :organization_tags)

  def self.items
    CategorizableItem.joins(category: :category_type)
      .where(category_types: { profile_specific: true })
      .where.not(category_types: { name: AgeGroupTaggable::AGE_RANGE_CATEGORY_TYPE })
  end

  # `log` receives one line per sector added, for the rake task's preview.
  def initialize(dry_run: false, log: nil)
    @dry_run = dry_run
    @log = log
  end

  def call
    translation = TagTranslation.new
    added = 0
    people = Set.new

    ActiveRecord::Base.transaction do
      self.class.items.where(categorizable_type: "Person").includes(:category, :categorizable).find_each do |item|
        person = item.categorizable
        next unless person

        translation.resolve(item.category.name).sector_ids.each do |sector_id|
          next if person.sectorable_items.exists?(sector_id: sector_id)

          person.sectorable_items.create!(sector_id: sector_id, is_primary: false)
          added += 1
          people << person.id
          @log&.call("  + person ##{person.id}: #{item.category.name.inspect} → #{Sector.find(sector_id).name}")
        end
      end

      raise ActiveRecord::Rollback if @dry_run
    end

    Result.new(added:, people: people.size, unmatched: translation.unmatched,
               organization_tags: self.class.items.where(categorizable_type: "Organization").count)
  end
end
