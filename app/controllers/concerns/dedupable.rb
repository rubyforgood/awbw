# frozen_string_literal: true

module Dedupable
  extend ActiveSupport::Concern

  def dedupe_index
    authorize!
    config = dedupe_config
    mc = config[:model_class]

    groups = mc.all.group_by { |r| r.name.to_s.strip.downcase }
    @possible_duplicates = groups.select { |_name, records| records.size > 1 }
    @records_for_select = mc.order(:name).map { |r| [ r.name, r.id ] }
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
      editable = mc.column_names - %w[id created_at updated_at legacy_id]
      record.update!(params.require(keep_param_key).permit(editable))
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

    record_to_delete = mc.find(params["#{mn}_to_delete_id"])
    record_to_keep = mc.find(params["#{mn}_to_keep_id"])

    keep_param_key = "#{mn}_to_keep"
    if params[keep_param_key].present?
      editable = mc.column_names - %w[id created_at updated_at legacy_id]
      record_to_keep.update!(params.require(keep_param_key).permit(editable))
    end

    if respond_to?(:track_event, true)
      track_event("dedupe.#{mn}", {
        resource_type: mc.name,
        resource_id: record_to_keep.id,
        deleted_record: record_to_delete.attributes,
        kept_record: { id: record_to_keep.id, name: record_to_keep.name },
        associations_moved: record_to_delete.public_send(dedupe_primary_join(mc).first).count
      })
    end

    deduper = ModelDeduper.new(model_class: mc, logger: Rails.logger, dry_run: false, min_usage: 0)
    deduper.merge(record_to_keep, record_to_delete)

    label = mc.model_name.human.pluralize
    redirect_to url_for(action: :index),
      notice: "#{label} merged successfully. '#{record_to_delete.name}' was merged into '#{record_to_keep.name}'."
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

  def build_dedupe_vars(config)
    mc = config[:model_class]
    mn = mc.model_name.singular
    join_assoc, join_incl = dedupe_primary_join(mc)
    opts = config[:belongs_to_options]

    {
      domain: config[:domain] || mc.model_name.plural.to_sym,
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
