# lib/tasks/sector_dedupe.rake
namespace :tags do
  desc "Deduplicate sectors by normalized name and reassign sectorable_items"
  task dedupe_sectors: :environment do
    dry_run = ENV.fetch("DRY_RUN", "true") != "false"
    min_usage = ENV.fetch("MIN_USAGE", "0").to_i

    logger = Logger.new($stdout)
    logger.level = Logger::INFO

    logger.info "Starting sector dedupe"
    logger.info "DRY_RUN=#{dry_run}"
    logger.info "MIN_USAGE=#{min_usage}"

    usage_by_sector_id =
      SectorableItem
        .group(:sector_id)
        .count

    groups =
      Sector
        .all
        .group_by { |s| s.name.to_s.strip.downcase }

    groups.each do |normalized_name, sectors|
      next if sectors.size < 2

      # Optional usage threshold (skip high-risk groups)
      total_usage = sectors.sum { |s| usage_by_sector_id[s.id] || 0 }
      next if total_usage < min_usage

      sorted =
        sectors.sort_by do |s|
          [
            s.published ? 0 : 1,                    # published first
            -(usage_by_sector_id[s.id] || 0),       # highest usage
            s.created_at || Time.current            # oldest
          ]
        end

      primary    = sorted.first
      duplicates = sorted.drop(1)

      logger.info "-" * 80
      logger.info "GROUP: '#{normalized_name}'"
      logger.info "KEEP  #{primary.id} | #{primary.name} | usage=#{usage_by_sector_id[primary.id] || 0}"

      duplicates.each do |dupe|
        dupe_usage = usage_by_sector_id[dupe.id] || 0

        logger.info "MERGE #{dupe.id} | #{dupe.name} | usage=#{dupe_usage}"

        next if dry_run

        ActiveRecord::Base.transaction do
          moved =
            SectorableItem
              .where(sector_id: dupe.id)
              .update_all(sector_id: primary.id)

          logger.info "  moved #{moved} sectorable_items"

          remaining =
            SectorableItem
              .where(sector_id: dupe.id)
              .count

          if remaining > 0
            raise "ABORT: #{remaining} items still reference sector #{dupe.id}"
          end

          dupe.destroy!
          logger.info "  deleted sector #{dupe.id}"
        end
      end
    end

    logger.info "Sector dedupe complete"
  end

  desc "Deduplicate categories by normalized name and reassign categorizable_items"
  task dedupe_categories: :environment do
    dry_run   = ENV.fetch("DRY_RUN", "true") != "false"
    min_usage = ENV.fetch("MIN_USAGE", "0").to_i

    logger = Logger.new($stdout)
    logger.level = Logger::INFO

    logger.info "Starting category dedupe"
    logger.info "DRY_RUN=#{dry_run}"
    logger.info "MIN_USAGE=#{min_usage}"

    usage_by_category_id =
      CategorizableItem
        .group(:category_id)
        .count

    groups =
      Category
        .all
        .group_by { |c| c.name.to_s.strip.downcase }

    groups.each do |normalized_name, categories|
      next if categories.size < 2

      total_usage = categories.sum { |c| usage_by_category_id[c.id] || 0 }
      next if total_usage < min_usage

      sorted =
        categories.sort_by do |c|
          [
            c.respond_to?(:published) && c.published ? 0 : 1,
            -(usage_by_category_id[c.id] || 0),
            c.created_at || Time.current
          ]
        end

      primary    = sorted.first
      duplicates = sorted.drop(1)

      logger.info "-" * 80
      logger.info "GROUP: '#{normalized_name}'"
      logger.info "KEEP  #{primary.id} | #{primary.name} | usage=#{usage_by_category_id[primary.id] || 0}"

      duplicates.each do |dupe|
        dupe_usage = usage_by_category_id[dupe.id] || 0

        logger.info "MERGE #{dupe.id} | #{dupe.name} | usage=#{dupe_usage}"

        next if dry_run

        ActiveRecord::Base.transaction do
          moved =
            CategorizableItem
              .where(category_id: dupe.id)
              .update_all(category_id: primary.id)

          logger.info "  moved #{moved} categorizable_items"

          remaining =
            CategorizableItem
              .where(category_id: dupe.id)
              .count

          if remaining > 0
            raise "ABORT: #{remaining} items still reference category #{dupe.id}"
          end

          dupe.destroy!
          logger.info "  deleted category #{dupe.id}"
        end
      end
    end

    logger.info "Category dedupe complete"
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

      delete.each do |row|
        row.destroy!
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

      delete.each do |row|
        row.destroy!
      end
    end

    logger.info "Duplicate assignment cleanup complete"
  end
end
