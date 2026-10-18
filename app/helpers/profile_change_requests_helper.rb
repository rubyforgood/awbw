module ProfileChangeRequestsHelper
  # [path, label] for the change-request queue's eyebrow. A "From change request"
  # link in a change log (Ahoy::EventDecorator#return_to_params) names the log it
  # came from, so the eyebrow returns there rather than to a generic default:
  # "record" is a record's inline log (back to that record), "activities" is the
  # admin activities index (back to it, filtered to the same record).
  def change_requests_return_link(person)
    return activities_return_link if params[:return_to] == "activities"

    record_link = record_return_link if params[:return_to] == "record"
    return record_link if record_link
    return [ edit_person_path(person), person.full_name ] if person

    [ root_path, "Home" ]
  end

  private

  def activities_return_link
    [ admin_activities_events_path(resource_type: params[:return_type].presence,
                                   resource_id: params[:return_id].presence), "Activity log" ]
  end

  # nil when the pair names nothing we can look up or label, so the caller falls
  # back to the person/home default.
  def record_return_link
    record = returning_record
    path = record && record_return_path(record)
    label = Analytics::EventBuilder.safe_title(record).to_s.presence if path

    [ path, label ] if label
  end

  def returning_record
    klass = params[:return_type].to_s.safe_constantize
    return nil unless klass.respond_to?(:find_by) && klass < ApplicationRecord

    klass.find_by(id: params[:return_id])
  end

  # The page the record's own change log is on: its edit screen, falling back to
  # its show page for a record with no edit route.
  def record_return_path(record)
    edit_polymorphic_path(record)
  rescue StandardError
    record_show_path(record)
  end

  def record_show_path(record)
    polymorphic_path(record)
  rescue StandardError
    nil
  end
end
