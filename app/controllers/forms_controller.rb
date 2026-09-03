class FormsController < ApplicationController
  before_action :set_form, only: %i[show results edit update destroy copy reorder_field reorder_fields edit_sections update_sections]
  before_action :set_dashboard_event, only: %i[show edit edit_sections update update_sections]

  SORTABLE_COLUMNS = %w[name role fields submissions].freeze

  def index
    authorize!
    if turbo_frame_request?
      @sort = SORTABLE_COLUMNS.include?(params[:sort]) ? params[:sort] : "name"
      @sort_direction = params[:direction] == "desc" ? "desc" : "asc"
      @forms = sorted_forms
      render :forms_results
    else
      @owned_forms = Form.owned.includes(:owner, :form_fields).order(:owner_type, :id)
      render :index
    end
  end

  # Reference page for the field identifiers that wire a question to backend
  # behavior — the "what will this actually do?" behind the form editor's field
  # identifier box. Reached from the form editors, so it carries the form and
  # event it came from to build its own way back.
  def smart_form_settings
    authorize! :form, to: :smart_form_settings?
    @groups = SmartFormFields.groups
    @answer_only_identifiers = SmartFormFields::ANSWER_ONLY_IDENTIFIERS
    @return_form = Form.find_by(id: params[:form_id])
    @dashboard_event = Event.find_by(id: params[:event_id])
    @return_field_id = params[:field_id]
  end

  def show
    authorize! @form
    # The forms preview shows every field, highlighting any with conditional
    # visibility. The conditional logic itself only runs on the live
    # registration and public registration forms.
    @form_fields = @form.form_fields.reorder(position: :asc)
  end

  # Aggregated rollup of this form's submissions: select/checkbox questions as
  # charts, free-text questions as lists of the actual answers.
  def results
    authorize! @form
    # Honor the event filter only for an event genuinely connected to this shared
    # form; an unknown id falls back to the unfiltered rollup.
    @selected_event_id = @form.events.where(id: params[:event_id]).pick(:id) if params[:event_id].present?
    @selected_submitter = results_submitter
    @selected_person_id = @selected_submitter.id if @selected_submitter.is_a?(Person)
    @selected_organization_id = @selected_submitter.id if @selected_submitter.is_a?(Organization)
    @selected_start_date = params[:start_date].presence
    @selected_end_date = params[:end_date].presence
    @selected_question = params[:question].presence
    @aggregator = FormResponseAggregator.new(@form, event_id: @selected_event_id,
                  person_id: @selected_person_id, organization_id: @selected_organization_id,
                  start_date: @selected_start_date, end_date: @selected_end_date,
                  question_query: @selected_question)
  end

  def new
    authorize!
  end

  def create
    authorize!

    sections = (params[:sections] || []).reject(&:blank?).map(&:to_sym)
    if sections.empty?
      flash.now[:alert] = "Please select at least one section."
      render :new, status: :unprocessable_content
      return
    end

    form = FormBuilderService.new(
      name: params[:name].presence || "New Form",
      sections: sections,
      role: params[:role].presence || "general"
    ).call

    redirect_to edit_sections_form_path(form), notice: "Form created with #{form.form_fields.size} fields."
  end

  def edit
    authorize! @form
    @form_fields = @form.form_fields.reorder(position: :asc)
  end

  def update
    authorize! @form

    if @form.update(form_params)
      redirect_to edit_form_path(@form, event_id: params[:event_id]), notice: "Form updated."
    else
      @form_fields = @form.form_fields.reorder(position: :asc)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! @form

    if @form.event_forms.exists?
      redirect_to @form, alert: "Cannot delete this form — it is linked to one or more events. Remove the form from all events first."
      return
    end

    @form.destroy!
    redirect_to forms_path, notice: "Form deleted."
  end

  def copy
    authorize! @form

    copy = FormCopyService.new(@form).call
    redirect_to edit_form_path(copy), notice: "Form duplicated. Now editing \"#{copy.display_name}\"."
  end

  def edit_sections
    authorize! @form
    @editable_sections = FormBuilderService.editable_sections(@form)
  end

  def update_sections
    authorize! @form

    sections = (params[:sections] || []).reject(&:blank?).map(&:to_sym)
    if sections.empty?
      flash.now[:alert] = "Please select at least one section."
      @editable_sections = FormBuilderService.editable_sections(@form)
      render :edit_sections, status: :unprocessable_content
      return
    end

    removed_custom_ids = removed_custom_section_ids
    current_sections = FormBuilderService.present_section_keys(@form)
    if sections.to_set == current_sections.to_set && removed_custom_ids.empty?
      redirect_to edit_form_path(@form, event_id: params[:event_id]), notice: "No section changes."
      return
    end

    FormBuilderService.update_sections!(@form, sections, remove_custom_section_ids: removed_custom_ids)
    redirect_to edit_form_path(@form, event_id: params[:event_id]), notice: "Sections updated."
  end

  def reorder_field
    authorize! @form
    field = @form.form_fields.find(params[:field_id])
    field.update!(position: params[:position].to_i)
    head :ok
  end

  def reorder_fields
    authorize! @form
    positions = JSON.parse(request.body.read)["positions"] || []
    positions.each do |item|
      @form.form_fields.where(id: item["id"]).update_all(position: item["position"])
    end
    head :ok
  end

  private

  # Whose submissions the results filter is narrowed to. One picker searches
  # people and organizations together and posts a signed global id saying which
  # kind was chosen; a plain person_id/organization_id also resolves, so an
  # eyebrow back from the answers list (which filters on those) lands on the same
  # slice. An unresolvable id falls back to the unfiltered rollup.
  def results_submitter
    submitter = if params[:submitter_sgid].present?
      GlobalID::Locator.locate_signed(params[:submitter_sgid])
    elsif params[:person_id].present?
      Person.find_by(id: params[:person_id])
    elsif params[:organization_id].present?
      Organization.find_by(id: params[:organization_id])
    end
    submitter if submitter.is_a?(Person) || submitter.is_a?(Organization)
  end

  # Sorts the standalone forms for the index frame. Count columns join their
  # association and order by the aggregate; direction is a symbol resolved from
  # the whitelisted param, never interpolated into raw SQL.
  def sorted_forms
    direction = @sort_direction == "desc" ? :desc : :asc
    case @sort
    when "role"
      Form.standalone.reorder(role: direction, name: :asc)
    when "fields"
      order_by_count(Form.standalone.left_joins(:form_fields), Arel.sql("COUNT(form_fields.id)"), direction)
    when "submissions"
      order_by_count(Form.standalone.left_joins(:form_submissions), Arel.sql("COUNT(form_submissions.id)"), direction)
    else
      Form.standalone.reorder(name: direction)
    end
  end

  def order_by_count(scope, count_expr, direction)
    scope.group(:id).reorder(direction == :desc ? count_expr.desc : count_expr.asc)
  end

  # Custom section header ids that were present on the page but left unchecked,
  # i.e. the custom sections the user chose to remove.
  def removed_custom_section_ids
    present = Array(params[:custom_sections]).map(&:to_i)
    kept = Array(params[:kept_custom_sections]).map(&:to_i)
    present - kept
  end

  def set_form
    @form = Form.find(params[:id])
  end

  # Forms are shared across events, so the "go back to the dashboard" target
  # can't be derived from the form alone — it comes from the event the admin
  # navigated from (passed as event_id). Scope the lookup to this form's events
  # so the link only ever points at a genuinely connected event. Fall back to
  # the sole connected event when there's exactly one.
  def set_dashboard_event
    @dashboard_event = @form.events.find_by(id: params[:event_id]) if params[:event_id].present?
    @dashboard_event ||= @form.events.one? ? @form.events.first : nil
  end

  def form_params
    params.require(:form).permit(
      :name, :role, :header, :hide_answered_person_questions, :hide_answered_form_questions, :slug, :published,
      form_fields_attributes: [
        :id, :name, :answer_type, :required, :subtitle, :hint_text,
        :field_identifier, :section, :position, :visibility, :one_time, :width, :min_words, :max_characters, :_destroy,
        form_field_answer_options_attributes: [ :id, :option_name, :_destroy ],
        form_field_resources_attributes: [ :id, :resource_id, :_destroy ]
      ]
    )
  end
end
