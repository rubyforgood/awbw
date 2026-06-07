class ScholarshipsController < ApplicationController
  before_action :set_scholarship, only: [ :show, :edit, :update, :destroy ]

  def show
    @scholarship = Scholarship.find(params[:id])
    authorize! @scholarship
  end

  def new
    @allocatable = locate_allocatable
    redirect_to allocations_path, alert: "Allocatable not found." unless @allocatable

    @scholarship = Scholarship.new(recipient: @allocatable.registrant)
    @scholarship.build_allocation(allocatable: @allocatable, amount: 0)
    authorize! @scholarship
  end

  def create
    @allocatable = locate_allocatable
    redirect_to allocations_path, alert: "Allocatable not found." and return unless @allocatable

    @scholarship = Scholarship.new(scholarship_params.merge(recipient: @allocatable.registrant))
    @scholarship.build_allocation(allocatable: @allocatable, amount: 0)
    authorize! @scholarship

    if @scholarship.save
      redirect_to edit_scholarship_path(@scholarship), notice: "Scholarship created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @allocatable = @scholarship.allocation&.allocatable
    authorize! @scholarship
    load_scholarship_submission
  end

  def update
    @allocatable = @scholarship.allocation&.allocatable
    authorize! @scholarship

    if @scholarship.update(scholarship_params)
      redirect_to edit_scholarship_path(@scholarship), notice: "Scholarship updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @allocatable = @scholarship.allocation&.allocatable
    authorize! @scholarship
    @scholarship.destroy!

    event = @allocatable.try(:event)
    redirect_to event ? manage_event_path(event) : scholarships_path,
                notice: "Scholarship removed."
  end

  private

  def set_scholarship
    @scholarship = Scholarship.find(params[:id])
  end

  # Pull the recipient's scholarship-section answers from the event's
  # registration form submission, plus a link to the full public submission.
  def load_scholarship_submission
    return unless @allocatable.respond_to?(:event)

    @event = @allocatable.event
    form = @event&.registration_form
    return unless form

    @form_submission = form.form_submissions.find_by(person: @scholarship.recipient)
    answers = @form_submission ? @form_submission.form_answers.index_by(&:form_field_id) : {}

    @scholarship_answers = form.form_fields
      .select { |field| field.section == "scholarship" || field.scholarship_only? }
      .reject { |field| field.group_header? || field.no_user_input? }
      .sort_by { |field| field.position.to_i }
      .map { |field| [ field, answers[field.id] ] }
  end

  def locate_allocatable
    sgid = params[:allocatable_sgid] || params.dig(:scholarship, :allocatable_sgid)
    GlobalID::Locator.locate_signed(sgid) if sgid
  end

  def scholarship_params
    params.require(:scholarship).permit(:amount_dollars, :amount_cents, :tasks_completed)
  end
end
