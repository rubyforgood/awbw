class ScholarshipsController < ApplicationController
  before_action :set_event_registration
  before_action :set_scholarship, only: [ :update, :destroy, :allocate ]

  def create
    @scholarship = @event_registration.scholarships.build(scholarship_params)
    authorize! @scholarship

    if @scholarship.save
      redirect_to edit_event_registration_path(@event_registration), notice: "Scholarship created."
    else
      redirect_to edit_event_registration_path(@event_registration),
                  alert: @scholarship.errors.full_messages.join(", ")
    end
  end

  def update
    authorize! @scholarship

    if @scholarship.update(scholarship_params)
      redirect_to edit_event_registration_path(@event_registration), notice: "Scholarship updated."
    else
      redirect_to edit_event_registration_path(@event_registration),
                  alert: @scholarship.errors.full_messages.join(", ")
    end
  end

  def destroy
    authorize! @scholarship
    @scholarship.destroy!
    redirect_to edit_event_registration_path(@event_registration), notice: "Scholarship removed."
  end

  def allocate
    authorize! @scholarship

    begin
      @scholarship.allocate!
      redirect_to edit_event_registration_path(@event_registration), notice: "Scholarship allocated."
    rescue => e
      redirect_to edit_event_registration_path(@event_registration), alert: e.message
    end
  end

  private

  def set_event_registration
    @event_registration = EventRegistration.find(params[:event_registration_id])
  end

  def set_scholarship
    @scholarship = @event_registration.scholarships.find(params[:id])
  end

  def scholarship_params
    params.require(:scholarship).permit(:amount_dollars, :amount_cents, :tasks_completed)
  end
end
