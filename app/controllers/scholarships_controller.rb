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
    @grants = Grant.selectable_for(@scholarship)
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
      redirect_to scholarship_save_path, notice: "Scholarship created."
    else
      @grants = Grant.selectable_for(@scholarship)
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @allocatable = @scholarship.allocation&.allocatable
    @grants = Grant.selectable_for(@scholarship)
    authorize! @scholarship
    load_scholarship_submission
  end

  def update
    @allocatable = @scholarship.allocation&.allocatable
    authorize! @scholarship

    @scholarship.assign_attributes(scholarship_params)
    attribute_comment_authorship

    # Inline-logged notifications are addressed to the scholarship recipient.
    recipient_email = @scholarship.recipient&.preferred_email.presence || "n/a"
    @scholarship.notifications.select(&:new_record?).each { |n| n.recipient_email = recipient_email }

    if @scholarship.save
      redirect_to scholarship_save_path, notice: "Scholarship updated."
    else
      @grants = Grant.selectable_for(@scholarship)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @allocatable = @scholarship.allocation&.allocatable
    authorize! @scholarship
    grant = @scholarship.grant
    @scholarship.destroy!

    redirect_to scholarship_return_path(grant), notice: "Scholarship removed."
  end

  private

  def set_scholarship
    @scholarship = Scholarship.find(params[:id])
  end

  def set_grant
    @grant = Grant.find(params[:grant_id]) if params[:grant_id].present?
  end

  # A scholarship can be both event-funded and grant-funded. The return_to param
  # records which page the user came from so navigation follows that context
  # rather than always preferring the event.
  def grant_context?(grant = @scholarship&.grant)
    grant.present? && params[:return_to].in?(%w[ grant_show grant_edit ])
  end

  # Return to the grant the user came from (its show or edit page, respectively).
  def grant_return_path(grant = @scholarship.grant)
    params[:return_to] == "grant_edit" ? edit_grant_path(grant) : grant_path(grant)
  end

  # After saving, return to wherever the user came from: the grant, the event
  # registration (the card's View link carries return_to=registration), or — by
  # default — stay on the scholarship's own edit page.
  def scholarship_save_path
    return grant_return_path if grant_context?
    return edit_event_registration_path(@allocatable) if params[:return_to] == "registration" && @allocatable.respond_to?(:event)

    edit_scholarship_path(@scholarship)
  end

  # After destroying, leave the scholarship entirely: back to the grant when that
  # is the context, otherwise the event registrants page, otherwise normal fallback.
  def scholarship_return_path(grant)
    return grant_return_path(grant) if grant_context?(grant)

    event = @allocatable.try(:event)
    return registrants_event_path(event) if event
    return grant_path(grant) if grant

    root_path
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
    params.require(:scholarship).permit(
      :amount_dollars, :amount_cents, :tasks_completed, :grant_id, :recipient_id,
      comments_attributes: [ :id, :topic, :body, :_destroy ],
      notifications_attributes: [ :channel, :sender_id, :email_subject, :email_body_text, :noticeable_type, :noticeable_id ]
    )
  end

  # Stamp authorship on comments edited through the scholarship form: author + editor
  # on new ones, editor on existing ones whose body changed.
  def attribute_comment_authorship
    @scholarship.comments.select(&:new_record?).each do |c|
      c.created_by = current_user
      c.updated_by = current_user
    end
    @scholarship.comments.select { |c| c.persisted? && c.body_changed? }.each do |c|
      c.updated_by = current_user
    end
  end
end
