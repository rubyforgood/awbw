# frozen_string_literal: true

require "set"

class BaseDeduper
  attr_reader :logger, :dry_run, :min_usage

  def initialize(logger: Logger.new($stdout), dry_run: true, min_usage: 0)
    @logger = logger
    @dry_run = dry_run
    @min_usage = min_usage
  end

  def call
    logger.info "Starting #{model_label} dedupe"
    logger.info "DRY_RUN=#{dry_run}"
    logger.info "MIN_USAGE=#{min_usage}"

    usage = usage_counts
    groups = model_class.all.group_by { |r| r.name.to_s.strip.downcase }

    groups.each do |normalized_name, records|
      next if records.size < 2

      total_usage = records.sum { |r| usage[r.id] || 0 }
      next if total_usage < min_usage

      deduplicate_group(normalized_name, records, usage)
    end

    logger.info "#{model_label.capitalize} dedupe complete"
  end

  def merge(record_to_keep, record_to_delete)
    merge_duplicate(record_to_keep, record_to_delete, usage_counts)
  end

  private

  # Subclasses must implement these:

  def model_class
    raise NotImplementedError
  end

  def join_class
    raise NotImplementedError
  end

  def foreign_key
    raise NotImplementedError
  end

  def polymorphic_type_column
    raise NotImplementedError
  end

  def polymorphic_id_column
    raise NotImplementedError
  end

  def model_label
    model_class.name.underscore.humanize.downcase
  end

  def usage_counts
    join_class.group(foreign_key).count
  end

  def deduplicate_group(normalized_name, records, usage)
    sorted = records.sort_by do |r|
      [
        r.published? ? 0 : 1,
        -(usage[r.id] || 0),
        r.created_at || Time.current
      ]
    end

    primary = sorted.first
    duplicates = sorted.drop(1)

    logger.info "-" * 80
    logger.info "GROUP: '#{normalized_name}'"
    logger.info "KEEP  #{primary.id} | #{primary.name} | usage=#{usage[primary.id] || 0}"

    duplicates.each do |dupe|
      merge_duplicate(primary, dupe, usage)
    end
  end

  def merge_duplicate(primary, dupe, usage)
    dupe_usage = usage[dupe.id] || 0
    logger.info "MERGE #{dupe.id} | #{dupe.name} | usage=#{dupe_usage}"

    return if dry_run

    ActiveRecord::Base.transaction do
      existing_taggings = join_class
        .where(foreign_key => primary.id)
        .pluck(polymorphic_type_column, polymorphic_id_column)
        .map { |type, id| "#{type}_#{id}" }
        .to_set

      items_to_move = join_class.where(foreign_key => dupe.id)

      items_to_move.find_each do |item|
        tagging_key = "#{item.public_send(polymorphic_type_column)}_#{item.public_send(polymorphic_id_column)}"

        if existing_taggings.include?(tagging_key)
          item.destroy!
          logger.info "  deleted duplicate tagging #{item.id} (primary already has it)"
        else
          item.update!(foreign_key => primary.id)
          logger.info "  moved tagging #{item.id} to primary"
        end
      end

      remaining = join_class.where(foreign_key => dupe.id).count
      raise "ABORT: #{remaining} items still reference #{model_label} #{dupe.id}" if remaining > 0

      dupe.destroy!
      logger.info "  deleted #{model_label} #{dupe.id}"
    end
  end
end
