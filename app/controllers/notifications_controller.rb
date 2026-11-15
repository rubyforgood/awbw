class NotificationsController < ApplicationController
  include AhoyTracking

  before_action :set_notification, only: [ :show, :edit, :update, :resend ]

  def index
    authorize!

    if turbo_frame_request?
      per_page = params[:number_of_items_per_page].presence || 25
      base_scope = authorized_scope(Notification.includes(:noticeable, sender: :person))
      filtered = base_scope.search_by_params(params.to_unsafe_h)
      @notifications = filtered.order(created_at: :desc)
                               .paginate(page: params[:page], per_page: per_page)

      render :notifications_results
    else
      track_view("notifications", { page: "index" })
      render :index
    end
  end

  def new
    authorize!
    @notification = Notification.new
    @noticeable = inline_noticeable
  end

  # Log a communication by hand against a person — mirrors the nested
  # notifications flow (people_controller#update): the picked person supplies the
  # recipient_email; the model fills in the manual_log defaults (kind,
  # recipient_role, notification_type, delivered_at). The person is also the
  # default noticeable, but the combined feed's composer can file it against one
  # of the person's other records instead (a signed GlobalID, so the type/id
  # can't be tampered with).
  def create
    authorize!

    if params[:inline].present?
      create_inline
    else
      create_for_person
    end
  end

  def show
    authorize! @notification
    track_view @notification
  end

  def edit
    authorize! @notification
    unless @notification.manual_log?
      redirect_to @notification, alert: "Only manually logged communications can be edited."
    end
  end

  def update
    authorize! @notification
    responded_was = @notification.responded?
    body_was = @notification.email_body_text

    if @notification.update(notification_params)
      flash.now[:notice] = "Saved" if params[:toggle].present?
      track_responded_change(responded_was)
      track_incoming_body_change(body_was)
      combined_feed_person

      if params[:inline].present?
        redirect_to helpers.inline_record_path(@notification.noticeable, fallback: notifications_path),
                    status: :see_other
      else
        respond_to do |format|
          format.turbo_stream
          format.any { head :ok }
        end
      end
    elsif params[:inline].present?
      render :edit, status: :unprocessable_content
    else
      respond_to do |format|
        format.turbo_stream { head :unprocessable_content }
        format.any { head :unprocessable_content }
      end
    end
  end

  def resend
    authorize! @notification, to: :resend?

    # Determine parent and root for the resend chain
    parent_id = @notification.id
    root_id = @notification.root_notification_id || @notification.id

    # Create and send a new notification using the service. Everything that shaped
    # the original body travels with it so the resend is the same email, not a
    # default-shaped one; only the provenance (sender, and `bulk` — a resend is an
    # individual action, not part of the original batch) reflects the resend itself.
    new_notification = NotificationServices::CreateNotification.call(
      noticeable: @notification.noticeable,
      person: @notification.person,
      kind: @notification.kind,
      recipient_email: @notification.recipient_email,
      recipient_role: @notification.recipient_role,
      notification_type: @notification.notification_type,
      custom_message: @notification.custom_message,
      custom_subject: @notification.custom_subject,
      hide_event_card: @notification.hide_event_card,
      hide_ticket_button: @notification.hide_ticket_button,
      sender: current_user, # a resend is an admin action — attribute it to them
      deliver: true,
      persist_delivered_email: true
    )

    # Set parent and root notification IDs to track the resend chain
    new_notification.update!(
      parent_notification_id: parent_id,
      root_notification_id: root_id
    )

    redirect_to @notification, notice: t("communications.resent")
  end

  private

  def create_inline
    record = inline_noticeable
    return create_inline_for(record) if record

    @notification = Notification.new(notification_params)
    @notification.errors.add(:base, "Select a record to log this communication against")
    render :new, status: :unprocessable_content
  end

  def create_for_person
    @person = Person.find_by(id: params[:person_id])
    @notification = Notification.new(notification_params)
    @notification.sender = current_user

    if @person
      @notification.noticeable = noticeable_target || @person
      @notification.person = @person
      @notification.recipient_email = @person.communications_email.presence || "n/a"
    else
      @notification.errors.add(:base, "Select a person to log this communication against")
    end

    if @person && @notification.save
      redirect_to after_create_path, notice: "Communication logged."
    elsif combined_feed_person
      redirect_to after_create_path, alert: @notification.errors.full_messages.to_sentence.presence || "Failed to log the communication."
    else
      render :new, status: :unprocessable_content
    end
  end

  def create_inline_for(record)
    @noticeable = record
    @notification = Notification.new(notification_params)
    @notification.sender = current_user
    @notification.noticeable = record
    @notification.person = record.is_a?(Person) ? record : record.try(:person)
    @notification.recipient_email = record.communications_email.presence || "n/a"

    if @notification.save
      if turbo_frame_request?
        render :create, formats: :turbo_stream
      else
        redirect_to helpers.inline_record_path(record, fallback: notifications_path),
                    notice: "Communication logged."
      end
    else
      render :new, status: :unprocessable_content
    end
  end

  def inline_noticeable
    return if params[:noticeable_sgid].blank?

    record = noticeable_target
    record if record.respond_to?(:communications_email)
  end

  # The record the communication is filed against when the composer offers a
  # picker. Signed, so a hostile value can't point at an arbitrary record.
  def noticeable_target
    return if params[:noticeable_sgid].blank?

    GlobalID::Locator.locate_signed(params[:noticeable_sgid])
  end

  # Set when a person's combined feed posted this — the composer lands the log
  # back there instead of the global index, and an inline row edit re-renders
  # with that person so its date link stays scoped to their feed.
  def combined_feed_person
    @combined_feed_person ||= Person.find_by(id: params[:for_person_id]) if params[:for_person_id].present?
  end

  def after_create_path
    combined_feed_person ? comments_and_communications_path(person_id: combined_feed_person.id) : notifications_path
  end

  def track_responded_change(previous)
    return if @notification.responded? == previous

    track_event("update.notification.responded", {
      resource_type: "Notification",
      resource_id: @notification.id,
      responded: @notification.responded?
    })
  end

  # An incoming communication is logged by hand, so an edit to its body is a real
  # content change worth surfacing — unlike outgoing/system messages, whose body
  # is generated, not authored.
  def track_incoming_body_change(previous)
    return unless @notification.incoming?
    return if @notification.email_body_text == previous

    track_event("update.notification.body", {
      resource_type: "Notification",
      resource_id: @notification.id
    })
  end

  def set_notification
    @notification = Notification.find(params[:id])
  end

  def notification_params
    params.require(:notification).permit(:responded, :flagged, :channel, :email_subject, :email_body_text, :direction, :created_at)
  end
end
