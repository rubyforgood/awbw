module AhoyTrackable
  extend ActiveSupport::Concern

  # Long-form bodies are stored as a readable preview, not in full: an event is a
  # summary, and whole articles would bloat every row of ahoy_events.
  RICH_TEXT_PREVIEW_LIMIT = 300

  included do
    after_create  -> { track_create_event }
    after_update  -> { track_update_event }
    after_destroy -> { track_lifecycle_event("destroy", @_destroy_snapshot || {}) }
    before_save :capture_pending_changes
    after_save :resolve_pending_association_ids
    before_destroy :capture_destroy_snapshot
  end

  # Category and sector memberships are reassigned through has_many :through
  # collection setters (categories=/sectors=) that persist immediately, outside
  # this record's dirty tracking — so the update callbacks never see them. The
  # code that reassigns them (TagAssignable) hands the before/after records here
  # to fold the diff onto the change log as the record's own update event.
  def track_membership_changes(memberships)
    association_changes = memberships.each_with_object({}) do |(assoc_name, delta), changes|
      entries = membership_change_entries(delta)
      changes[assoc_name] = entries if entries.present?
    end
    return if association_changes.blank?

    track_lifecycle_event("update", association_changes: association_changes)
  end

  private

  def membership_change_entries(delta)
    return [] if delta.blank?

    added = Array(delta[:added]).map { |record| membership_entry("added", record) }
    removed = Array(delta[:removed]).map { |record| membership_entry("removed", record) }
    added + removed
  end

  def membership_entry(action, record)
    { action: action, type: record.class.name, id: record.id }
  end

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

    changes = previous_changes.except("updated_at", "created_at").merge(@_pending_rich_text_changes.to_h)
    assoc_changes = collect_association_changes

    return if changes.empty? && assoc_changes.empty?
    return if devise_only_changes?(changes) && assoc_changes.empty?

    extra = {}
    extra[:changes] = format_tracked_changes(changes) if changes.present? && !devise_only_changes?(changes)
    extra[:association_changes] = assoc_changes if assoc_changes.present?

    track_lifecycle_event("update", extra)
  end

  # Autosave writes children, rich text, and attachments *after* this record's own
  # callbacks have run, clearing their dirty state on the way — so everything the
  # update event says about them has to be read here, while it's still pending.
  def capture_pending_changes
    capture_pending_association_changes
    capture_pending_rich_text_changes
    capture_pending_attachment_changes
  end

  def capture_pending_association_changes
    @_pending_association_changes = []

    self.class.nested_attributes_options.each_key do |assoc_name|
      # A symbol: the association cache is symbol-keyed, and a string lookup hands
      # back a fresh, unloaded association whose target is empty.
      Array(association(assoc_name).target).compact.each do |record|
        pending = pending_association_change(assoc_name, record)
        @_pending_association_changes << pending if pending
      end
    end
  end

  def pending_association_change(assoc_name, record)
    if record.marked_for_destruction? || record.new_record?
      action = record.marked_for_destruction? ? "removed" : "added"
      return { assoc: assoc_name, record: record, action: action, attributes: content_attributes(record) }
    end

    record_changes = record.changes.except("updated_at", "created_at")
    return if record_changes.empty?

    { assoc: assoc_name, record: record, action: "updated", changes: format_tracked_changes(record_changes) }
  end

  # What the record says, minus the plumbing: an added comment should read as its
  # body, not as a row of foreign keys. Keys, timestamps, and anything
  # secret-shaped are left out; the child's own event keeps the full snapshot.
  def content_attributes(record)
    record.attributes
      .except("id", "created_at", "updated_at")
      .reject { |key, value| value.blank? || key.end_with?("_id", "_type") }
      .reject { |key, _| key.match?(/password|token|secret|key|digest|salt|otp/i) }
  end

  # Ids are read now rather than at capture time: a record added through nested
  # attributes has none until the save goes through.
  def collect_association_changes
    @_unresolved_association_ids = []

    (@_pending_association_changes.to_a + @_pending_attachment_changes.to_a).each_with_object({}) do |pending, changes|
      entry = { action: pending[:action], type: pending[:type] || pending[:record].class.name }
      entry[:id] = pending[:record].id if pending[:record]
      entry[:filename] = pending[:filename] if pending[:filename]
      entry[:changes] = pending[:changes] if pending[:changes]
      entry[:attributes] = pending[:attributes] if pending[:attributes].present?
      @_unresolved_association_ids << [ entry, pending[:record] ] if pending[:record] && entry[:id].nil?

      (changes[pending[:assoc]] ||= []) << entry
    end
  end

  # A record added through nested attributes has no id until the collection
  # autosave runs, which is after the update event is assembled. The buffered
  # event holds the same hash, so filling it in here fills it in there.
  def resolve_pending_association_ids
    @_unresolved_association_ids.to_a.each { |entry, record| entry[:id] ||= record.id }
    @_unresolved_association_ids = nil
  end

  # Rich text saves through the parent's autosave chain, so by the time the update
  # event is built the body is no longer reliably readable as a change — capture it
  # here, while it's still dirty. Keyed on the attribute (`rhino_body`), not the
  # association, because a reader thinks of it as a field of the record; the plain
  # text is stored rather than the markup, truncated, so an event stays readable
  # and small.
  def capture_pending_rich_text_changes
    @_pending_rich_text_changes = {}

    self.class.reflect_on_all_associations(:has_one).each do |assoc|
      next if assoc.polymorphic?
      next unless safe_assoc_class_name(assoc) == "ActionText::RichText"

      # Reading the association would build an empty record for an untouched field.
      # The name has to stay a symbol: the association cache is symbol-keyed, and a
      # string lookup hands back a fresh, unloaded association whose target is nil.
      record = association(assoc.name).target
      # plain_text_body is derived when the rich text itself saves, which happens
      # after this, so the body is the only diff available on a first edit.
      diff = record&.changes&.values_at("plain_text_body", "body")&.compact&.first
      next if diff.blank?

      before, after = diff.map { |value| rich_text_preview(value) }
      next if before == after

      @_pending_rich_text_changes[assoc.name.to_s.delete_prefix("rich_text_")] = [ before, after ]
    end
  end

  def rich_text_preview(value)
    text = value.respond_to?(:to_plain_text) ? value.to_plain_text : value.to_s
    text.squish.truncate(RICH_TEXT_PREVIEW_LIMIT)
  end

  # ActiveStorage stages attach/purge on the record and applies it during save, so
  # the staged change is the only reliable description of what happened.
  def capture_pending_attachment_changes
    @_pending_attachment_changes = []
    return unless respond_to?(:attachment_changes, true)

    attachment_changes.each do |name, change|
      removal = change.is_a?(ActiveStorage::Attached::Changes::DeleteOne) ||
        change.is_a?(ActiveStorage::Attached::Changes::DeleteMany)

      @_pending_attachment_changes << {
        assoc: :"#{name}_attachment",
        type: "ActiveStorage::Attachment",
        action: removal ? "removed" : "added",
        filename: (attachment_filenames(change) unless removal)
      }.compact
    end
  end

  def attachment_filenames(change)
    blobs = change.try(:blobs) || Array(change.try(:blob))
    blobs.filter_map { |blob| blob.filename.to_s.presence }.join(", ").presence
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
      assoc = association(assoc_name)
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

      target = association(assoc.name).target
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

      begin
        ids = public_send(assoc.name).pluck(:id)
        next if ids.empty?

        records[assoc.name] = ids.map { |id| { record_type: assoc.klass.name, record_id: id } }
      rescue ActiveRecord::StatementInvalid
        next
      end
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
    return unless Current.user || Current.source
    return if self.class.name.start_with?("Ahoy::")
    return if self.class.name.in?(%w[ActiveStorage::Attachment ActiveStorage::Blob])
    # A Notification is already a durable, timestamped log, so a create/update event
    # per email sent would be redundant noise. A destroy is the exception — we do want
    # destroy.notification so a removed communication isn't silently lost.
    return if self.class.name == "Notification" && action != "destroy"

    # prevent nested tracking loops
    return if Thread.current[:_ahoy_tracking]
    Thread.current[:_ahoy_tracking] = true

    payload = Analytics::EventBuilder.lifecycle(action, self, user: Current.user)
    payload[:properties].merge!(extra_properties) if extra_properties.present?
    payload[:properties][:source] = Current.source if Current.source
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
      # A form posts every field, so untouched blanks arrive as nil -> "". Dirty
      # tracking counts that; a reader shouldn't have to.
      next if before.blank? && after.blank?

      h[attr] = { before: before, after: after }
    end
  end
end
