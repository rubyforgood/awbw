# frozen_string_literal: true

require "set"

class SectorDeduper
  attr_reader :logger, :dry_run, :min_usage

  def initialize(logger: Logger.new($stdout), dry_run: true, min_usage: 0)
    @logger = logger
    @dry_run = dry_run
    @min_usage = min_usage
  end

  def call
    logger.info "Starting sector dedupe"
    logger.info "DRY_RUN=#{dry_run}"
    logger.info "MIN_USAGE=#{min_usage}"

    usage_by_sector_id = SectorableItem.group(:sector_id).count
    groups = Sector.all.group_by { |s| s.name.to_s.strip.downcase }

    groups.each do |normalized_name, sectors|
      next if sectors.size < 2

      total_usage = sectors.sum { |s| usage_by_sector_id[s.id] || 0 }
      next if total_usage < min_usage

      deduplicate_group(normalized_name, sectors, usage_by_sector_id)
    end

    logger.info "Sector dedupe complete"
  end

  private

  def deduplicate_group(normalized_name, sectors, usage_by_sector_id)
    sorted = sectors.sort_by do |s|
      [
        s.published? ? 0 : 1,
        -(usage_by_sector_id[s.id] || 0),
        s.created_at || Time.current
      ]
    end

    primary = sorted.first
    duplicates = sorted.drop(1)

    logger.info "-" * 80
    logger.info "GROUP: '#{normalized_name}'"
    logger.info "KEEP  #{primary.id} | #{primary.name} | usage=#{usage_by_sector_id[primary.id] || 0}"

    duplicates.each do |dupe|
      merge_duplicate(primary, dupe, usage_by_sector_id)
    end
  end

  def merge_duplicate(primary, dupe, usage_by_sector_id)
    dupe_usage = usage_by_sector_id[dupe.id] || 0
    logger.info "MERGE #{dupe.id} | #{dupe.name} | usage=#{dupe_usage}"

    return if dry_run

    ActiveRecord::Base.transaction do
      existing_taggings = SectorableItem
        .where(sector_id: primary.id)
        .pluck(:sectorable_type, :sectorable_id)
        .map { |type, id| "#{type}_#{id}" }
        .to_set

      items_to_move = SectorableItem.where(sector_id: dupe.id)

      items_to_move.find_each do |item|
        tagging_key = "#{item.sectorable_type}_#{item.sectorable_id}"

        if existing_taggings.include?(tagging_key)
          item.destroy!
          logger.info "  deleted duplicate tagging #{item.id} (primary already has it)"
        else
          item.update!(sector_id: primary.id)
          logger.info "  moved tagging #{item.id} to primary"
        end
      end

      remaining = SectorableItem.where(sector_id: dupe.id).count

      raise "ABORT: #{remaining} items still reference sector #{dupe.id}" if remaining > 0

      dupe.destroy!
      logger.info "  deleted sector #{dupe.id}"
    end
  end
end
