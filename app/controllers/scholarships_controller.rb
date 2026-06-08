class ScholarshipsController < ApplicationController
  before_action :set_scholarship, only: [ :show, :edit, :update, :destroy ]
  before_action :set_grant, only: [ :new, :create ]

  def show
    @scholarship = Scholarship.find(params[:id])
    authorize! @scholarship
  end

  def new
    if @grant
      @scholarship = Scholarship.new(grant: @grant)
      authorize! @scholarship
      return
    end

    @allocatable = locate_allocatable
    redirect_to allocations_path, alert: "Allocatable not found." and return unless @allocatable

    @scholarship = Scholarship.new(recipient: @allocatable.registrant)
    @scholarship.build_allocation(allocatable: @allocatable, amount: 0)
    @grants = Grant.by_deadline
    authorize! @scholarship
  end

  def create
    if @grant
      @scholarship = Scholarship.new(scholarship_params.merge(grant: @grant))
      authorize! @scholarship

      if @scholarship.save
        redirect_to grant_return_path, notice: "Scholarship created."
      else
        render :new, status: :unprocessable_content
      end
      return
    end

    @allocatable = locate_allocatable
    redirect_to allocations_path, alert: "Allocatable not found." and return unless @allocatable

    @scholarship = Scholarship.new(scholarship_params.merge(recipient: @allocatable.registrant))
    @scholarship.build_allocation(allocatable: @allocatable, amount: 0)
    authorize! @scholarship

    if @scholarship.save
      redirect_to edit_scholarship_path(@scholarship), notice: "Scholarship created."
    else
      @grants = Grant.by_deadline
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @allocatable = @scholarship.allocation&.allocatable
    @grants = Grant.by_deadline
    authorize! @scholarship
    load_scholarship_submission
  end

  def update
    @allocatable = @scholarship.allocation&.allocatable
    authorize! @scholarship

    if @scholarship.update(scholarship_params)
      redirect_to scholarship_save_path, notice: "Scholarship updated."
    else
      @grants = Grant.by_deadline
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @allocatable = @scholarship.allocation&.allocatable
    authorize! @scholarship
    grant = @scholarship.grant
    @scholarship.destroy!

    event = @allocatable.try(:event)
    destination = if event
      registrants_event_path(event)
    elsif grant
      params[:return_to] == "grant_edit" ? edit_grant_path(grant) : grant_path(grant)
    else
      root_path
    end
    redirect_to destination, notice: "Scholarship removed."
  end

  private

  def set_scholarship
    @scholarship = Scholarship.find(params[:id])
  end

  def set_grant
    @grant = Grant.find(params[:grant_id]) if params[:grant_id].present?
  end

  # After saving a grant-funded scholarship, return to the grant the user came
  # from (its show or edit page, respectively).
  def grant_return_path
    params[:return_to] == "grant_edit" ? edit_grant_path(@scholarship.grant) : grant_path(@scholarship.grant)
  end

  def scholarship_save_path
    return grant_return_path if @scholarship.grant && params[:return_to].in?(%w[ grant_show grant_edit ])

    edit_scholarship_path(@scholarship)
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
    params.require(:scholarship).permit(:amount_dollars, :amount_cents, :tasks_completed, :grant_id, :recipient_id)
  end
end
