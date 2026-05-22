class ScholarshipsController < ApplicationController
  before_action :set_event_registration
  before_action :set_scholarship, only: [ :edit, :update, :destroy, :allocate ]

  def new
    @scholarship = @event_registration.scholarships.build
    authorize! @scholarship
  end

  def create
    @scholarship = @event_registration.scholarships.build(scholarship_params)
    authorize! @scholarship

    if @scholarship.save
      redirect_to edit_event_registration_scholarship_path(@event_registration, @scholarship),
                  notice: "Scholarship created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! @scholarship
  end

  def update
    authorize! @scholarship

    if @scholarship.update(scholarship_params)
      redirect_to edit_event_registration_scholarship_path(@event_registration, @scholarship),
                  notice: "Scholarship updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @scholarship
    @scholarship.destroy!
    redirect_to manage_event_path(@event_registration.event), notice: "Scholarship removed."
  end

  def allocate
    authorize! @scholarship

    begin
      @scholarship.allocate!
      redirect_to edit_event_registration_scholarship_path(@event_registration, @scholarship),
                  notice: "Scholarship allocated."
    rescue => e
      redirect_to edit_event_registration_scholarship_path(@event_registration, @scholarship),
                  alert: e.message
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
