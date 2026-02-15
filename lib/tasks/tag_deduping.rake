# lib/tasks/tag_deduping.rake

namespace :tags do
  desc "Deduplicate sectors by normalized name and reassign sectorable_items"
  task dedupe_sectors: :environment do
    dry_run = ENV.fetch("DRY_RUN", "true") != "false"
    min_usage = ENV.fetch("MIN_USAGE", "0").to_i

    logger = Logger.new($stdout)
    logger.level = Logger::INFO

    ModelDeduper.new(model_class: Sector, logger: logger, dry_run: dry_run, min_usage: min_usage).call
  end

  desc "Deduplicate categories by normalized name and reassign categorizable_items"
  task dedupe_categories: :environment do
    dry_run = ENV.fetch("DRY_RUN", "true") != "false"
    min_usage = ENV.fetch("MIN_USAGE", "0").to_i

    logger = Logger.new($stdout)
    logger.level = Logger::INFO

    ModelDeduper.new(model_class: Category, logger: logger, dry_run: dry_run, min_usage: min_usage).call
  end

  desc "Delete duplicate sectorable_items and categorizable_items"
  task dedupe_assignments: :environment do
    dry_run = ENV.fetch("DRY_RUN", "true") != "false"
    logger = Logger.new($stdout)
    logger.level = Logger::INFO
    logger.info "Starting duplicate assignment cleanup"
    logger.info "DRY_RUN=#{dry_run}"
    # ------------------------------------------------------------
    # SectorableItem duplicates
    # ------------------------------------------------------------
    logger.info "Checking SectorableItem duplicates"
    sector_dupes =
      SectorableItem
        .group(:sector_id, :sectorable_type, :sectorable_id)
        .having("COUNT(*) > 1")
        .pluck(:sector_id, :sectorable_type, :sectorable_id)
    sector_dupes.each do |sector_id, type, owner_id|
      rows =
        SectorableItem
          .where(
            sector_id: sector_id,
            sectorable_type: type,
            sectorable_id: owner_id
          )
          .order(:id)
      keep = rows.first
      delete = rows.drop(1)

      logger.info(
        "SectorableItem DUPES " \
          "sector_id=#{sector_id} " \
          "#{type}(#{owner_id}) " \
          "KEEP=#{keep.id} DELETE=#{delete.map(&:id)}"
      )
      next if dry_run
      ActiveRecord::Base.transaction do
        delete.each do |row|
          row.destroy!
        end
        logger.info "  deleted #{delete.size} duplicate sectorable_items"
      end
    end

    # ------------------------------------------------------------
    # CategorizableItem duplicates
    # ------------------------------------------------------------
    logger.info "Checking CategorizableItem duplicates"
    category_dupes =
      CategorizableItem
        .group(:category_id, :categorizable_type, :categorizable_id)
        .having("COUNT(*) > 1")
        .pluck(:category_id, :categorizable_type, :categorizable_id)
    category_dupes.each do |category_id, type, owner_id|
      rows =
        CategorizableItem
          .where(
            category_id: category_id,
            categorizable_type: type,
            categorizable_id: owner_id
          )
          .order(:id)
      keep = rows.first
      delete = rows.drop(1)

      logger.info(
        "CategorizableItem DUPES " \
          "category_id=#{category_id} " \
          "#{type}(#{owner_id}) " \
          "KEEP=#{keep.id} DELETE=#{delete.map(&:id)}"
      )
      next if dry_run
      ActiveRecord::Base.transaction do
        delete.each do |row|
          row.destroy!
        end
        logger.info "  deleted #{delete.size} duplicate categorizable_items"
      end
    end
    logger.info "Duplicate assignment cleanup complete"
  end
end
