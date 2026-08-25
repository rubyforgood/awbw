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

  # A { human label => count } of the records that would be reassigned off this
  # record on merge, skipping empty associations. Drives the preview so an admin
  # sees exactly what moves (affiliations, event registrations, reports, …).
  def reassignment_counts(record)
    reassignable_joins.each_with_object({}) do |join, counts|
      count = join[:join_class].where(join[:foreign_key] => record.id).count
      next if count.zero?

      counts[join_label(join[:join_class])] = count
    end
  end

  private

  # Every association that references this model by a foreign key — whether a
  # plain FK child (affiliations, reports), a polymorphic child (addresses via
  # as: :addressable), or a tagging join (categorizable_items). Each is reassigned
  # from the duplicate to the kept record on merge. Reflection-driven, so any
  # FK-based model works with no bespoke config.
  #
  # Sources are unioned: this model's own has_many/:as declarations, plus a scan
  # of every model for a non-polymorphic belongs_to pointing back here — so a
  # child with an organization_id but no inverse has_many (payments, stories, …)
  # is still reassigned rather than orphaned or blocked by its FK constraint.
  #
  # Collisions are resolved by DB *unique indexes*, not by guessing: the columns
  # of a unique index that includes the FK are the scope in which only one row may
  # exist (e.g. [category_id, categorizable_type, categorizable_id] →
  # [category_id, categorizable_type]), so a row the kept record already has is
  # deleted instead of violating the index.
  def reassignable_joins
    @reassignable_joins ||= begin
      seen = Set.new
      (has_many_joins + belongs_to_joins).select do |join|
        seen.add?([ join[:join_class].table_name, join[:foreign_key] ])
      end
    end
  end

  def has_many_joins
    model_class.reflect_on_all_associations(:has_many).filter_map do |assoc|
      next if assoc.options[:through]
      begin
        join_klass = assoc.klass
      rescue NameError
        next
      end

      fk = assoc.foreign_key.to_s
      next unless join_klass.column_names.include?(fk)

      join_for(join_klass, fk)
    end
  end

  # Schema-driven: every DB foreign key pointing at this model's table, so a child
  # with an organization_id but no inverse has_many (payments, stories, …) is still
  # reassigned. Reading the schema avoids eager-loading every model (which would
  # touch databases not configured in every environment).
  def belongs_to_joins
    connection = model_class.connection
    connection.tables.flat_map do |table|
      next [] if table == model_class.table_name

      connection.foreign_keys(table).filter_map do |fk_def|
        next unless fk_def.to_table == model_class.table_name

        join_for(model_for_table(table), fk_def.column.to_s)
      end
    end
  rescue NotImplementedError
    []
  end

  # The model backing a table, or an anonymous one bound to it. Guards against a
  # name that resolves to a class mapped elsewhere (e.g. an STI child of another
  # table), which would reassign the wrong table.
  def model_for_table(table)
    klass = table.classify.constantize
    return klass if klass.table_name == table

    anonymous_model_for(table)
  rescue NameError
    anonymous_model_for(table)
  end

  def anonymous_model_for(table)
    klass = Class.new(ApplicationRecord)
    klass.table_name = table
    klass
  end

  def join_for(join_klass, fk)
    {
      join_class: join_klass,
      foreign_key: fk.to_sym,
      natural_key: natural_key_columns(join_klass, fk)
    }
  end

  # Columns (other than the FK) of a unique index that includes the FK.
  def natural_key_columns(join_klass, fk)
    join_klass.connection.indexes(join_klass.table_name)
      .select(&:unique)
      .map { |index| Array(index.columns) }
      .select { |cols| cols.include?(fk) }
      .map { |cols| (cols - [ fk ]).map(&:to_sym) }
      .find(&:present?) || []
  end

  def model_label
    model_class.name.underscore.humanize.downcase
  end

  def join_label(join_class)
    (join_class.name || join_class.table_name.classify).underscore.humanize.pluralize
  end

  def usage_counts
    counts = Hash.new(0)
    reassignable_joins.each do |join|
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
      reassignable_joins.each do |join|
        merge_join(primary, dupe, join)
      end

      dupe.reload.destroy!
      logger.info "  deleted #{model_label} #{dupe.id}"
    end
  end

  def merge_join(primary, dupe, join)
    jc = join[:join_class]
    fk = join[:foreign_key]
    natural_key = join[:natural_key]

    if natural_key.empty?
      moved = jc.where(fk => dupe.id).update_all(fk => primary.id)
      logger.info "  moved #{moved} #{jc.name} to primary" if moved > 0
      return
    end

    existing = jc.where(fk => primary.id).pluck(*natural_key).map { |values| Array(values) }.to_set

    jc.where(fk => dupe.id).find_each do |item|
      key = natural_key.map { |col| item.public_send(col) }
      if existing.include?(key)
        item.destroy!
        logger.info "  deleted duplicate #{jc.name} #{item.id} (primary already has it)"
      else
        item.update!(fk => primary.id)
        existing << key
        logger.info "  moved #{jc.name} #{item.id} to primary"
      end
    end

    remaining = jc.where(fk => dupe.id).count
    raise "ABORT: #{remaining} #{jc.name} items still reference #{model_label} #{dupe.id}" if remaining > 0
  end
end
