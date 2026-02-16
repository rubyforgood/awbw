module AhoyTrackable
  extend ActiveSupport::Concern

  included do
    after_create  -> { track_create_event }
    after_update  -> { track_update_event }
    after_destroy -> { track_lifecycle_event("destroy", @_destroy_snapshot || {}) }
    before_save :capture_pending_association_removals
    before_destroy :capture_destroy_snapshot
  end

  private

  def devise_only_changes?(changes)
    auth_fields = %w[
      current_sign_in_at
      last_sign_in_at
      current_sign_in_ip
      last_sign_in_ip
      sign_in_count
      remember_created_at
    ]

    (changes.keys - auth_fields).empty?
  end

  def track_create_event
    extra = {}

    attrs = attributes.except("updated_at", "created_at")
    safe_attrs = attrs.select { |k, v| v.present? && !k.match?(/password|token|secret|key|digest|salt|otp/i) }
    extra[:attributes] = safe_attrs if safe_attrs.present?

    assoc_records = snapshot_nested_associated_records
    extra[:associated_records] = assoc_records if assoc_records.present?

    track_lifecycle_event("create", extra)
  end

  def track_update_event
    return if previously_new_record? # Skip the fake "update" that happens right after create

    changes = previous_changes.except("updated_at", "created_at")
    assoc_changes = collect_association_changes

    return if changes.empty? && assoc_changes.empty?
    return if devise_only_changes?(changes) && assoc_changes.empty?

    extra = {}
    extra[:changes] = format_tracked_changes(changes) if changes.present? && !devise_only_changes?(changes)
    extra[:association_changes] = assoc_changes if assoc_changes.present?

    track_lifecycle_event("update", extra)
  end

  # Capture records marked for destruction before autosave removes them from the target
  def capture_pending_association_removals
    @_pending_association_removals = {}

    self.class.nested_attributes_options.each_key do |assoc_name|
      assoc = association(assoc_name.to_s)
      next unless assoc.loaded?

      marked = Array(assoc.target).compact.select(&:marked_for_destruction?)
      next if marked.empty?

      @_pending_association_removals[assoc_name] = marked.map do |record|
        { action: "removed", id: record.id, type: record.class.name }
      end
    end
  end

  def collect_association_changes
    changes = {}

    self.class.nested_attributes_options.each_key do |assoc_name|
      assoc = association(assoc_name.to_s)
      next unless assoc.loaded?

      Array(assoc.target).compact.each do |record|
        if record.previously_new_record?
          changes[assoc_name] ||= []
          changes[assoc_name] << { action: "added", id: record.id, type: record.class.name }
        else
          record_changes = record.previous_changes.except("updated_at", "created_at")
          next if record_changes.empty?

          changes[assoc_name] ||= []
          changes[assoc_name] << { action: "updated", id: record.id, type: record.class.name,
                                   changes: format_tracked_changes(record_changes) }
        end
      end
    end

    # Merge in removals captured before save
    if @_pending_association_removals.present?
      @_pending_association_removals.each do |assoc_name, removals|
        changes[assoc_name] ||= []
        changes[assoc_name].concat(removals)
      end
    end

    # Track rich text changes
    collect_rich_text_changes(changes)

    # Track attachment changes
    collect_attachment_changes(changes)

    changes
  end

  def collect_rich_text_changes(changes)
    self.class.reflect_on_all_associations(:has_one).each do |assoc|
      next if assoc.polymorphic?
      next unless safe_assoc_class_name(assoc) == "ActionText::RichText"

      record = public_send(assoc.name)
      next unless record&.persisted?

      rt_changes = record.previous_changes.slice("body", "plain_text_body")
      next if rt_changes.empty?

      changes[assoc.name] ||= []
      changes[assoc.name] << { action: "updated", id: record.id, type: "ActionText::RichText",
                                changes: format_tracked_changes(rt_changes) }
    end
  end

  def collect_attachment_changes(changes)
    self.class.reflect_on_all_associations.each do |assoc|
      next if assoc.polymorphic?
      next unless safe_assoc_class_name(assoc) == "ActiveStorage::Attachment"

      if assoc.macro == :has_many
        Array(association(assoc.name.to_s).target).compact.each do |record|
          next unless record.previously_new_record?

          changes[assoc.name] ||= []
          changes[assoc.name] << { action: "added", type: "ActiveStorage::Attachment", record_id: record.id, blob_id: record.blob_id }
        end
      elsif assoc.macro == :has_one
        record = public_send(assoc.name)
        next unless record&.previously_new_record?

        changes[assoc.name] ||= []
        changes[assoc.name] << { action: "added", type: "ActiveStorage::Attachment", record_id: record.id, blob_id: record.blob_id }
      end
    end

    if @_pending_association_removals.blank?
      # Check for attachment removals via attachment_changes (Rails built-in tracking)
      return unless respond_to?(:attachment_changes, true) && attachment_changes.present?

      attachment_changes.each do |name, change|
        assoc_name = "#{name}_attachment".to_sym
        if change.is_a?(ActiveStorage::Attached::Changes::DeleteOne) || change.is_a?(ActiveStorage::Attached::Changes::DeleteMany)
          changes[assoc_name] ||= []
          changes[assoc_name] << { action: "removed", type: "ActiveStorage::Attachment" }
        end
      end
    end
  end

  def capture_destroy_snapshot
    attrs = attributes.except("updated_at", "created_at")
    safe_attrs = attrs.select { |k, v| v.present? && !k.match?(/password|token|secret|key|digest|salt|otp/i) }

    @_destroy_snapshot = {
      attributes: safe_attrs,
      associated_records: snapshot_associated_records
    }
  end

  def snapshot_nested_associated_records
    records = {}

    self.class.nested_attributes_options.each_key do |assoc_name|
      assoc = association(assoc_name.to_s)
      next unless assoc.loaded?

      created = Array(assoc.target).compact.select(&:persisted?)
      next if created.empty?

      records[assoc_name] = created.map { |r| { record_type: r.class.name, record_id: r.id } }
    end

    # Capture rich text content set on create
    self.class.reflect_on_all_associations(:has_one).each do |assoc|
      next if assoc.polymorphic?
      next unless safe_assoc_class_name(assoc) == "ActionText::RichText"

      record = public_send(assoc.name)
      next unless record&.persisted?

      content = record.plain_text_body.presence || record.to_plain_text
      next if content.blank?

      records[assoc.name] = { record_type: "ActionText::RichText", record_id: record.id, content: content }
    end

    # Capture attachments added on create
    self.class.reflect_on_all_associations.each do |assoc|
      next if assoc.polymorphic?
      next unless safe_assoc_class_name(assoc) == "ActiveStorage::Attachment"

      target = association(assoc.name.to_s).target
      attached = Array(target).compact.select(&:persisted?)
      next if attached.empty?

      records[assoc.name] = attached.map { |a| { action: "added", record_type: "ActiveStorage::Attachment", record_id: a.id, blob_id: a.blob_id } }
    end

    records
  end

  def snapshot_associated_records
    records = {}

    self.class.reflect_on_all_associations(:has_many).each do |assoc|
      next if assoc.is_a?(ActiveRecord::Reflection::ThroughReflection)
      next if assoc.polymorphic?
      class_name = safe_assoc_class_name(assoc)
      next unless class_name
      next if class_name == "ActiveStorage::Blob"

      if class_name == "ActiveStorage::Attachment"
        attachments = public_send(assoc.name)
        next unless attachments.any?

        records[assoc.name] = attachments.map { |a| { record_type: "ActiveStorage::Attachment", record_id: a.id, blob_id: a.blob_id } }
        next
      end

      ids = public_send(assoc.name).pluck(:id)
      next if ids.empty?

      records[assoc.name] = ids.map { |id| { record_type: assoc.klass.name, record_id: id } }
    end

    self.class.reflect_on_all_associations(:has_one).each do |assoc|
      next if assoc.polymorphic?
      class_name = safe_assoc_class_name(assoc)
      next unless class_name
      next if class_name == "ActiveStorage::Blob"

      record = public_send(assoc.name)
      next unless record

      if class_name == "ActionText::RichText"
        records[assoc.name] = { record_type: "ActionText::RichText", record_id: record.id, content: record.plain_text_body.presence || record.to_plain_text }
      elsif class_name == "ActiveStorage::Attachment"
        records[assoc.name] = { record_type: "ActiveStorage::Attachment", record_id: record.id, blob_id: record.blob_id }
      else
        records[assoc.name] = { record_type: assoc.klass.name, record_id: record.id }
      end
    end

    records
  end

  def track_lifecycle_event(action, extra_properties = {})
    return unless Current.user
    return if self.class.name.start_with?("Ahoy::")
    return if self.class.name.in?(%w[Notification ActiveStorage::Attachment ActiveStorage::Blob])

    # prevent nested tracking loops
    return if Thread.current[:_ahoy_tracking]
    Thread.current[:_ahoy_tracking] = true

    payload = Analytics::EventBuilder.lifecycle(action, self, user: Current.user)
    payload[:properties].merge!(extra_properties) if extra_properties.present?
    Analytics::LifecycleBuffer.push(payload)
  rescue => e
    Rails.logger.error "Ahoy lifecycle tracking failed: #{e.message}"
  ensure
    Thread.current[:_ahoy_tracking] = false
  end

  def safe_assoc_class_name(assoc)
    assoc.klass.name
  rescue ArgumentError
    nil
  end

  def format_tracked_changes(changes)
    safe_changes = changes.reject { |attr, _| attr.match?(/password|token|secret|key|digest|salt|otp/i) }
    safe_changes.each_with_object({}) do |(attr, (before, after)), h|
      h[attr] = { before: before, after: after }
    end
  end
end
