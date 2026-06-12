class FormsController < ApplicationController
  before_action :set_form, only: %i[show edit update destroy reorder_field reorder_fields edit_sections update_sections]

  def index
    authorize!
    @forms = Form.standalone.order(:name)
  end

  def show
    authorize! @form
    # The forms preview shows every field, highlighting any with conditional
    # visibility. The conditional logic itself only runs on the live
    # registration and public registration forms.
    @form_fields = @form.form_fields.reorder(position: :asc)
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
      role: params[:role].presence
    ).call

    redirect_to edit_form_path(form), notice: "Form created with #{form.form_fields.size} fields."
  end

  def edit
    authorize! @form
    @form_fields = @form.form_fields.reorder(position: :asc)
  end

  def update
    authorize! @form

    if @form.update(form_params)
      redirect_to edit_form_path(@form), notice: "Form updated."
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
    current_sections = (@form.sections || []).map(&:to_sym)
    if sections.to_set == current_sections.to_set && removed_custom_ids.empty?
      redirect_to edit_form_path(@form), notice: "No section changes."
      return
    end

    FormBuilderService.update_sections!(@form, sections, remove_custom_section_ids: removed_custom_ids)
    redirect_to edit_form_path(@form), notice: "Sections updated."
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

  def form_params
    params.require(:form).permit(
      :name, :role, :rhino_header, :hide_answered_person_questions, :hide_answered_form_questions,
      form_fields_attributes: [
        :id, :name, :answer_type, :required, :hint_text,
        :field_identifier, :section, :position, :visibility, :one_time, :width, :min_words, :max_characters, :_destroy,
        form_field_answer_options_attributes: [ :id, :option_name, :_destroy ]
      ]
    )
  end
end
