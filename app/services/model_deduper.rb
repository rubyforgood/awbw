# frozen_string_literal: true

require "set"

class ModelDeduper
  attr_reader :model_class, :logger, :dry_run, :min_usage

  def initialize(model_class:, logger: Logger.new($stdout), dry_run: true, min_usage: 0)
    @model_class = model_class
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

  # Auto-detect all polymorphic join associations on the model.
  # Returns an array of hashes, each with :join_class, :foreign_key,
  # :polymorphic_type_column, and :polymorphic_id_column.
  def polymorphic_joins
    @polymorphic_joins ||= model_class.reflect_on_all_associations(:has_many).filter_map do |assoc|
      next if assoc.options[:through] # skip has_many :through
      begin
        join_klass = assoc.klass
      rescue NameError
        next
      end

      poly = join_klass.reflect_on_all_associations(:belongs_to).find(&:polymorphic?)
      next unless poly

      {
        join_class: join_klass,
        foreign_key: assoc.foreign_key.to_sym,
        polymorphic_type_column: poly.foreign_type.to_sym,
        polymorphic_id_column: poly.foreign_key.to_sym
      }
    end
  end

  def model_label
    model_class.name.underscore.humanize.downcase
  end

  def usage_counts
    counts = Hash.new(0)
    polymorphic_joins.each do |join|
      join[:join_class].where(join[:foreign_key] => model_class.pluck(:id))
        .group(join[:foreign_key]).count
        .each { |id, count| counts[id] += count }
    end
    counts
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
      polymorphic_joins.each do |join|
        merge_join(primary, dupe, join)
      end

      dupe.destroy!
      logger.info "  deleted #{model_label} #{dupe.id}"
    end
  end

  def merge_join(primary, dupe, join)
    jc = join[:join_class]
    fk = join[:foreign_key]
    type_col = join[:polymorphic_type_column]
    id_col = join[:polymorphic_id_column]

    if fk == id_col
      # Deduplicating the polymorphic side (e.g. Workshop via categorizable_items).
      # Use non-polymorphic FK columns for duplicate detection.
      other_fk_cols = jc.reflect_on_all_associations(:belongs_to)
        .reject(&:polymorphic?)
        .map { |a| a.foreign_key.to_s }

      existing_keys = if other_fk_cols.any?
        jc.where(fk => primary.id)
          .pluck(*other_fk_cols)
          .map { |vals| Array(vals).join("_") }
          .to_set
      else
        Set.new
      end

      jc.where(fk => dupe.id).find_each do |item|
        key = other_fk_cols.map { |c| item.public_send(c) }.join("_")
        if other_fk_cols.any? && existing_keys.include?(key)
          item.destroy!
          logger.info "  deleted duplicate #{jc.name} #{item.id} (primary already has it)"
        else
          item.update!(fk => primary.id)
          logger.info "  moved #{jc.name} #{item.id} to primary"
        end
      end
    else
      # Normal case: deduplicating the non-polymorphic side (e.g. Category via categorizable_items).
      existing_taggings = jc
        .where(fk => primary.id)
        .pluck(type_col, id_col)
        .map { |type, id| "#{type}_#{id}" }
        .to_set

      jc.where(fk => dupe.id).find_each do |item|
        tagging_key = "#{item.public_send(type_col)}_#{item.public_send(id_col)}"

        if existing_taggings.include?(tagging_key)
          item.destroy!
          logger.info "  deleted duplicate #{jc.name} #{item.id} (primary already has it)"
        else
          item.update!(fk => primary.id)
          logger.info "  moved #{jc.name} #{item.id} to primary"
        end
      end
    end

    remaining = jc.where(fk => dupe.id).count
    raise "ABORT: #{remaining} #{jc.name} items still reference #{model_label} #{dupe.id}" if remaining > 0
  end
end
