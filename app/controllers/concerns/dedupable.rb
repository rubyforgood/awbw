# frozen_string_literal: true

module Dedupable
  extend ActiveSupport::Concern

  def dedupe_index
    authorize!
    config = dedupe_config
    mc = config[:model_class]
    name_col = config[:name_column] || :name

    # Eager-load belongs_to associations used by record_extras
    eager = mc.reflect_on_all_associations(:belongs_to).map(&:name)
    all_records = mc.includes(eager).to_a

    groups = all_records.group_by { |r| r.public_send(name_col).to_s.strip.downcase }
    @possible_duplicates = groups.select { |_name, records| records.size > 1 }
    @records_for_select = all_records.sort_by { |r| r.public_send(name_col).to_s.downcase }.map { |r| [ r.public_send(name_col), r.id ] }

    # Pre-compute tagging counts in a single query
    join_assoc, _join_incl = dedupe_primary_join(mc)
    assoc_reflection = mc.reflect_on_association(join_assoc)
    fk = assoc_reflection.foreign_key
    @tagging_counts = assoc_reflection.klass.group(fk).count

    @dedupe = build_dedupe_vars(config)

    render "dedupes/index"
  end

  def dedupe_preview
    authorize!
    config = dedupe_config
    mc = config[:model_class]
    mn = mc.model_name.singular

    if params["#{mn}_to_delete_id"].blank? || params["#{mn}_to_keep_id"].blank?
      return redirect_to url_for(action: :dedupe_index)
    end
    if params["#{mn}_to_delete_id"] == params["#{mn}_to_keep_id"]
      return redirect_to url_for(action: :dedupe_index),
        alert: "You must select two different #{mc.model_name.human.pluralize.downcase} to dedupe."
    end

    @record_to_delete = mc.find_by(id: params["#{mn}_to_delete_id"])
    @record_to_keep = mc.find_by(id: params["#{mn}_to_keep_id"])
    unless @record_to_delete && @record_to_keep
      missing = [ @record_to_delete ? nil : params["#{mn}_to_delete_id"],
                  @record_to_keep ? nil : params["#{mn}_to_keep_id"] ].compact
      return redirect_to url_for(action: :dedupe_index),
        alert: "#{mc.model_name.human} not found (ID: #{missing.join(', ')})."
    end
    join_assoc, join_incl = dedupe_primary_join(mc)
    @delete_items = @record_to_delete.public_send(join_assoc).includes(join_incl)
    @keep_items = @record_to_keep.public_send(join_assoc).includes(join_incl)
    @dedupe = build_dedupe_vars(config)

    @extra_association_data = (config[:extra_associations] || []).map do |ea|
      {
        label: ea[:label],
        delete_items: @record_to_delete.public_send(ea[:name]),
        keep_items: @record_to_keep.public_send(ea[:name])
      }
    end

    render "dedupes/preview"
  end

  def dedupe_update_keep
    authorize!
    config = dedupe_config
    mc = config[:model_class]
    mn = mc.model_name.singular

    record = mc.find(params[:id])
    keep_param_key = "#{mn}_to_keep"

    if params[keep_param_key].present?
      editable = mc.column_names - %w[id created_at updated_at legacy_id] + rich_text_attribute_names(mc)
      non_blank = params.require(keep_param_key).permit(editable).to_h.reject { |_k, v| v.nil? || v == "" }
      record.update!(non_blank) if non_blank.any?
    end

    head :ok
  rescue ActionPolicy::Unauthorized
    raise
  rescue StandardError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def dedupe_execute
    authorize!
    config = dedupe_config
    mc = config[:model_class]
    mn = mc.model_name.singular
    name_col = config[:name_column] || :name

    record_to_delete = mc.find(params["#{mn}_to_delete_id"])
    record_to_keep = mc.find(params["#{mn}_to_keep_id"])

    delete_name = record_to_delete.public_send(name_col)
    keep_name = record_to_keep.public_send(name_col)

    ActiveRecord::Base.transaction do
      keep_param_key = "#{mn}_to_keep"
      if params[keep_param_key].present?
        editable = mc.column_names - %w[id created_at updated_at legacy_id] + rich_text_attribute_names(mc)
        non_blank = params.require(keep_param_key).permit(editable).to_h.reject { |_k, v| v.nil? || v == "" }
        record_to_keep.update!(non_blank) if non_blank.any?
      end

      if respond_to?(:track_event, true)
        track_event("dedupe.#{mn}", {
          resource_type: mc.name,
          resource_id: record_to_keep.id,
          deleted_record: record_to_delete.attributes,
          kept_record: { id: record_to_keep.id, name: keep_name },
          associations_moved: record_to_delete.public_send(dedupe_primary_join(mc).first).count
        })
      end

      if (extra_assocs = config[:extra_associations])
        extra_assocs.reject { |ea| ea[:display_only] }.each do |ea|
          reassign_direct_association(record_to_delete, record_to_keep, ea[:name])
        end
        # Clear stale association caches so dependent: :destroy
        # doesn't cascade-delete already-reassigned records.
        record_to_delete.reload
      end

      deduper = ModelDeduper.new(model_class: mc, logger: Rails.logger, dry_run: false, min_usage: 0)
      deduper.merge(record_to_keep, record_to_delete)
    end

    label = mc.model_name.human.pluralize
    redirect_to url_for(action: :index),
      notice: "#{label} merged successfully. '#{delete_name}' was merged into '#{keep_name}'."
  rescue ActionPolicy::Unauthorized
    raise
  rescue StandardError => e
    redirect_to url_for(action: :dedupe_index),
      alert: "Error merging: #{e.message}"
  end

  private

  # Subclasses must implement this, returning a hash with:
  #   model_class:        The ActiveRecord model (e.g. Category)
  #   domain:             Symbol for DomainTheme (e.g. :categories) (optional, derived from model)
  #   belongs_to_options: Hash or Proc of { column_name => collection } for select fields (optional)
  #   record_extras:      Lambda(record) returning extra detail string for index listing (optional)
  def dedupe_config
    raise NotImplementedError, "#{self.class} must implement #dedupe_config"
  end

  # Returns [association_name, includes_name] for the primary polymorphic join.
  # e.g. [:categorizable_items, :categorizable]
  def dedupe_primary_join(mc)
    assoc = mc.reflect_on_all_associations(:has_many).find do |a|
      next if a.options[:through]
      begin
        a.klass.reflect_on_all_associations(:belongs_to).any?(&:polymorphic?)
      rescue NameError
        false
      end
    end
    raise "No polymorphic join found for #{mc.name}" unless assoc

    poly = assoc.klass.reflect_on_all_associations(:belongs_to).find(&:polymorphic?)
    [ assoc.name, poly.name ]
  end

  # Reassign a direct FK has_many association from one record to another.
  # Detects duplicates using other FK columns and destroys them instead of moving.
  # Also catches DB-level uniqueness violations as a fallback.
  def reassign_direct_association(from_record, to_record, assoc_name)
    assoc = from_record.class.reflect_on_association(assoc_name)
    fk = assoc.foreign_key.to_s
    join_class = assoc.klass

    # Collect other belongs_to FK columns for duplicate detection,
    # filtering to only columns that actually exist in the table.
    db_columns = join_class.column_names.to_set
    other_fk_cols = join_class.reflect_on_all_associations(:belongs_to).flat_map do |bt|
      next [] if bt.foreign_key.to_s == fk
      cols =
        if bt.polymorphic?
          [ bt.foreign_type.to_s, bt.foreign_key.to_s ]
        else
          [ bt.foreign_key.to_s ]
        end
      cols.select { |c| db_columns.include?(c) }
    end

    items = from_record.public_send(assoc_name).to_a

    items.each do |item|
      if other_fk_cols.any?
        dedup_attrs = other_fk_cols.each_with_object({}) { |col, h| h[col] = item.public_send(col) }
        if to_record.public_send(assoc_name).where(dedup_attrs).exists?
          item.destroy!
          next
        end
      end

      begin
        item.update!(fk => to_record.id)
      rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
        # Model-level validation (e.g., name uniqueness) prevents the move;
        # destroy the unmovable record since the keeper has a conflict.
        item.destroy!
      end
    end
  end

  # Returns attribute names for has_rich_text fields (e.g. ["rhino_objective", "rhino_materials"]).
  # Empty array for models without ActionText.
  def rich_text_attribute_names(mc)
    mc.reflect_on_all_associations(:has_one)
      .select { |a| a.class_name == "ActionText::RichText" }
      .map { |a| a.name.to_s.sub(/^rich_text_/, "") }
  end

  def build_dedupe_vars(config)
    mc = config[:model_class]
    mn = mc.model_name.singular
    join_assoc, join_incl = dedupe_primary_join(mc)
    opts = config[:belongs_to_options]
    name_col = config[:name_column] || :name

    {
      domain: config[:domain] || mc.model_name.plural.to_sym,
      name_column: name_col,
      model_label: mc.model_name.human,
      model_label_plural: mc.model_name.human.pluralize,
      model_name: mn,
      delete_id_param: "#{mn}_to_delete_id",
      keep_id_param: "#{mn}_to_keep_id",
      keep_param_key: "#{mn}_to_keep".to_sym,
      item_type_col: "#{join_incl}_type".to_sym,
      item_id_col: "#{join_incl}_id".to_sym,
      join_association: join_assoc,
      belongs_to_options: opts.is_a?(Proc) ? opts.call : (opts || {}),
      record_extras: config[:record_extras]
    }
  end
end
