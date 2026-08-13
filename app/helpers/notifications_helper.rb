module NotificationsHelper
  # Records that embed the communications box and can link into the index with a
  # "View all". A fixed name→class map (rather than constantizing the param) so a
  # hostile return_to_type can never be turned into an arbitrary class.
  RETURN_TO_MODELS = {
    "Person" => Person,
    "EventRegistration" => EventRegistration,
    "Scholarship" => Scholarship,
    "Story" => Story,
    "StoryIdea" => StoryIdea
  }.freeze

  # The record a communications-index visitor came from — set by a record's
  # "View all" link (return_to_type/return_to_id) so the index can show a back
  # eyebrow to that record. Nil unless a valid, recognized pair is present.
  def notification_return_record
    klass = RETURN_TO_MODELS[params[:return_to_type]]
    id = params[:return_to_id]
    return unless klass && id.present?

    klass.find_by(id: id)
  end

  # Back to where the "View all" was clicked — the record's edit page (which
  # holds the communications box), falling back to its canonical path.
  def notification_return_path(record)
    edit_polymorphic_path(record)
  rescue NoMethodError
    routable_path(record) || admin_path
  end
end
