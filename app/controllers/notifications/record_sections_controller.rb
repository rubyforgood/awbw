module Notifications
  class RecordSectionsController < ApplicationController
    include AhoyTracking

    before_action :set_noticeable, only: [ :new, :create ]
    before_action :set_notification, only: [ :show, :edit, :update ]

    def new
      authorize! Notification
      @notification = Notification.new
    end

    def create
      authorize! Notification

      @notification = Notification.new(notification_params)
      @notification.sender = current_user
      @notification.noticeable = @noticeable
      @notification.person = @noticeable.is_a?(Person) ? @noticeable : @noticeable.try(:person)
      @notification.recipient_email = @noticeable.communications_email.presence || "n/a"

      unless @notification.save
        render :create, status: :unprocessable_content
      end
    end

    def show
      authorize! @notification
    end

    def edit
      authorize! @notification

      unless @notification.manual_log?
        redirect_to notification_path(@notification), alert: "Only manually logged communications can be edited."
      end
    end

    def update
      authorize! @notification
      responded_was = @notification.responded?
      body_was = @notification.email_body_text

      if @notification.update(notification_params)
        flash.now[:notice] = "Saved"
        track_responded_change(responded_was)
        track_incoming_body_change(body_was)
      else
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_noticeable
      @noticeable = GlobalID::Locator.locate_signed(params[:noticeable_sgid])
      raise ActiveRecord::RecordNotFound unless @noticeable
    end

    def set_notification
      @notification = Notification.find(params[:id])
    end

    def notification_params
      params.expect(notification: [ :responded, :flagged, :channel, :email_subject, :email_body_text, :direction, :created_at ])
    end

    def track_responded_change(previous)
      return if @notification.responded? == previous

      track_event("update.notification.responded", {
        resource_type: "Notification",
        resource_id: @notification.id,
        responded: @notification.responded?
      })
    end

    def track_incoming_body_change(previous)
      return unless @notification.incoming?
      return if @notification.email_body_text == previous

      track_event("update.notification.body", {
        resource_type: "Notification",
        resource_id: @notification.id
      })
    end
  end
end
