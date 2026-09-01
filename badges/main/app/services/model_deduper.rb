# frozen_string_literal: true

require "set"

class ModelDeduper
  attr_reader :model_class, :logger, :dry_run, :min_usage

  def initialize(model_class:, logger: Logger.new($stdout), dry_run: true, min_usage: 0, movable_attachments: [])
    @model_class = model_class
    @logger = logger
    @dry_run = dry_run
    @min_usage = min_usage
    @movable_attachments = Array(movable_attachments).map(&:to_s)
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
      count = join_references(join, record.id).count
      next if count.zero?

      counts[join_label(join[:join_class])] = count
    end
  end

  # Like #reassignment_counts, but also the record names per association so the
  # preview can show *what* moves, not just how many. Names are capped so a huge
  # association can't bloat the page; anything past the cap is reported as a count.
  # Each entry is { label:, count:, names: [ up to NAME_LIMIT display strings ] }.
  NAME_LIMIT = 50

  def reassignment_preview(record)
    reassignable_joins.filter_map do |join|
      scope = join_references(join, record.id)
      count = scope.count
      next if count.zero?

      {
        label: join_label(join[:join_class]),
        count: count,
        names: scope.limit(NAME_LIMIT).map { |related| record_display(related) }
      }
    end.sort_by { |entry| entry[:label] }
  end

  # A best-effort human name for an associated record: its own name/title, else a
  # named parent (e.g. an affiliation's person), else its id.
  def record_display(record)
    own = display_string(record)
    return own if own

    record.class.reflect_on_all_associations(:belongs_to).each do |assoc|
      next if assoc.polymorphic?

      related = record.try(assoc.name)
      parent = display_string(related)
      return parent if parent
    end
    "##{record.id}"
  end

  def display_string(record)
    return unless record

    %i[name title full_name].filter_map { |method| record.try(method).presence }.first
  end

  # Polymorphic references the merge repoints to the kept record (type stays, id
  # moves) so analytics and audit history follow the survivor instead of orphaning.
  # table => [ type_column, id_column ].
  REASSIGNED_POLYMORPHIC_REFERENCES = {
    "ahoy_events" => %w[resource_type resource_id],
    "versions" => %w[item_type item_id]
  }.freeze

  # References that are lost with the deleted record (its own attached files purge)
  # rather than moved — surfaced on the preview so an admin sees the loss.
  LOST_POLYMORPHIC_REFERENCES = { "active_storage_attachments" => %w[record_type record_id] }.freeze

  # Billing links between orgs need a deliberate decision (rubyforgood/awbw#2378);
  # skipped here so they neither block nor silently move.
  DEFERRED_REFERENCE_TABLES = %w[
    pay_customers pay_merchants pay_subscriptions pay_charges pay_payment_methods pay_webhooks
  ].freeze

  # Framework internals that purge with the record and aren't worth surfacing.
  IGNORED_REFERENCE_TABLES = %w[
    action_text_rich_texts action_text_mentions ckeditor_assets
    active_storage_blobs active_storage_variant_records ahoy_visits
  ].freeze

  HANDLED_ELSEWHERE_TABLES = (
    REASSIGNED_POLYMORPHIC_REFERENCES.keys + LOST_POLYMORPHIC_REFERENCES.keys +
    DEFERRED_REFERENCE_TABLES + IGNORED_REFERENCE_TABLES
  ).freeze

  # Attached files that are deleted with the record, not moved. Any attachment
  # named in `movable_attachments` is excluded here — it's reported by
  # #attachment_plan instead, which decides move-vs-drop against the keeper.
  # Each entry is { label:, count: } — drives the preview's "will be lost" note.
  def lost_references(record)
    LOST_POLYMORPHIC_REFERENCES.filter_map do |table, (type_column, id_column)|
      next unless reference_table_present?(table)

      klass = model_for_table(table)
      next unless klass.column_names.include?(id_column)

      scope = klass.where(type_column => model_class.polymorphic_name, id_column => record.id)
      scope = scope.where.not(name: @movable_attachments) if @movable_attachments.any? && klass.column_names.include?("name")
      count = scope.count
      next if count.zero?

      { label: "Attached files", count: count }
    end
  end

  # For each `movable_attachments` name the deleted record has: whether it will
  # MOVE to the keeper (keeper has none) or be DROPPED (keeper already has one).
  # Each entry is { name:, label:, action: :move | :drop }.
  def attachment_plan(record_to_keep, record_to_delete)
    @movable_attachments.filter_map do |name|
      next unless record_to_delete.public_send(name).attached?

      action = record_to_keep.public_send(name).attached? ? :drop : :move
      { name: name, label: name.humanize, action: action }
    end
  end

  # Defensive safeguard: tables that still reference `record` but that the merge
  # would NOT reassign — e.g. a new association added to the model that this flow
  # doesn't yet account for. Data-driven (it checks the actual record) and
  # independent of any `dependent:` option, so a future association can't silently
  # orphan rows or break referential integrity. Each entry is { table:, column: }.
  def unhandled_references(record)
    covered = reassignable_joins.map { |join| [ join[:join_class].table_name, join[:foreign_key].to_s ] }.to_set
    connection = model_class.connection
    convention_fk = "#{model_class.model_name.singular}_id"
    polymorphic_name = model_class.polymorphic_name

    connection.tables.flat_map do |table|
      next [] if table == model_class.table_name || HANDLED_ELSEWHERE_TABLES.include?(table)

      column_names = connection.columns(table).map(&:name)
      gaps = []

      if column_names.include?(convention_fk) && !covered.include?([ table, convention_fk ]) &&
          model_for_table(table).where(convention_fk => record.id).exists?
        gaps << { table: table, column: convention_fk }
      end

      column_names.each do |column|
        next unless column.end_with?("_type")

        id_column = column.sub(/_type\z/, "_id")
        next unless column_names.include?(id_column)
        next if covered.include?([ table, id_column ])
        next unless model_for_table(table).where(column => polymorphic_name, id_column => record.id).exists?

        gaps << { table: table, column: id_column }
      end

      gaps.uniq
    end.uniq
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

      # A polymorphic `has_many … as:` (allocations, comments) is scoped by its
      # `*_type` column too, so a merge only moves this model's own rows and can't
      # steal another type's rows that happen to share the deleted record's id.
      type_column = assoc.type.to_s if assoc.options[:as]
      type_column = nil unless type_column && join_klass.column_names.include?(type_column)

      join_for(join_klass, fk, type_column: type_column)
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

  def join_for(join_klass, fk, type_column: nil)
    {
      join_class: join_klass,
      foreign_key: fk.to_sym,
      type_column: type_column,
      natural_key: natural_key_columns(join_klass, fk)
    }
  end

  # Rows of `join` that reference `id` — narrowed to this model's polymorphic type
  # when the join is a polymorphic `as:` association, so it never touches another
  # type's rows sharing the same id.
  def join_references(join, id)
    scope = join[:join_class].where(join[:foreign_key] => id)
    scope = scope.where(join[:type_column] => model_class.polymorphic_name) if join[:type_column]
    scope
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

      reassign_polymorphic_references(primary, dupe)
      move_attachments(primary, dupe)

      dupe.reload.destroy!
      logger.info "  deleted #{model_label} #{dupe.id}"
    end
  end

  # Reassign each movable attachment from the dupe to the kept record when the
  # keeper has none; otherwise leave it on the dupe so it purges on destroy. The
  # attachment row's record_id moves (record_type is unchanged — same model), so
  # the file follows the survivor instead of being lost with the deleted record.
  def move_attachments(primary, dupe)
    @movable_attachments.each do |name|
      next unless dupe.public_send(name).attached?
      next if primary.public_send(name).attached?

      ActiveStorage::Attachment.where(record: dupe, name: name).update_all(record_id: primary.id)
      logger.info "  moved attachment #{name} to primary"
    end
  end

  # Repoint analytics/audit rows (ahoy events, versions) from the dupe to the kept
  # record so its history survives the merge. Type column stays; only the id moves.
  def reassign_polymorphic_references(primary, dupe)
    REASSIGNED_POLYMORPHIC_REFERENCES.each do |table, (type_column, id_column)|
      next unless reference_table_present?(table)

      klass = model_for_table(table)
      next unless klass.column_names.include?(id_column)

      moved = klass.where(type_column => model_class.polymorphic_name, id_column => dupe.id)
                   .update_all(id_column => primary.id)
      logger.info "  moved #{moved} #{table} to primary" if moved > 0
    end
  end

  def reference_table_present?(table)
    model_class.connection.data_source_exists?(table)
  end

  def merge_join(primary, dupe, join)
    jc = join[:join_class]
    fk = join[:foreign_key]
    natural_key = join[:natural_key]

    if natural_key.empty?
      moved = join_references(join, dupe.id).update_all(fk => primary.id)
      logger.info "  moved #{moved} #{jc.name} to primary" if moved > 0
      return
    end

    existing = join_references(join, primary.id).pluck(*natural_key).map { |values| Array(values) }.to_set

    join_references(join, dupe.id).find_each do |item|
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

    remaining = join_references(join, dupe.id).count
    raise "ABORT: #{remaining} #{jc.name} items still reference #{model_label} #{dupe.id}" if remaining > 0
  end
end
