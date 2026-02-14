# frozen_string_literal: true

require "set"

class CategoryDeduper
  attr_reader :logger, :dry_run, :min_usage

  def initialize(logger: Logger.new($stdout), dry_run: true, min_usage: 0)
    @logger = logger
    @dry_run = dry_run
    @min_usage = min_usage
  end

  def call
    logger.info "Starting category dedupe"
    logger.info "DRY_RUN=#{dry_run}"
    logger.info "MIN_USAGE=#{min_usage}"

    usage_by_category_id = CategorizableItem.group(:category_id).count
    groups = Category.all.group_by { |c| c.name.to_s.strip.downcase }

    groups.each do |normalized_name, categories|
      next if categories.size < 2

      total_usage = categories.sum { |c| usage_by_category_id[c.id] || 0 }
      next if total_usage < min_usage

      deduplicate_group(normalized_name, categories, usage_by_category_id)
    end

    logger.info "Category dedupe complete"
  end

  private

  def deduplicate_group(normalized_name, categories, usage_by_category_id)
    sorted = categories.sort_by do |c|
      [
        c.published? ? 0 : 1,
        -(usage_by_category_id[c.id] || 0),
        c.created_at || Time.current
      ]
    end

    primary = sorted.first
    duplicates = sorted.drop(1)

    logger.info "-" * 80
    logger.info "GROUP: '#{normalized_name}'"
    logger.info "KEEP  #{primary.id} | #{primary.name} | usage=#{usage_by_category_id[primary.id] || 0}"

    duplicates.each do |dupe|
      merge_duplicate(primary, dupe, usage_by_category_id)
    end
  end

  def merge_duplicate(primary, dupe, usage_by_category_id)
    dupe_usage = usage_by_category_id[dupe.id] || 0
    logger.info "MERGE #{dupe.id} | #{dupe.name} | usage=#{dupe_usage}"

    return if dry_run

    ActiveRecord::Base.transaction do
      existing_taggings = CategorizableItem
        .where(category_id: primary.id)
        .pluck(:categorizable_type, :categorizable_id)
        .map { |type, id| "#{type}_#{id}" }
        .to_set

      items_to_move = CategorizableItem.where(category_id: dupe.id)

      items_to_move.find_each do |item|
        tagging_key = "#{item.categorizable_type}_#{item.categorizable_id}"

        if existing_taggings.include?(tagging_key)
          item.destroy!
          logger.info "  deleted duplicate tagging #{item.id} (primary already has it)"
        else
          item.update!(category_id: primary.id)
          logger.info "  moved tagging #{item.id} to primary"
        end
      end

      remaining = CategorizableItem.where(category_id: dupe.id).count

      raise "ABORT: #{remaining} items still reference category #{dupe.id}" if remaining > 0

      dupe.destroy!
      logger.info "  deleted category #{dupe.id}"
    end
  end
end
