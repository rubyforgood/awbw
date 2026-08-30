# frozen_string_literal: true

module Dedupable
  extend ActiveSupport::Concern

  CandidateGroup = Struct.new(:label, :records, :reasons, keyword_init: true)

  def dedupe_index
    authorize! :dedupe, to: :dedupe?
    config = dedupe_config
    mc = config[:model_class]

    @possible_duplicate_groups = dedupe_candidate_groups(config)
    @dedupe = build_dedupe_vars(config)

    render "dedupes/index"
  end

  def dedupe_preview
    authorize! :dedupe, to: :dedupe?
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
    deduper = ModelDeduper.new(model_class: mc, movable_attachments: config[:movable_attachments])
    @reassignment_delete = deduper.reassignment_preview(@record_to_delete)
    @reassignment_keep = deduper.reassignment_preview(@record_to_keep)
    @lost_references = deduper.lost_references(@record_to_delete)
    @attachment_plan = deduper.attachment_plan(@record_to_keep, @record_to_delete)
    @unhandled_references = deduper.unhandled_references(@record_to_delete)
    @merge_notes = Array(config[:merge_notes]&.call(@record_to_keep, @record_to_delete))
    @dedupe = build_dedupe_vars(config)

    render "dedupes/preview"
  end

  def dedupe_update_keep
    authorize! :dedupe, to: :dedupe?
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
    render json: { error: e.message }, status: :unprocessable_content
  end

  def dedupe_perform
    authorize! :dedupe, to: :dedupe?
    config = dedupe_config
    mc = config[:model_class]
    mn = mc.model_name.singular

    record_to_delete = mc.find(params["#{mn}_to_delete_id"])
    record_to_keep = mc.find(params["#{mn}_to_keep_id"])

    unhandled = ModelDeduper.new(model_class: mc).unhandled_references(record_to_delete)
    if unhandled.any?
      tables = unhandled.map { |ref| ref[:table] }.uniq.join(", ")
      return redirect_to url_for(action: :dedupe_index),
        alert: "Can't merge: #{tables} still reference this #{mc.model_name.human.downcase} and the deduper doesn't reassign them. A developer needs to teach ModelDeduper about them before merging."
    end

    keep_param_key = "#{mn}_to_keep"
    if params[keep_param_key].present?
      editable = mc.column_names - %w[id created_at updated_at legacy_id]
      record_to_keep.assign_attributes(params.require(keep_param_key).permit(editable))
    end

    # Combine values that must survive the merge rather than be replaced wholesale
    # (e.g. an org's FileMaker codes), so the kept record keeps both records' links.
    config[:merge_keeper]&.call(record_to_keep, record_to_delete)

    deduper = ModelDeduper.new(model_class: mc, logger: Rails.logger, dry_run: false, min_usage: 0,
                               movable_attachments: config[:movable_attachments])

    if respond_to?(:track_event, true)
      track_event("dedupe.#{mn}", {
        resource_type: mc.name,
        resource_id: record_to_keep.id,
        deleted_record: record_to_delete.attributes,
        kept_record: { id: record_to_keep.id, name: record_to_keep.name },
        associations_moved: deduper.reassignment_counts(record_to_delete).values.sum
      })
    end

    # Merge (which deletes the duplicate) before saving the keeper's edits, so a
    # uniqueness validation scoped to name+email (people) doesn't see the record
    # being deleted as a conflict. Atomic: a failed save rolls the merge back.
    ActiveRecord::Base.transaction do
      deduper.merge(record_to_keep, record_to_delete)
      record_to_keep.save! if record_to_keep.changed?
    end

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
  #   remote_select_options: Hash of { belongs_to column_name => search model } rendering an
  #                       ajax-search TomSelect picker on the keeper instead of a fixed dropdown —
  #                       for a target set too large to enumerate (e.g. author_id => "person") (optional)
  #   field_notes:        Hash of { column_name => hint } rendered under the keeper's field, to guide
  #                       an admin on what to enter (e.g. full_name is a legacy free-text author) (optional)
  #   deprecated_columns: Array of column names to render muted with a "Deprecated" badge (optional)
  #   movable_attachments: Array of has_one_attached names to move to the keeper when it has none
  #                       (otherwise dropped with the deleted record), e.g. %w[thumbnail header] (optional)
  #   merge_notes:        Lambda(keep, delete) returning an array of informational (non-blocking)
  #                       strings to surface on the preview (e.g. "both people have a login") (optional)
  #   record_extras:      Lambda(record) returning extra detail string for index listing (optional)
  def dedupe_config
    raise NotImplementedError, "#{self.class} must implement #dedupe_config"
  end

  # Candidate duplicate groups for the index. A config may supply a
  # :candidate_finder (a callable returning objects that respond to #label,
  # #records, and #reasons — e.g. OrganizationServices::DuplicateFinder); without
  # one, fall back to exact normalized-name grouping.
  def dedupe_candidate_groups(config)
    finder = config[:candidate_finder]
    return Array(finder.call) if finder

    config[:model_class].all
      .group_by { |record| record.name.to_s.strip.downcase }
      .select { |_name, records| records.size > 1 }
      .map { |name, records| CandidateGroup.new(label: name, records: records, reasons: []) }
  end

  def build_dedupe_vars(config)
    mc = config[:model_class]
    mn = mc.model_name.singular
    opts = config[:belongs_to_options]

    {
      domain: config[:domain] || mc.model_name.plural.to_sym,
      model_label: mc.model_name.human,
      model_label_plural: mc.model_name.human.pluralize,
      model_name: mn,
      delete_id_param: "#{mn}_to_delete_id",
      keep_id_param: "#{mn}_to_keep_id",
      keep_param_key: "#{mn}_to_keep".to_sym,
      search_model: mn,
      editable_columns: config[:editable_columns],
      union_columns: Array(config[:union_columns]).map(&:to_s),
      belongs_to_options: opts.is_a?(Proc) ? opts.call : (opts || {}),
      remote_select_options: config[:remote_select_options] || {},
      field_notes: config[:field_notes] || {},
      deprecated_columns: Array(config[:deprecated_columns]).map(&:to_s),
      record_extras: config[:record_extras]
    }
  end
end
