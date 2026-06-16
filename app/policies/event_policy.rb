class EventPolicy < ApplicationPolicy
  # See https://actionpolicy.evilmartians.io/#/writing_policies
  #
  # override or add new rules here that are not defined in ApplicationPolicy

  def index?
    true
  end

  # Powers the admin "favorite event" autocomplete on user accounts. Admin-only
  # so the endpoint never exposes unpublished/private events to other users.
  def search?
    admin?
  end

  def show?
    return true if admin?

    if record.ended?
      authenticated? && record.published? && record.actively_registered?(user.person)
    else
      record.publicly_visible? || (authenticated? && record.published?)
    end
  end

  # Who can see the public "Meet the staff" roster. Mirrors event visibility for
  # now, but kept as its own rule (rather than delegating to show?) so we can
  # tighten it later — e.g. registrants only — without affecting event show access.
  def staff?
    return true if admin?

    if record.ended?
      authenticated? && record.published? && record.actively_registered?(user.person)
    else
      record.publicly_visible? || (authenticated? && record.published?)
    end
  end

  def register?
    authenticated? && record.published?
  end

  def edit?
    admin? || owner?
  end

  def update?
    admin? || owner?
  end

  def manage?
    admin? || owner?
  end

  # Who can view/manage an event's registrants. Mirrors manage? for now, but kept
  # as its own rule so registrant access can be tightened later without affecting
  # other manage? actions.
  def registrants?
    manage?
  end

  def dashboard?
    admin? || owner?
  end

  def background?
    admin? || owner?
  end

  def edit_staff?
    manage?
  end

  def update_staff?
    manage?
  end

  def recipients?
    manage?
  end

  def bulk_payments?
    manage?
  end

  def preview_reminder?
    manage?
  end

  def send_reminder?
    manage?
  end

  # Use caution - This allows pasting scripts
  def google_analytics?
    admin?
  end

  params_filter do |params|
    permitted = [ :cost,
                  :created_by_id,
                  :location_id,
                  :title,
                  :pre_title,
                  :videoconference_url,
                  :videoconference_label,
                  :rhino_header,
                  :rhino_description,
                  :event_details,
                  :event_details_label,
                  :autoshow_cost,
                  :autoshow_date,
                  :autoshow_location,
                  :autoshow_registration,
                  :autoshow_time,
                  :autoshow_title,
                  :autoshow_videoconference_link,
                  :autoshow_videoconference_label,
                  :autoshow_pre_date_text,
                  :autoshow_registration_close,
                  :public_registration_enabled,
                  :signed_in_one_click_enabled,
                  :autoshow_registration_details,
                  :hint_dates,
                  :hint_times,
                  :hint_registration_cost,
                  :pre_title,
                  :pre_date_text,
                  :featured,
                  :start_date, :end_date,
                  :registration_close_date,
                  :published,
                  :publicly_visible,
                  :publicly_featured,
                  category_ids: [],
                  sector_ids: [],
                  primary_asset_attributes: [ :id, :file, :_destroy ],
                  gallery_assets_attributes: [ :id, :file, :_destroy ]
        ]

    permitted.prepend(:ga4_snippet, :gtm_head_snippet, :gtm_body_snippet) if admin?

    params.permit(*permitted)
  end

  alias_rule :preview?, to: :edit?
  alias_rule :details?, to: :show?

  private

  def owner?
    return false unless authenticated?
    return false unless record.is_a?(Event)
    record.created_by == user
  end

  relation_scope do |relation|
    next relation if admin?

    if authenticated?
      relation
        .joins(
          "LEFT OUTER JOIN event_registrations
             ON event_registrations.event_id = events.id
             AND event_registrations.status IN ('registered', 'attended', 'incomplete_attendance')
           LEFT OUTER JOIN people
             ON people.id = event_registrations.registrant_id"
        )
        .published
        .where(
          "(events.end_date >= :now AND (events.registration_close_date IS NULL OR events.registration_close_date >= :now))
           OR people.id = :person_id",
          now: Time.current,
          person_id: user.person_id
        )
        .distinct
    else
      relation.publicly_visible
              .published
              .where("events.end_date >= ?", Time.current)
              .where("events.registration_close_date IS NULL OR events.registration_close_date >= ?", Time.current)
    end
  end
end
