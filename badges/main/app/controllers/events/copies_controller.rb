module Events
  # Copies an event — settings, callouts, forms, staff, tags, images — onto a new
  # unpublished event at a chosen start date (see EventCopyService).
  class CopiesController < ApplicationController
    before_action :set_event

    def new
      authorize! @event, to: :copy?
      @title = "#{EventCopyService::COPY_TITLE_PREFIX}#{@event.title}"
      @start_on = @event.starts_on
    end

    def create
      authorize! @event, to: :copy?
      @title = params[:title]
      @start_on = params[:start_on].presence&.to_date
      return render_new("Choose a start date for the copy.") unless @start_on

      service = EventCopyService.for_event(@event)
      copy = service.call(start_on: @start_on, title: @title)
      flash[:warning] = service.warnings.to_sentence if service.warnings.any?
      redirect_to edit_event_path(copy), status: :see_other,
        notice: "Event copied. Now editing the unpublished copy — review it before publishing."
    rescue Date::Error
      render_new("Start date isn't a valid date.")
    rescue ActiveRecord::RecordInvalid => e
      render_new(e.record.errors.full_messages.to_sentence)
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def render_new(alert)
      flash.now[:alert] = alert
      render :new, status: :unprocessable_content
    end
  end
end
